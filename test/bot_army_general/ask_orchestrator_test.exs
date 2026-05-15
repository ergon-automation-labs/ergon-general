defmodule BotArmyGeneral.AskOrchestratorTest do
  use ExUnit.Case, async: true
  @moduletag :core

  alias BotArmyGeneral.AskOrchestrator

  test "requires query" do
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             AskOrchestrator.handle(%{})
  end
end
