defmodule BotArmyGeneral.NATS.Consumer do
  @moduledoc """
  NATS consumer: fleet-wide filesystem skills (`priv/skills/*.md`).
  """

  use GenServer
  require Logger

  alias BotArmyGeneral.Handlers.OperatorNotifyHandler
  alias BotArmyGeneral.Handlers.SkillsHandler

  @reconnect_delay_ms 5_000
  @version Mix.Project.config()[:version]
  @registry_heartbeat_ms 20_000
  @health_subject "system.health.bot_army_general"
  @health_interval_ms 30_000
  @list_subject "bot_army.general.skill.list"
  @get_subject "bot_army.general.skill.get"
  @complete_subject "bot_army.general.operator.complete"

  @subjects [
    %{
      subject: @list_subject,
      type: :request_reply,
      description: "List base markdown skills shipped with the general bot"
    },
    %{
      subject: @get_subject,
      type: :request_reply,
      description: "Fetch one base skill by slug (markdown body + frontmatter)"
    },
    %{
      subject: @complete_subject,
      type: :request_reply,
      description: "PARA capture + notification intent after operator/skill work"
    },
    %{
      subject: @health_subject,
      type: :publish,
      description: "General bot health pulse"
    }
  ]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: {:ok, %{subscriptions: []}, {:continue, :connect}}

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5_000) do
      {:ok, conn} ->
        BotArmyRuntime.NATS.Connection.subscribe_to_status()

        case subscribe_all(conn, [@list_subject, @get_subject, @complete_subject]) do
          {:ok, subs} ->
            BotArmyRuntime.Registry.register("bot_army_general", @subjects, @version)
            Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
            Process.send_after(self(), :publish_health, 1_000)
            Logger.info("[General] Subscribed to skill + operator.complete subjects")
            {:noreply, %{state | subscriptions: subs}}

          {:error, subject, reason} ->
            Logger.error("[General] Subscribe failed #{subject}: #{inspect(reason)}")
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
      BotArmyRuntime.Registry.register("bot_army_general", @subjects, @version)
      Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers, []), fn ->
      try do
        query = decode_body(msg.body)
        response = dispatch(msg.topic, query)
        maybe_reply(msg.reply_to, response)
      rescue
        e ->
          Logger.warning("[General] Request failed: #{inspect(e)}")
          maybe_reply(msg.reply_to, %{"error" => "handler_failed"})
      end
    end)

    {:noreply, state}
  end

  defp dispatch(@list_subject, query), do: SkillsHandler.handle_list(query)
  defp dispatch(@get_subject, query), do: SkillsHandler.handle_get(query)
  defp dispatch(@complete_subject, query), do: OperatorNotifyHandler.handle_complete(query)
  defp dispatch(_, _), do: %{"error" => "unknown_subject"}

  defp subscribe_all(_conn, []), do: {:ok, []}

  defp subscribe_all(conn, [subject | rest]) do
    case Gnat.sub(conn, self(), subject) do
      {:ok, sub} ->
        Logger.info("[General] Subscribed to #{subject}")

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
      service: "bot_army_general",
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
