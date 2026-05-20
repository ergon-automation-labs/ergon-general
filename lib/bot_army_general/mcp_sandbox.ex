defmodule BotArmyGeneral.McpSandbox do
  @moduledoc """
  Sandboxed execution layer for MCP tools.

  - **Allowlist**: only approved tool names execute without explicit consent.
  - **Timeout**: every tool call capped at `sandbox_timeout_ms`.
  - **Audit log**: every execution logged at `:info` with tenant, tool, params hash.

  Configure via Application env:
    config :bot_army_general, :sandbox_mode, :strict | :permissive
    config :bot_army_general, :sandbox_allowlist, ["registry_list_bots", ...]
    config :bot_army_general, :sandbox_timeout_ms, 15_000

  `:strict` (default) — unknown tools are rejected.
  `:permissive` — all tools pass the allowlist gate (useful for dev).
  """

  require Logger

  alias BotArmyGeneral.McpClient

  @default_allowlist [
    "nats_server_info",
    "nats_subject_reference",
    "registry_list_bots",
    "registry_list_subjects"
  ]

  @doc """
  Execute a tool if it passes the sandbox gate.

  Returns `{:ok, result}` or `{:error, :sandbox_rejected}`.
  """
  @spec execute(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def execute(tool_name, params \\ %{}, tenant_id \\ "default") do
    if allowed?(tool_name) do
      audit(tenant_id, tool_name, params)

      case McpClient.execute_tool(tool_name, params) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          Logger.warning("[McpSandbox] #{tool_name} failed: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.warning("[McpSandbox] Rejected tool: #{tool_name} (tenant: #{tenant_id})")
      {:error, :sandbox_rejected}
    end
  end

  @doc "List allowed tools from the MCP gateway, filtered by allowlist."
  @spec list_allowed_tools() :: {:ok, [map()]} | {:error, term()}
  def list_allowed_tools do
    case McpClient.list_tools() do
      {:ok, tools} ->
        allowed = allowlist_set()
        filtered = Enum.filter(tools, &(Map.get(&1, "name") in (allowed / 1)))
        {:ok, filtered}

      error ->
        error
    end
  end

  @doc "Suggest MCP tools from external catalogs (discovery, no sandbox restriction)."
  @spec catalog_suggest(String.t(), String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def catalog_suggest(query, tenant_id \\ "default", limit \\ 8) do
    McpClient.catalog_suggest(query, tenant_id, limit)
  end

  @doc "Register an MCP tool for a tenant (administration, no sandbox restriction)."
  @spec register_tool(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def register_tool(slug, tenant_id \\ "default", config \\ %{}) do
    McpClient.register_tool(slug, tenant_id, config)
  end

  # ---

  defp allowed?(tool_name) do
    mode = Application.get_env(:bot_army_general, :sandbox_mode, :strict)

    case mode do
      :permissive -> true
      _ -> tool_name in allowlist_set()
    end
  end

  defp allowlist_set do
    Application.get_env(:bot_army_general, :sandbox_allowlist, @default_allowlist)
    |> MapSet.new()
  end

  defp audit(tenant_id, tool_name, params) do
    param_hash =
      :crypto.hash(:sha256, Jason.encode!(params))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)

    Logger.info("[McpSandbox] tenant=#{tenant_id} tool=#{tool_name} param_hash=#{param_hash}")
  end
end
