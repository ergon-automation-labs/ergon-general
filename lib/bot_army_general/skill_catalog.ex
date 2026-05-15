defmodule BotArmyGeneral.SkillCatalog do
  @moduledoc """
  Loads fleet-wide base skills from `priv/skills/*.md` shipped with the release.

  Each file basename (without `.md`) is the skill `slug`. Optional YAML frontmatter
  supports `name` and `description` keys (single-line string values).
  """

  @slug_pattern ~r/^[a-z0-9][a-z0-9_]*$/

  def skills_root do
    Application.get_env(:bot_army_general, :skills_root) ||
      Application.app_dir(:bot_army_general, "priv/skills")
  end

  @doc """
  Returns `{:ok, [%{...}]}` with entries sorted by slug.
  """
  def list_skills do
    root = skills_root()

    case File.ls(root) do
      {:ok, names} ->
        skills =
          names
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.reject(&(&1 == "README.md"))
          |> Enum.map(&skill_summary(root, &1))
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1["slug"])

        {:ok, skills}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, "skills_dir_unreadable", inspect(reason)}
    end
  end

  @doc """
  Fetches one skill by slug. Response map includes `slug`, `frontmatter`, `markdown`.
  """
  def get_skill(slug) when is_binary(slug) do
    if slug =~ @slug_pattern do
      path = Path.join(skills_root(), slug <> ".md")

      case File.read(path) do
        {:ok, content} ->
          {fm, body} = split_frontmatter(content)

          {:ok,
           %{
             "slug" => slug,
             "frontmatter" => fm,
             "markdown" => body
           }}

        {:error, :enoent} ->
          {:error, "skill_not_found", slug}

        {:error, reason} ->
          {:error, "read_failed", inspect(reason)}
      end
    else
      {:error, "invalid_slug", slug}
    end
  end

  def get_skill(_), do: {:error, "invalid_slug", nil}

  defp skill_summary(root, filename) do
    slug = filename |> String.trim_trailing(".md")

    if slug =~ @slug_pattern do
      path = Path.join(root, filename)

      case File.read(path) do
        {:ok, content} ->
          {fm, _body} = split_frontmatter(content)

          %{
            "slug" => slug,
            "name" => Map.get(fm, "name", slug),
            "description" => Map.get(fm, "description", "")
          }

        {:error, _} ->
          nil
      end
    else
      nil
    end
  end

  defp split_frontmatter(content) do
    cond do
      match?(<<"---\n", _::binary>>, content) ->
        <<"---\n", rest::binary>> = content
        split_fm_body(rest, "\n---\n")

      match?(<<"---\r\n", _::binary>>, content) ->
        <<"---\r\n", rest::binary>> = content
        split_fm_body(rest, "\r\n---\r\n")

      true ->
        {%{}, content}
    end
  end

  defp split_fm_body(rest, delim) do
    case String.split(rest, delim, parts: 2) do
      [fm, body] -> {parse_simple_yaml(fm), String.trim_leading(body, "\n")}
      [fm] -> {parse_simple_yaml(fm), ""}
    end
  end

  defp parse_simple_yaml(text) do
    text
    |> String.split(~r/\R/)
    |> Enum.reduce(%{}, fn line, acc ->
      line = String.trim(line)

      case String.split(line, ":", parts: 2) do
        [k, v] ->
          key = String.trim(k)
          val = String.trim(v)

          if key != "" and valid_key?(key) do
            Map.put(acc, key, strip_quotes(val))
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  defp valid_key?(k), do: k =~ ~r/^[a-zA-Z0-9_]+$/

  defp strip_quotes(<<?", rest::binary>>) do
    rest |> String.trim_trailing("\"")
  end

  defp strip_quotes(<<?', rest::binary>>) do
    rest |> String.trim_trailing("'")
  end

  defp strip_quotes(s), do: s
end
