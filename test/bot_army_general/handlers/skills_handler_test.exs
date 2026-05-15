defmodule BotArmyGeneral.Handlers.SkillsHandlerTest do
  use ExUnit.Case
  @moduletag :handlers

  alias BotArmyGeneral.Handlers.SkillsHandler

  setup do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "general_handler_skills_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp)
    File.write!(Path.join(tmp, "demo.md"), "---\nname: Demo\ndescription: D\n---\nHi")
    :ok = Application.put_env(:bot_army_general, :skills_root, tmp, persistent: false)

    on_exit(fn ->
      File.rm_rf(tmp)
      Application.delete_env(:bot_army_general, :skills_root)
    end)

    :ok
  end

  test "handle_list returns skills" do
    assert %{"skills" => [%{"slug" => "demo"} | _]} = SkillsHandler.handle_list(%{})
  end

  test "handle_get by slug" do
    assert %{"slug" => "demo", "markdown" => "Hi"} = SkillsHandler.handle_get(%{"slug" => "demo"})
  end

  test "handle_get accepts skill key" do
    assert %{"slug" => "demo"} = SkillsHandler.handle_get(%{"skill" => "demo"})
  end

  test "handle_get missing slug" do
    assert %{"error" => "missing_slug"} = SkillsHandler.handle_get(%{})
  end
end
