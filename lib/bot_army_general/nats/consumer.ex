defmodule BotArmyGeneral.NATS.Consumer do
  @moduledoc """
  NATS consumer for the general-purpose orchestrator bot.

  - `bot_army.general_purpose.ask` — discover skills, suggest installs, LLM answer
  - `bot_army.general_purpose.operator.complete` — PARA + notification intent

  Deprecated (one release): `bot_army.general.operator.complete`
  """

  use GenServer
  require Logger

  alias BotArmyGeneral.Handlers.{AskHandler, OperatorNotifyHandler}

  @reconnect_delay_ms 5_000
  @version Mix.Project.config()[:version]
  @registry_heartbeat_ms 20_000
  @health_subject "system.health.bot_army_general_purpose"
  @health_interval_ms 30_000
  @ask_subject "bot_army.general_purpose.ask"
  @complete_subject "bot_army.general_purpose.operator.complete"
  @legacy_complete_subject "bot_army.general.operator.complete"

  @subjects [
    %{
      subject: @ask_subject,
      type: :request_reply,
      description: "General-purpose ask (skills discovery + LLM)"
    },
    %{
      subject: @complete_subject,
      type: :request_reply,
      description: "PARA capture + notification intent after operator work"
    },
    %{
      subject: @legacy_complete_subject,
      type: :request_reply,
      description: "Deprecated alias for operator.complete"
    },
    %{
      subject: @health_subject,
      type: :publish,
      description: "General-purpose bot health pulse"
    }
  ]

  @subscribe_subjects [@ask_subject, @complete_subject, @legacy_complete_subject]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: {:ok, %{subscriptions: []}, {:continue, :connect}}

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5_000) do
      {:ok, conn} ->
        BotArmyRuntime.NATS.Connection.subscribe_to_status()

        case subscribe_all(conn, @subscribe_subjects) do
          {:ok, subs} ->
            BotArmyRuntime.Registry.register("bot_army_general_purpose", @subjects, @version)
            Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
            Process.send_after(self(), :publish_health, 1_000)
            Logger.info("[GeneralPurpose] Subscribed to ask + operator.complete")
            {:noreply, %{state | subscriptions: subs}}

          {:error, subject, reason} ->
            Logger.error("[GeneralPurpose] Subscribe failed #{subject}: #{inspect(reason)}")
            Process.send_after(self(), :reconnect, @reconnect_delay_ms)
            {:noreply, state}
        end

      {:error, _} ->
        Process.send_after(self(), :reconnect, @reconnect_delay_ms)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:reconnect, state), do: {:noreply, state, {:continue, :connect}}

  @impl true
  def handle_info(:publish_health, state) do
    _ = build_health_payload() |> publish_json(@health_subject)
    Process.send_after(self(), :publish_health, @health_interval_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:registry_heartbeat, state) do
    if state.subscriptions != [] do
      BotArmyRuntime.Registry.register("bot_army_general_purpose", @subjects, @version)
      Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers, []), fn ->
      try do
        query = decode_body(msg.body)
        response = dispatch(msg.topic, query) |> maybe_deprecate(msg.topic)
        maybe_reply(msg.reply_to, response)
      rescue
        e ->
          Logger.warning("[GeneralPurpose] Request failed: #{inspect(e)}")
          maybe_reply(msg.reply_to, %{"error" => "handler_failed"})
      end
    end)

    {:noreply, state}
  end

  defp dispatch(@ask_subject, query), do: AskHandler.handle_ask(query)

  defp dispatch(subject, query)
       when subject in [@complete_subject, @legacy_complete_subject],
       do: OperatorNotifyHandler.handle_complete(query)

  defp dispatch(_, _), do: %{"error" => "unknown_subject"}

  defp maybe_deprecate(response, @legacy_complete_subject) when is_map(response) do
    Map.put(response, "deprecated_subject", @legacy_complete_subject)
    |> Map.put("use_subject", @complete_subject)
  end

  defp maybe_deprecate(response, _), do: response

  defp subscribe_all(_conn, []), do: {:ok, []}

  defp subscribe_all(conn, [subject | rest]) do
    case Gnat.sub(conn, self(), subject) do
      {:ok, sub} ->
        Logger.info("[GeneralPurpose] Subscribed to #{subject}")

        case subscribe_all(conn, rest) do
          {:ok, subs} ->
            {:ok, [sub | subs]}

          {:error, failed_subject, reason} ->
            Gnat.unsub(conn, subject)
            {:error, failed_subject, reason}
        end

      {:error, reason} ->
        {:error, subject, reason}
    end
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp decode_body(_), do: %{}

  defp maybe_reply(nil, _response), do: :ok

  defp maybe_reply(reply_to, response) when is_binary(reply_to) do
    publish_json(response, reply_to)
  end

  defp build_health_payload do
    %{
      service: "bot_army_general_purpose",
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp publish_json(payload, subject) do
    with {:ok, conn} <- GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5_000) do
      Gnat.pub(conn, subject, Jason.encode!(payload))
    end
  end
end
