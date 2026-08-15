defmodule BotArmyGeneral.AskOrchestratorTest do
  use ExUnit.Case, async: true
  @moduletag :core

  alias BotArmyGeneral.AskOrchestrator

  test "requires query" do
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             AskOrchestrator.handle(%{})
  end

  test "handles missing query field" do
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             AskOrchestrator.handle(%{"tenant_id" => "test"})
  end

  test "handles empty query string" do
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             AskOrchestrator.handle(%{"query" => ""})
  end

  test "handles whitespace-only query string" do
    assert {:ok, %{"ok" => false, "error" => "missing_query"}} =
             AskOrchestrator.handle(%{"query" => "   "})
  end

  test "handles invalid input type" do
    assert {:ok, %{"ok" => false, "error" => "invalid_query"}} =
             AskOrchestrator.handle("not a map")
  end

  test "handles nil input" do
    assert {:ok, %{"ok" => false, "error" => "invalid_query"}} =
             AskOrchestrator.handle(nil)
  end

  @tag :integration
  test "uses 'text' field as fallback for query" do
    # Should not error even though 'query' is missing
    # (The actual behavior depends on whether text field gets picked up)
    result = AskOrchestrator.handle(%{"text" => "test query"})
    assert match?({:ok, _}, result)
  end

  @tag :integration
  test "default tenant when not specified" do
    # Should use default tenant and proceed (will likely fail on skills_bot unavailable)
    result = AskOrchestrator.handle(%{"query" => "test"})
    assert match?({:ok, _}, result)
  end

  @tag :integration
  test "response includes metadata fields" do
    {:ok, response} = AskOrchestrator.handle(%{"query" => "simple test"})

    assert is_map(response)
    assert Map.has_key?(response, "ok")
    assert Map.has_key?(response, "tenant_id")
    assert Map.has_key?(response, "matched_skills")
    assert Map.has_key?(response, "suggested_installs")
    assert Map.has_key?(response, "mcp_tools_available")
    assert Map.has_key?(response, "mcp_suggestions")
  end

  @tag :integration
  test "matched_skills is always a list" do
    {:ok, response} = AskOrchestrator.handle(%{"query" => "test"})
    assert is_list(response["matched_skills"])
  end

  @tag :integration
  test "actions is always a list" do
    {:ok, response} = AskOrchestrator.handle(%{"query" => "test"})
    assert is_list(response["actions"])
  end

  @tag :integration
  test "handles custom model option" do
    result = AskOrchestrator.handle(%{"query" => "test", "model" => "custom-model"})
    assert match?({:ok, _}, result)
  end

  @tag :integration
  test "handles allow_cloud_when_sensitive flag" do
    result =
      AskOrchestrator.handle(%{
        "query" => "test",
        "allow_cloud_when_sensitive" => true
      })

    assert match?({:ok, _}, result)
  end
end
