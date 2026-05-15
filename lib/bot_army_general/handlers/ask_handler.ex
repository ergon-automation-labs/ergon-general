defmodule BotArmyGeneral.Handlers.AskHandler do
  @moduledoc false

  alias BotArmyGeneral.AskOrchestrator

  def handle_ask(query) when is_map(query) do
    case AskOrchestrator.handle(query) do
      {:ok, body} -> body
    end
  end

  def handle_ask(_), do: %{"ok" => false, "error" => "invalid_query"}
end
