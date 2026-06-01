---
name: commit
description: Stage and create a git commit with a consistent message format. Use when the user says "commit this", "make a commit", or "write a commit message". Mirrors the title convention used by the `write-pr` skill so commits and PRs read consistently.
---

# commit

Read the diff (`git status`, `git diff --staged`, `git diff`), then commit with a message grounded in what actually changed — not from memory.

## Message format

Subject: `[type][Domain] Summary`

- **type** — `feat`, `fix`, `refactor`, `perf`, `test`, `chore`, `docs`
- **Domain** — area touched (`Auth`, `API`, `CI`)
- **Summary** — present tense, specific, ≤72 chars. "Add JWT expiry handling to AuthService", not "Fix auth bug".

Add a body only when *why* isn't obvious from the subject: a line or two on motivation, the Jira ticket, or a non-obvious trade-off. Skip it for typos and dependency bumps.

## Guardrails

- Nothing staged? Ask whether to stage everything or specific files — never silently `git add -A`.
- One logical change per commit; suggest splitting an unrelated diff.
- Never `--no-verify` or `--amend` a pushed commit. If a hook fails, fix the cause and commit fresh.
- Don't commit `.env`, credentials, or key files — warn loudly if asked to.
