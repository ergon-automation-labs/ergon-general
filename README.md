# bot_army_general

Fleet-wide **general-purpose** bot: serves **base markdown skills** from `priv/skills/*.md` over NATS (no database).

## NATS subjects

| Subject | Mode | Body (JSON) | Response |
|---------|------|---------------|----------|
| `bot_army.general.skill.list` | request/reply | `{}` (optional) | `{"skills":[%{slug,name,description},...]}` |
| `bot_army.general.skill.get` | request/reply | `{"slug":"playwright_operator"}` | `slug`, `frontmatter`, `markdown` or `error` |
| `system.health.bot_army_general` | publish | — | JSON health pulse |

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
