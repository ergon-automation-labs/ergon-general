defmodule BotArmyGeneral.OperatorNotifyTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyGeneral.OperatorNotify

  test "build_para_payload includes slug in details" do
    p =
      OperatorNotify.build_para_payload(%{
        "slug" => "playwright_operator",
        "summary" => "Browser run done",
        "details" => "Passed smoke test.",
        "topic" => "playwright"
      })

    assert p["schema_version"] == "1.0"
    assert p["source_bot"] == "general_purpose"
    assert p["summary"] == "Browser run done"
    assert p["details"] =~ "playwright_operator"
    assert p["details"] =~ "Passed smoke test."
  end

  test "build_notification_intent matches router-friendly shape" do
    p =
      OperatorNotify.build_notification_intent(%{
        "slug" => "playwright_operator",
        "summary" => "Done",
        "priority" => "normal"
      })

    assert p["signal_type"] == "general_purpose_operator_complete"
    assert p["intent"]["domain"] == "general_purpose"
    assert p["intent"]["requires_notification_router_delivery"] == true
    assert p["data"]["para_inbox"] == "inbox/bots/general_purpose.md"
    assert p["intent"]["delivery_policy"]["fallback_order"] == ["discord", "synapse_chat"]
  end

  test "handle skips when disabled" do
    prev = Application.get_env(:bot_army_general, :operator_notify_enabled)
    Application.put_env(:bot_army_general, :operator_notify_enabled, false)

    on_exit(fn ->
      Application.put_env(:bot_army_general, :operator_notify_enabled, prev)
    end)

    assert {:ok, %{"skipped" => "operator_notify_disabled"}} =
             OperatorNotify.handle(%{"summary" => "x"})
  end
end
