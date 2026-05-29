---
name: add-skill
description: Interview the user, then author a new Claude Code skill into their personal config repo (skills/<name>/SKILL.md). Use when the user says "add a skill", "create a skill", "build me a skill for X", "/add-skill", or describes a repeatable workflow they want Claude to run on command. Asks targeted questions first so the skill's description and trigger are specific, not vague.
---

# add-skill

Author a new skill into the user's config repo (the one scaffolded by
`/scaffold-config`, default `~/claude-config`). Skills are **verbs the main
session performs** — repeatable workflows Claude follows with its own tools.

## Locate the config repo

Resolve in order: `$CLAUDE_CONFIG_REPO`, then `~/claude-config`, then ask. If no
`skills/` dir exists there, suggest running `/scaffold-config` first.

## Interview (gather before writing)

Use **AskUserQuestion** for the choices, plain questions for free text. Get:

1. **What should the skill do?** One-sentence purpose, plus the concrete steps
   the workflow follows. If the user is vague, ask for a real example run.
2. **Name** — a verb or verb-qualifier (`write-pr`, `tidy-note`, `release`).
   Confirm it matches the `[a-z0-9-]+` convention and isn't already taken.
3. **Triggers** — the exact phrases / situations Claude should match on
   (`"draft a PR"`, `"/write-pr"`, "after finishing a feature"). These become the
   `description`, which is what actually fires the skill — make it specific and
   example-rich.
4. **Tools / commands** it relies on (git, gh, a test runner, an MCP server).
   Skills run with the main session's tools — don't assume tools it won't have.
5. **Guardrails** — anything it must NOT do, when it should refuse or stop.

## Author

Write `skills/<name>/SKILL.md` with frontmatter `name` (== folder) and
`description` (the triggers, written so they match). Body: numbered workflow
steps, a `## Rules` section for guardrails, and any examples. Drop helper files
alongside if useful. Keep it under ~150 lines — long skills lose adherence.

Skill body structure to follow:

```markdown
---
name: <name>
description: <what it does> Use when the user says "<trigger>", "/<name>", or <situation>. <key qualifiers>.
---

# <name>

<one-paragraph purpose>

## Steps
1. ...

## Rules
- ...
```

## Finish

1. Validate: `bash <repo>/bootstrap.sh validate`.
2. The skill is live via the `skills/` directory symlink (if bootstrap has run
   before) — tell the user to start a new session to pick it up, or run
   `./bootstrap.sh` if this is a brand-new repo.
3. Offer to add its trigger to `user-CLAUDE.md`'s "Skills I prefer" list.
4. Offer to commit.

## Rules

- **Interview first.** Don't write a skill from a one-line request — vague
  descriptions don't trigger reliably. Ask for the example run.
- **Verb-named.** Reject noun-only names unless the skill is a broad domain.
- **No invented behavior.** Implement what the user described; flag gaps, don't fill them with guesses.
- **One skill per invocation.** If they describe several, scaffold one and list the rest.
