# bot_army_general

Fleet-wide **general-purpose** bot: serves **base markdown skills** from `priv/skills/*.md` over NATS (no database).

## NATS subjects

| Subject | Mode | Body (JSON) | Response |
|---------|------|---------------|----------|
| `bot_army.general.skill.list` | request/reply | `{}` (optional) | `{"skills":[%{slug,name,description},...]}` |
| `bot_army.general.skill.get` | request/reply | `{"slug":"playwright_operator"}` | `slug`, `frontmatter`, `markdown` or `error` |
| `bot_army.general.operator.complete` | request/reply | see below | PARA capture + notification intent |
| `system.health.bot_army_general` | publish | — | JSON health pulse |

### Operator complete (PARA + Discord path)

After using a skill, call **`bot_army.general.operator.complete`** so the fleet records human review and notifies you:

```json
{
  "slug": "playwright_operator",
  "summary": "Playwright smoke passed",
  "details": "optional longer text",
  "priority": "normal",
  "para_capture": true,
  "notify_discord": true
}
```

- **PARA:** `para.capture.append` → `inbox/bots/general.md` (para bot / personal_os).
- **Discord:** publishes `synapse.intent.notification.request` → notification router (respects quiet hours).

Monorepo flow doc: `docs/GENERAL_BOT_OPERATOR_FLOW.md` in **elixir_bots**. CLI: `scripts/general_operator_complete.py`.

Registry id: **`bot_army_general`**.

## OTP release

- Release name: `general_bot`
- Tarball pattern: `general_bot-VERSION.tar.gz`

## Local

```bash
make deps
make test
```

Run the release (with NATS + `bot_army_runtime` connection as for other bots).

## Configuration

- `config :bot_army_general, :skills_root, "/path/to/skills"` — override directory (tests use this).

## Where this repo lives (Bot Army layout)

This app is a **separate git repository**, not committed inside the `elixir_bots` monorepo. The usual layout is a real checkout under **`../bots/bot_army_general`** next to the monorepo (see **`clone_base_bots`** in the monorepo’s `config/repos.toml`), with an optional symlink **`elixir_bots/bot_army_general` → `../bots/bot_army_general`** so tools see one workspace.

Step-by-step onboarding and symlink repair: **`docs/ONBOARDING.md`** and **`docs/WORKSPACE_SETUP.md`** in the **elixir_bots** repository.
