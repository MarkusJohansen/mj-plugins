---
name: add-hook
description: Interview the user, then author a Claude Code hook script and wire it into their config repo's settings.template.json. Use when the user says "add a hook", "create a hook", "run X automatically when Y", "before/after every tool call do X", "notify me when Claude finishes", or "/add-hook". Hooks are how the harness runs deterministic automation that Claude itself cannot — events like PreToolUse, PostToolUse, Stop, Notification, UserPromptSubmit.
---

# add-hook

Author a hook script under `hooks/` and wire it into `settings.template.json` in
the user's config repo (default `~/claude-config`). Hooks are shell commands the
**harness** runs on lifecycle events — the right tool for "always do X when Y"
automation, which Claude's own behavior can't guarantee.

## Locate the config repo

Resolve in order: `$CLAUDE_CONFIG_REPO`, then `~/claude-config`, then ask. If no
`settings.template.json` exists, suggest `/scaffold-config` first.

## Interview (gather before writing)

Use **AskUserQuestion** for the event/matcher choices, plain questions for free
text. Get:

1. **What should happen, and when** — the trigger in plain words, then map it to
   an event:
   - `PreToolUse` — before a tool runs; can **block** it (exit 2 + stderr).
   - `PostToolUse` — after a tool runs (e.g. auto-format an edited file).
   - `UserPromptSubmit` — when the user submits a prompt.
   - `Stop` / `SubagentStop` — when Claude finishes a turn (e.g. chime/notify).
   - `Notification` — when Claude needs attention (e.g. desktop banner).
   - `SessionStart` / `SessionEnd`.
2. **Matcher** (for PreToolUse/PostToolUse) — which tools, e.g. `Bash`,
   `Edit|Write|MultiEdit`, or `.*` for all.
3. **Behavior** — exactly what the script does. Hooks receive a JSON event on
   **stdin**; for blocking PreToolUse hooks, exit non-zero and write the reason
   to stderr.
4. **Blocking or advisory?** Be explicit: regex "security" hooks are speed bumps,
   not controls — say so if they ask for one.

## Author

1. Write `hooks/<name>.sh`, executable, reading the event JSON from stdin with
   `jq`. Keep it fast and dependency-light (`jq` is fine). Example skeleton:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   input="$(cat)"
   # tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
   # ...decide, then: exit 0 (allow) or  echo "reason" >&2; exit 2  (block, PreToolUse)
   ```

2. Wire it into `settings.template.json` under the right event, using a
   `__REPO__` path so bootstrap renders it:

   ```json
   "PostToolUse": [
     { "matcher": "Edit|Write|MultiEdit",
       "hooks": [ { "type": "command", "command": "bash \"__REPO__/hooks/<name>.sh\"" } ] }
   ]
   ```

   Merge into existing arrays for that event — don't clobber other hooks.

3. `chmod +x hooks/<name>.sh`.

## Finish

1. Validate: `bash <repo>/bootstrap.sh validate` (checks the hook exists and is
   executable and the JSON parses).
2. Hooks load from rendered `settings.json`, so **re-run `./bootstrap.sh`** and
   tell the user to restart Claude Code to load the new hook.
3. Offer to commit.

## Rules

- **Hooks are deterministic automation** — use them for "always/never" rules the
  model can't be relied on to follow. Don't reach for a hook when a CLAUDE.md
  instruction or a skill is enough.
- **Be honest about security hooks.** String/regex matchers on commands are speed
  bumps with known bypasses, not real controls. Say so.
- **Don't break existing wiring.** Merge into the event's array; keep `__REPO__` paths.
- **Test the script** against a sample stdin JSON before declaring it done.
