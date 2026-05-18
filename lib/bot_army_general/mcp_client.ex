defmodule BotArmyGeneral.McpClient do
  @moduledoc """
  Client for discovering and executing MCP tools via the MCP bot gateway.

  Queries `bot_army.mcp.status` for available tools and
  `bot_army.mcp.tools.execute` for sandboxed invocation.
  """

  alias BotArmyRuntime.NATS.Publisher

  @status_subject "bot_army.mcp.status"
  @execute_subject "bot_army.mcp.tools.execute"
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
