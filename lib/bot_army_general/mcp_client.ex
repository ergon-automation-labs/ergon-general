defmodule BotArmyGeneral.McpClient do
  @moduledoc """
  Client for discovering and executing MCP tools via the MCP bot gateway.

  Queries `bot_army.mcp.status` for available tools and
  `bot_army.mcp.tools.execute` for sandboxed invocation.
  """

  alias BotArmyRuntime.NATS.Publisher

  @status_subject "bot_army.mcp.status"
  @execute_subject "bot_army.mcp.tools.execute"
  @catalog_suggest_subject "bot_army.mcp.catalog.suggest"
  @tools_register_subject "bot_army.mcp.tools.register"
  @tool_timeout_ms 15_000

  @doc "List all available MCP tools from the gateway."
  @spec list_tools() :: {:ok, [map()]} | {:error, term()}
  def list_tools do
    case Publisher.request(@status_subject, %{}, timeout_ms: @tool_timeout_ms) do
      {:ok, %{"tools" => tools}} when is_list(tools) ->
        {:ok, tools}

      {:ok, resp} ->
        {:ok, Map.get(resp, "tools", [])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Suggest MCP tools from canonical + external catalogs based on a query."
  @spec catalog_suggest(String.t(), String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def catalog_suggest(query, tenant_id \\ "default", limit \\ 8) do
    payload = %{
      "query" => query,
      "tenant_id" => tenant_id,
      "limit" => limit
    }

    case Publisher.request(@catalog_suggest_subject, payload, timeout_ms: @tool_timeout_ms) do
      {:ok, resp} when is_map(resp) -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Register an MCP tool for a tenant."
  @spec register_tool(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def register_tool(slug, tenant_id \\ "default", config \\ %{}) do
    payload = %{
      "slug" => slug,
      "tenant_id" => tenant_id,
      "config" => config
    }

    case Publisher.request(@tools_register_subject, payload, timeout_ms: @tool_timeout_ms) do
      {:ok, resp} when is_map(resp) -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Execute an MCP tool by name with the given parameters."
  @spec execute_tool(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def execute_tool(tool_name, params \\ %{}) do
    payload = %{
      "tool" => tool_name,
      "params" => params
    }

    case Publisher.request(@execute_subject, payload, timeout_ms: @tool_timeout_ms) do
      {:ok, resp} when is_map(resp) ->
        {:ok, resp}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
