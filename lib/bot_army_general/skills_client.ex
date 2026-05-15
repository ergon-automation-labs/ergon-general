defmodule BotArmyGeneral.SkillsClient do
  @moduledoc false

  alias BotArmyRuntime.NATS.Publisher

  @default_tenant_id "00000000-0000-0000-0000-000000000001"
  @skills_timeout_ms 12_000

  def list_installed(tenant_id) do
    request("bot.army.skills.content.list", %{"tenant_id" => tenant_id})
  end

  def get_skill(tenant_id, slug) do
    request("bot.army.skills.content.get", %{"tenant_id" => tenant_id, "slug" => slug})
  end

  def suggest_missing(tenant_id, query) do
    request("bot.army.skills.catalog.suggest", %{
      "tenant_id" => tenant_id,
      "query" => query,
      "limit" => 8
    })
  end

  def invoke_skill(tenant_id, user_id, slug, payload_text, opts \\ []) do
    timeout = Keyword.get(opts, :timeout_ms, 95_000)
    subject = "bot.army.skills.command." <> slug

    envelope = %{
      "event" => subject,
      "event_id" => event_id(),
      "schema_version" => "1.0",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_general_purpose",
      "source_node" => node() |> Atom.to_string(),
      "triggered_by" => "general_purpose.ask",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{"text" => payload_text}
    }

    request(subject, envelope, timeout)
  end

  defp request(subject, body, timeout \\ @skills_timeout_ms) do
    case Publisher.request(subject, body, timeout_ms: timeout) do
      {:ok, resp} when is_map(resp) -> {:ok, resp}
      {:error, :timeout} -> {:error, :skills_timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  def default_tenant_id, do: @default_tenant_id

  defp event_id, do: BotArmyGeneral.UUID.v4()
end
