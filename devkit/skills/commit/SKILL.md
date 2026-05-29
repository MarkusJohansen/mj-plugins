---
name: commit
description: Stage and create a git commit with a consistent message format. Use when the user says "commit this", "make a commit", or "write a commit message". Mirrors the title convention used by the `write-pr` skill so commits and PRs read consistently.
---

# commit

Create a git commit with a clear, specific message grounded in the actual diff. Never commit without the user's explicit go-ahead in this session.

## Preparation

Run these in parallel before drafting a message:

1. `git status` (no `-uall`) — see what's staged, unstaged, untracked.
2. `git diff --staged` and `git diff` — read both. Draft messages from the diff, not from memory.
3. `git log -n 5 --oneline` — match the repo's existing tone if it diverges from this convention.

If nothing is staged, decide with the user whether to stage everything, stage specific files, or abort. Never silently `git add -A` — it can sweep in `.env`, large binaries, or unrelated work.

## Message format

**Subject line:** `[type][Domain] Summary`

- **Type** — `feat`, `fix`, `refactor`, `perf`, `test`, `chore`, `docs`
- **Domain** — short tag for the area touched (e.g. `Auth`, `API`, `CI`)
- **Summary** — present tense, specific, under 72 chars total. "Add JWT expiry handling to AuthService" not "Fix auth bug"

**Body** (when the change isn't self-evident from the subject):

- 1–3 short paragraphs or bullets. Focus on *why*, not *what* — the diff already shows what.
- Reference the originating Jira ticket if applicable.
- Mention any non-obvious trade-off, follow-up, or rollback note.

Skip the body for trivial changes (typo fixes, dependency bumps, single-line tweaks).

## Rules

- One logical change per commit. If the diff spans two unrelated concerns, suggest splitting before committing.
- Never `--amend` a previously-pushed commit unless the user explicitly asks.
- Never `--no-verify`. If a hook fails, fix the underlying issue and create a new commit — do not modify the failed one.
- Don't commit files that likely contain secrets (`.env`, `credentials.*`, key files). Warn loudly if the user insists.

## Submission

Always pass the message via heredoc to preserve formatting:

```sh
git commit -m "$(cat <<'EOF'
[type][Domain] Summary

Optional body explaining why.
EOF
)"
```

After committing, run `git status` to confirm a clean tree.
