# bot_army_general

**General-purpose orchestrator** for the Bot Army: out-of-domain asks (skills discovery + LLM) and operator close-out (PARA + notification).

Registry id: **`bot_army_general_purpose`**.

## Skills platform (not in this repo)

Fleet markdown: `bot_army_skills/priv/canonical_skills/*.md` → Postgres → `skills_bot`.

| Action | NATS |
|--------|------|
| List / read | `bot.army.skills.content.list`, `bot.army.skills.content.get` |
| Suggest installs | `bot.army.skills.catalog.suggest` |
| Run skill | `bot.army.skills.command.<slug>` |

## NATS subjects (this bot)

| Subject | Purpose |
|---------|---------|
| `bot_army.general_purpose.ask` | Discover installed skills, suggest missing, LLM answer |
| `bot_army.general_purpose.operator.complete` | PARA `inbox/bots/general_purpose.md` + notification intent |
| `bot_army.general.operator.complete` | Deprecated alias |
| `system.health.bot_army_general_purpose` | Health pulse |

## Release

- Primary: **`general_purpose_bot`** (`general_purpose_bot-VERSION.tar.gz`)
- Alias: `general_bot` (same app, transitional)

## Local

```bash
make deps
make test
```

Monorepo: `docs/GENERAL_BOT_OPERATOR_FLOW.md`, `scripts/general_operator_complete.py`.
