defmodule BotArmyGeneral.Handlers.OperatorNotifyHandler do
  @moduledoc """
  POST-workflow hook: PARA human-review inbox + Discord-bound notification intent.
  """

  alias BotArmyGeneral.OperatorNotify

  def handle_complete(query) when is_map(query) do
    case OperatorNotify.handle(query) do
      {:ok, body} -> body
    end
  end

  def handle_complete(_), do: %{"error" => "invalid_query"}
end
