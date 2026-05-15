---
name: Playwright operator playbook
description: Baseline guidance for browser automation via Playwright (operator context, safety, traces).
---

# Playwright operator playbook

This is a **filesystem base skill**: versioned with the `bot_army_general` release, shared fleet-wide.

## Role

Use when an operator or agent should drive a real browser (navigation, forms, assertions) with Playwright.

## Safety

- Run automation only in **approved** environments; never against production tenant data without explicit scope.
- Prefer **headed vs headless** based on policy; capture **video/trace** on failure.
- Treat selectors as brittle — prefer role/name locators and stable test ids agreed with the app team.

## Flow

1. Define the user goal and **happy path** plus one **failure** case to observe.
2. Stabilize login/session (fixtures, storage state) outside hot paths when possible.
3. After edits, run a **single focused spec** before the full suite.

## Integration note

Executable Playwright belongs in a **sandboxed worker** with a narrow API; this markdown is the **shared procedure** layer until that worker is wired. Callers should fetch this skill via `bot_army.general.skill.get` with `{"slug":"playwright_operator"}`.
