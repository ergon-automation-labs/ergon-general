defmodule BotArmyGeneral.OperatorNotify do
  @moduledoc """
  After an operator or agent finishes work with a fleet skill, optionally:
  - append a line to PARA `inbox/bots/general.md` via `para.capture.append`
  - publish `synapse.intent.notification.request` for Notification Router → Discord
  """

  require Logger

  alias BotArmyRuntime.NATS.Publisher

  @schema_version "1.0"
  @para_subject "para.capture.append"
  @intent_subject "synapse.intent.notification.request"

  @doc """
  Handles operator-complete notification. Returns `{:ok, response_map}`.
  """
  @spec handle(map()) :: {:ok, map()}
  def handle(payload) when is_map(payload) do
    if enabled?() do
      para_result =
        if truthy?(Map.get(payload, "para_capture", true)) do
          capture_para(payload)
        else
          %{"skipped" => true}
        end

      notify_result =
        if truthy?(Map.get(payload, "notify_discord", true)) do
          publish_notification_intent(payload)
        else
          %{"skipped" => true}
        end

      {:ok,
       %{
         "ok" => true,
         "para" => result_to_map(para_result),
         "notification" => result_to_map(notify_result)
       }}
    else
      {:ok, %{"ok" => true, "skipped" => "operator_notify_disabled"}}
    end
  end

  def handle(_), do: {:ok, %{"ok" => false, "error" => "invalid_query"}}

  @doc false
  def build_para_payload(payload) when is_map(payload) do
    slug = string_field(payload, "slug")
    summary = string_field(payload, "summary") || default_summary(slug)
    details = string_field(payload, "details") || ""
    topic = string_field(payload, "topic") || "general_skill"
    task_id = string_field(payload, "task_id")

    base_details =
      if slug != "" do
        "skill_slug: #{slug}\n\n#{details}"
      else
        details
      end

    %{
      "schema_version" => @schema_version,
      "source_bot" => "general",
      "summary" => summary,
      "details" => String.trim(base_details),
      "topic" => topic,
      "task_id" => task_id
    }
    |> drop_nil_values()
  end

  @doc false
  def build_notification_intent(payload) when is_map(payload) do
    slug = string_field(payload, "slug")
    summary = string_field(payload, "summary") || default_summary(slug)
    details = string_field(payload, "details") || ""
    topic = string_field(payload, "topic") || "general_skill"
    priority = normalize_priority(Map.get(payload, "priority", "normal"))
    status = string_field(payload, "status") || "complete"
    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    %{
      "signal_type" => "general_operator_complete",
      "schema_version" => @schema_version,
      "timestamp" => now,
      "status" => status,
      "intent" => %{
        "intent_type" => "operator_update",
        "domain" => "general",
        "topic" => topic,
        "priority" => priority,
        "requires_context_broker_routing" => true,
        "requires_notification_router_delivery" => true,
        "delivery_policy" => %{
          "channel_strategy" => "last_successful_user_surface",
          "fallback_order" => ["discord", "synapse_chat"],
          "respect_quiet_hours" => true
        },
        "suggested_actions" => ["acknowledge", "open_para_inbox", "snooze"]
      },
      "data" => %{
        "summary" => summary,
        "details" => details,
        "skill_slug" => slug,
        "source_bot" => "bot_army_general",
        "para_inbox" => "inbox/bots/general.md"
      }
    }
    |> drop_nil_values()
  end

  defp capture_para(payload) do
    body = build_para_payload(payload)
    timeout = Application.get_env(:bot_army_general, :para_capture_timeout_ms, 5_000)

    case Publisher.request(@para_subject, body, timeout_ms: timeout) do
      {:ok, %{"ok" => true} = resp} ->
        {:ok, resp}

      {:ok, resp} when is_map(resp) ->
        Logger.warning("[General] para.capture.append returned ok!=true: #{inspect(resp)}")
        {:error, :para_capture_failed, resp}

      {:error, :timeout} ->
        {:error, :para_timeout, nil}

      {:error, reason} ->
        {:error, reason, nil}
    end
  end

  defp publish_notification_intent(payload) do
    body = build_notification_intent(payload)

    case Publisher.publish(@intent_subject, body) do
      {:ok, subject} -> {:ok, %{"published" => true, "subject" => subject}}
      {:error, reason} -> {:error, reason, nil}
    end
  end

  defp enabled? do
    Application.get_env(:bot_army_general, :operator_notify_enabled, true)
  end

  defp truthy?(v) when v in [true, "true", 1, "1", "yes"], do: true
  defp truthy?(_), do: false

  defp string_field(payload, key) do
    case Map.get(payload, key) do
      v when is_binary(v) ->
        t = String.trim(v)
        if t == "", do: nil, else: t

      _ ->
        nil
    end
  end

  defp default_summary(nil), do: "General bot operator update"
  defp default_summary(""), do: "General bot operator update"
  defp default_summary(slug), do: "General skill: #{slug}"

  defp normalize_priority(p) when p in ["low", "normal", "medium", "high"], do: p
  defp normalize_priority("urgent"), do: "high"
  defp normalize_priority(_), do: "normal"

  defp drop_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

  defp result_to_map({:ok, data}) when is_map(data), do: Map.put(data, "status", "ok")

  defp result_to_map({:ok, subject}) when is_binary(subject),
    do: %{"status" => "ok", "subject" => subject}

  defp result_to_map({:error, reason, detail}) when is_map(detail),
    do: %{"status" => "error", "reason" => inspect(reason), "detail" => detail}

  defp result_to_map({:error, reason, _}), do: %{"status" => "error", "reason" => inspect(reason)}
  defp result_to_map(%{"skipped" => _} = m), do: m
end
