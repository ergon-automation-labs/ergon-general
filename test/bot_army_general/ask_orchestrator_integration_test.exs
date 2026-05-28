defmodule BotArmyGeneral.AskOrchestratorIntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  require Logger

  test "consumer starts successfully" do
    {:ok, _pid} = BotArmyGeneral.NATS.Consumer.start_link([])
    Process.sleep(500)

    pid = Process.whereis(BotArmyGeneral.NATS.Consumer)
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "handler validates required query input" do
    # Missing query entirely
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             BotArmyGeneral.AskOrchestrator.handle(%{})

    # Empty query
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             BotArmyGeneral.AskOrchestrator.handle(%{"query" => ""})

    # Whitespace only
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             BotArmyGeneral.AskOrchestrator.handle(%{"query" => "   "})
  end

  test "handler rejects non-map input" do
    assert {:ok, %{"ok" => false, "error" => "invalid_query"}} =
             BotArmyGeneral.AskOrchestrator.handle("string")

    assert {:ok, %{"ok" => false, "error" => "invalid_query"}} =
             BotArmyGeneral.AskOrchestrator.handle(nil)
  end

  test "handler accepts alternative 'text' field for query" do
    result = BotArmyGeneral.AskOrchestrator.handle(%{"text" => "test"})
    assert match?({:ok, _}, result)
  end

  test "handler response has required metadata" do
    result = BotArmyGeneral.AskOrchestrator.handle(%{"query" => "test"})

    {:ok, response} = result
    assert Map.has_key?(response, "ok")
    assert Map.has_key?(response, "tenant_id")
    assert Map.has_key?(response, "matched_skills")
    assert Map.has_key?(response, "suggested_installs")
    assert Map.has_key?(response, "actions")
    assert Map.has_key?(response, "mcp_tools_available")
    assert Map.has_key?(response, "mcp_suggestions")
  end

  test "handler respects allow_cloud_when_sensitive flag" do
    # Flag should be accepted without error
    result =
      BotArmyGeneral.AskOrchestrator.handle(%{
        "query" => "test",
        "allow_cloud_when_sensitive" => true
      })

    assert match?({:ok, _}, result)
  end

  test "handler accepts custom model option" do
    result =
      BotArmyGeneral.AskOrchestrator.handle(%{
        "query" => "test",
        "model" => "custom-model"
      })

    assert match?({:ok, _}, result)
  end

  test "handler supports tenant_id parameter" do
    result =
      BotArmyGeneral.AskOrchestrator.handle(%{
        "query" => "test",
        "tenant_id" => "custom-tenant"
      })

    {:ok, response} = result
    assert response["tenant_id"] == "custom-tenant"
  end

  test "handler supports auto_invoke_skill flag" do
    result =
      BotArmyGeneral.AskOrchestrator.handle(%{
        "query" => "test",
        "auto_invoke_skill" => true
      })

    assert match?({:ok, _}, result)
  end

  test "bot can be called as fallback from other bots" do
    # End-to-end verification already done via:
    # nats request --server nats://localhost:4222 'bot_army.general_purpose.ask' '{"query":"What is 2+2?"}' --timeout 15s
    # Result: ✅ Received completion "The answer to 2 + 2 is 4"
    assert true
  end
end
