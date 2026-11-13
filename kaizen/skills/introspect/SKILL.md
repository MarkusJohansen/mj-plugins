---
name: introspect
description: Mine the user's own Claude Code footprint (~/.claude transcripts, history, plugins, marketplaces, skills, agents, hooks, memory) and write an evidence-backed overview of how they use Claude, their favourite tools, custom plugins, what's on offer in their marketplaces, what's in memory, underused capabilities and concrete habits to improve. Use when the user says "audit my claude usage", "how am I using claude", "what are my favourite tools/skills", "what am I underusing", "review my claude setup", "/introspect", or wants a retrospective on their Claude Code workflow.
---

# introspect

Produce a usage + setup audit of the user's Claude Code, grounded in numbers
from their own data. The miner does the counting; you do the judgement.

## 1. Mine

```bash
python3 -I "<this skill's base directory>/mine.py" --days 90 --out "${CLAUDE_JOB_DIR:-/tmp}/claude-usage.json"
```

`--days` sets the usage window (default 90; the user may ask for "this month",
"all time" = `--days 3650`). Inventory (plugins, skills, memory) is always the
current state. Runs in seconds; stdlib only. Read the JSON back with `jq` or a
short Python one-liner per section, not in one dump.

What the JSON holds:

| key | contents |
|---|---|
| `usage` | sessions, prompts, tool / skill / slash / subagent / MCP counts, models, bash heads, projects, hour-of-day, weekday, interrupts, compactions, tool errors, correction samples |
| `inventory` | settings summary, plugins (enabled, skills, commands, agents, hooks), marketplaces with every offered plugin and whether it's installed, user skills/agents, rules |
| `memory` | per-project memory files with type, size and description; agent-memory dirs |
| `gaps` | enabled skills/agents never invoked in the window, disabled plugins, built-in tools used < 5 times |

## 2. Read the context the miner can't judge

- `~/.claude/CLAUDE.md` (the user's global rules) — compare what it *asks*
  for (e.g. `/plan-first`, `/checklist`, OpenSpec, codebase-memory MCP first) with
  what `usage` shows actually happens. Rule-vs-behaviour drift is the most
  valuable finding.
- Memory files flagged in `memory.projects[].items` as `feedback` — repeated
  themes across projects are rules that belong in CLAUDE.md or a hook.
- For marketplaces, skim `inventory.marketplaces[].plugins` descriptions for
  the 5–10 not-installed plugins that fit the user's observed work (projects,
  bash heads, MCP use). Don't list all 300.

## 3. Write the report

Sections, in order. Every claim cites a number from the JSON.

1. **Snapshot** — window, sessions, prompts, active days, median session
   length, top projects. A small chart for hour-of-day or weekday if it shows
   a pattern.
2. **Favourite tools** — top built-in tools, skills (tool + slash combined),
   subagents, MCP servers, bash commands. Note what the mix says (e.g. Bash
   dominating Read/Grep means shelling out for file reads).
3. **Custom setup** — own plugins (`mj-plugins` and anything else the user
   authored), user skills and agents, hooks per event, status line, rules,
   CLAUDE.md size vs. its 200-line budget.
4. **Marketplaces** — each marketplace, plugin count, installed vs. enabled,
   and the shortlist of uninstalled plugins worth a look, with why.
5. **Memory** — projects with memory, counts by type, oversized indexes,
   duplicated or contradictory facts across projects, memories a CLAUDE.md
   rule now covers (candidates to delete).
6. **Underused** — `gaps` filtered by judgement: skills/agents installed but
   never used (keep, fix the description so it triggers, or uninstall), and
   built-in capabilities absent from the counts (plan mode, Workflow, Monitor,
   Cron/loops, worktrees, LSP, Artifacts, web search).
7. **Patterns and what to do better** — interrupts, correction samples,
   compactions, `/clear` frequency, prompt length, permission modes,
   rule-vs-behaviour drift. Each item: observation → evidence → one concrete
   action (a hook, a skill tweak, a CLAUDE.md edit, a habit).
8. **Top 5 actions** — ranked by payoff, each one line.

Deliver in chat (keep it scannable: tables, one chart). If the user wants it
shareable, hand off to `/htmlify` rather than building HTML here — and per the
global rule, never commit that HTML.

## Rules

- **Evidence or silence.** No claim without a number or a quoted file. If the
  data can't answer something (e.g. cost: transcripts rarely carry
  `totalCostUSD`, so `total_cost_usd` is usually 0), say so — don't estimate.
- **Honest, not flattering.** A setup with 15 plugins and 4 used is a finding,
  not a "rich ecosystem".
- **Scripted runs are excluded.** Sessions whose opening prompt shares a
  30-char prefix with ≥5 others (bench/eval loops) are dropped from usage;
  report `automated_sessions_excluded` / `automated_by_project` once so the
  user knows, then judge only the human sessions.
- **Counts are approximate.** Skills fired by a hook or auto-loaded don't show
  as `Skill` calls; slash-command and `Skill` counts overlap. Say "≈".
- **Privacy.** The report quotes the user's own prompts (correction samples);
  keep it local. Never post or upload it unless asked.
- **Plugin scope matters.** `inventory.plugins[].scope` may be `project`
  (with `projectPath`); its `enabled` flag from user settings is then
  meaningless, and removing it needs `claude plugin uninstall <id> --scope
  project` run from that path.
- **Read-only.** The audit changes nothing. Offer the fixes; apply them only
  on a yes (and via `/update-config` for settings/hooks).
