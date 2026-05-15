defmodule BotArmyGeneral.SkillCatalogTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyGeneral.SkillCatalog

  setup do
    tmp = Path.join(System.tmp_dir!(), "general_skills_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    File.write!(
      Path.join(tmp, "alpha_skill.md"),
      """
      ---
      name: Alpha Name
      description: Alpha desc
      ---

      Hello **body**
      """
    )

    File.write!(Path.join(tmp, "no_front.md"), "plain only\n")
    File.write!(Path.join(tmp, "Bad-Caps.md"), "---\nname: X\n---\n")
    :ok = Application.put_env(:bot_army_general, :skills_root, tmp, persistent: false)

    on_exit(fn ->
      File.rm_rf(tmp)
      Application.delete_env(:bot_army_general, :skills_root)
    end)

    :ok
  end

  test "list_skills returns valid slugs and summaries" do
    assert {:ok, skills} = SkillCatalog.list_skills()
    slugs = Enum.map(skills, & &1["slug"]) |> Enum.sort()
    assert slugs == ["alpha_skill", "no_front"]
  end

  test "get_skill returns markdown and frontmatter" do
    assert {:ok, %{"slug" => "alpha_skill", "frontmatter" => fm, "markdown" => md}} =
             SkillCatalog.get_skill("alpha_skill")

    assert fm["name"] == "Alpha Name"
    assert fm["description"] == "Alpha desc"
    assert md == "Hello **body**\n"
  end

  test "get_skill without frontmatter" do
    assert {:ok, %{"frontmatter" => %{}, "markdown" => md}} = SkillCatalog.get_skill("no_front")
    assert md == "plain only\n"
  end

  test "get_skill rejects invalid slug" do
    assert {:error, "invalid_slug", _} = SkillCatalog.get_skill("../etc")
  end

  test "get_skill missing file" do
    assert {:error, "skill_not_found", "missing"} = SkillCatalog.get_skill("missing")
  end
end
