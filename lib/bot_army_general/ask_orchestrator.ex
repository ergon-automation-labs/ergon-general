defmodule BotArmyGeneral.AskOrchestrator do
  @moduledoc """
  Out-of-domain ask flow: discover tenant skills, suggest installs, optional invoke, LLM answer.
  """

  require Logger

  alias BotArmyGeneral.SkillsClient
  alias BotArmyRuntime.NATS.Publisher

  @llm_subject "llm.prompt.submit"
  @default_llm_timeout_ms 120_000

  @intent_keywords %{
    "playwright" => ["playwright", "browser", "selenium", "click", "login page"],
    "travel" => ["flight", "airline", "airfare", "cheap", "travel", "hotel"],
    "web" => ["search the web", "google", "look up online", "find online"]
  }

  @spec handle(map()) :: {:ok, map()} | {:error, term()}
  def handle(query) when is_map(query) do
    user_query = string_field(query, "query") || string_field(query, "text")

    if is_nil(user_query) do
      {:ok, %{"ok" => false, "error" => "missing_query"}}
    else
      tenant_id = tenant_id_from(query)
      user_id = string_field(query, "user_id") || "general-purpose-user"
      auto_invoke = truthy?(Map.get(query, "auto_invoke_skill", false))

      with {:ok, installed} <- fetch_installed(tenant_id),
           {:ok, suggestions} <- fetch_suggestions(tenant_id, user_query),
           {:ok, matched} <- pick_skills(user_query, installed),
           {:ok, skill_context, actions} <-
             build_skill_context(tenant_id, user_id, matched, user_query, auto_invoke),
           {:ok, answer} <- llm_answer(user_query, installed, suggestions, skill_context, query) do
        {:ok,
         %{
           "ok" => true,
           "answer" => answer,
           "tenant_id" => tenant_id,
           "matched_skills" => Enum.map(matched, & &1["slug"]),
           "suggested_installs" => Map.get(suggestions, "suggestions", []),
           "actions" => actions
         }}
      else
        {:error, reason} ->
          Logger.warning("[GeneralPurpose] ask failed: #{inspect(reason)}")
          {:ok, %{"ok" => false, "error" => inspect(reason)}}
      end
    end
  end

  def handle(_), do: {:ok, %{"ok" => false, "error" => "invalid_query"}}

  defp fetch_installed(tenant_id) do
    case SkillsClient.list_installed(tenant_id) do
      {:ok, %{"skills" => skills}} when is_list(skills) -> {:ok, skills}
      {:ok, other} -> {:ok, Map.get(other, "skills", [])}
      {:error, reason} -> {:error, {:installed_list_failed, reason}}
    end
  end

  defp fetch_suggestions(tenant_id, user_query) do
    case SkillsClient.suggest_missing(tenant_id, user_query) do
      {:ok, resp} -> {:ok, resp}
      {:error, _} -> {:ok, %{"suggestions" => []}}
    end
  end

  defp pick_skills(user_query, installed) do
    slugs = Enum.map(installed, &Map.get(&1, "slug"))
    hay = String.downcase(user_query)

    matched_slugs =
      @intent_keywords
      |> Enum.flat_map(fn {intent, words} ->
        if Enum.any?(words, &String.contains?(hay, &1)) do
          slugs
          |> Enum.filter(fn slug ->
            String.contains?(slug, intent) or intent_matches_slug?(intent, slug)
          end)
        else
          []
        end
      end)
      |> Enum.uniq()

    matched =
      installed
      |> Enum.filter(fn s -> s["slug"] in matched_slugs end)
      |> Enum.take(3)

    {:ok, matched}
  end

  defp intent_matches_slug?("travel", slug), do: slug in ["playwright_operator"]
  defp intent_matches_slug?("web", slug), do: slug in ["playwright_operator", "nats_broker_call"]
  defp intent_matches_slug?("playwright", slug), do: slug == "playwright_operator"
  defp intent_matches_slug?(_, _), do: false

  defp build_skill_context(tenant_id, user_id, matched, user_query, auto_invoke) do
    {context_parts, actions} =
      Enum.reduce(matched, {[], []}, fn skill, {parts, acts} ->
        slug = skill["slug"]

        case SkillsClient.get_skill(tenant_id, slug) do
          {:ok, %{"markdown" => md}} when is_binary(md) ->
            part = "## Skill: #{slug}\n\n#{String.slice(md, 0, 4000)}"
            acts = maybe_invoke(tenant_id, user_id, slug, user_query, md, auto_invoke, acts)
            {[part | parts], acts}

          _ ->
            {parts, acts}
        end
      end)

    {:ok, Enum.join(Enum.reverse(context_parts), "\n\n"), actions}
  end

  defp maybe_invoke(tenant_id, user_id, slug, user_query, markdown, true, acts) do
    if playbook_only?(markdown) do
      [
        %{
          "type" => "playbook_only",
          "slug" => slug,
          "note" =>
            "Skill is a playbook (llm_hint: none); follow markdown or deploy an executor bot."
        }
        | acts
      ]
    else
      case SkillsClient.invoke_skill(tenant_id, user_id, slug, user_query) do
        {:ok, %{"status" => "success", "payload" => %{"completion" => c}}} ->
          [
            %{
              "type" => "invoked_skill",
              "slug" => slug,
              "completion_preview" => String.slice(c, 0, 500)
            }
            | acts
          ]

        {:ok, resp} ->
          [%{"type" => "invoked_skill", "slug" => slug, "raw" => resp} | acts]

        {:error, reason} ->
          [%{"type" => "invoke_failed", "slug" => slug, "reason" => inspect(reason)} | acts]
      end
    end
  end

  defp maybe_invoke(_tenant_id, _user_id, slug, _query, markdown, false, acts) do
    if playbook_only?(markdown) do
      [
        %{
          "type" => "playbook_available",
          "slug" => slug,
          "note" =>
            "Set auto_invoke_skill=true to run LLM-backed skills; playbooks are guidance only."
        }
        | acts
      ]
    else
      acts
    end
  end

  defp playbook_only?(markdown) do
    String.contains?(markdown, "llm_hint: none") or
      String.contains?(markdown, "llm_hint:none")
  end

  defp llm_answer(user_query, installed, suggestions, skill_context, query) do
    timeout = Application.get_env(:bot_army_general, :ask_llm_timeout_ms, @default_llm_timeout_ms)

    installed_lines =
      installed
      |> Enum.map(fn s -> "- #{s["slug"]}: #{s["description"] || "(no description)"}" end)
      |> Enum.join("\n")

    suggest_lines =
      (Map.get(suggestions, "suggestions", []) || [])
      |> Enum.map(fn s ->
        "- #{s["slug"]}: #{s["description"] || ""} (install: #{s["install_hint"] || "skills_bot migration/seed"})"
      end)
      |> Enum.join("\n")

    prompt = """
      You are the Bot Army general-purpose orchestrator. The user asked something outside specialist bots.

      User question:
      #{user_query}

      Installed tenant skills:
      #{if installed_lines == "", do: "(none listed)", else: installed_lines}

      Suggested skills to install (not yet in tenant DB):
      #{if suggest_lines == "", do: "(none)", else: suggest_lines}

      Relevant installed skill excerpts:
      #{if skill_context == "", do: "(none matched)", else: skill_context}

      Instructions:
      - Answer the question helpfully and honestly.
      - If a playbook skill applies (e.g. Playwright), explain steps and note if a browser worker is required.
      - If a skill is in "Suggested skills to install", tell the user the slug and that they need a skills_bot migration/seed.
      - Do not claim you ran Playwright or booked a flight unless tool output says so.
    """

    body = %{
      "event" => @llm_subject,
      "event_id" => BotArmyGeneral.UUID.v4(),
      "schema_version" => "1.0",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_general_purpose",
      "payload" => %{"text" => prompt, "model" => Map.get(query, "model", "auto")}
    }

    case Publisher.request(@llm_subject, body, timeout_ms: timeout) do
      {:ok, %{"completion" => c}} when is_binary(c) ->
        {:ok, c}

      {:ok, %{"error" => err}} ->
        {:error, {:llm_error, err}}

      {:error, :timeout} ->
        {:error, :llm_timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp tenant_id_from(query) do
    case Map.get(query, "tenant_id") do
      id when is_binary(id) and id != "" -> id
      _ -> SkillsClient.default_tenant_id()
    end
  end

  defp string_field(map, key) do
    case Map.get(map, key) do
      v when is_binary(v) ->
        t = String.trim(v)
        if t == "", do: nil, else: t

      _ ->
        nil
    end
  end

  defp truthy?(v) when v in [true, "true", 1, "1", "yes"], do: true
  defp truthy?(_), do: false
end
