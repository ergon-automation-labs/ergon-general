defmodule BotArmyGeneral.Handlers.SkillsHandler do
  @moduledoc """
  Request/reply payloads for fleet-wide filesystem skills.
  """

  alias BotArmyGeneral.SkillCatalog

  def handle_list(_query) do
    case SkillCatalog.list_skills() do
      {:ok, skills} -> %{"skills" => skills}
      {:error, code, detail} -> %{"error" => code, "detail" => detail}
    end
  end

  def handle_get(query) when is_map(query) do
    slug = Map.get(query, "slug") || Map.get(query, "skill")

    case slug do
      s when is_binary(s) and s != "" ->
        case SkillCatalog.get_skill(s) do
          {:ok, skill} -> skill
          {:error, code, detail} -> %{"error" => code, "detail" => detail}
        end

      _ ->
        %{"error" => "missing_slug"}
    end
  end

  def handle_get(_), do: %{"error" => "invalid_query"}
end
