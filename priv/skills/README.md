# Fleet-wide base skills (markdown)

Add one file per skill: **`slug`.md** where `slug` matches `^[a-z0-9][a-z0-9_]*$`.

Optional YAML frontmatter (first lines):

```markdown
---
name: Human-readable title
description: One line for catalogs
---

Markdown body shown to operators or LLM harnesses.
```

Consumers fetch via NATS (see bot README): `bot_army.general.skill.list` and `bot_army.general.skill.get`.
