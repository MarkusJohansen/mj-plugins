#!/usr/bin/env bash
# Weekly self-review and self-improvement, run by launchd (see setup.sh).
#
# Runs from the marketplace clone (~/.claude/plugins/marketplaces/<marketplace>/kaizen),
# which launchd can read; it can't read ~/Documents (macOS privacy).
# 1. Mine the last 7 days: usage (introspect), instruction-file budgets, shell recipes.
#    Every output is redacted with ~/.claude/private-terms.json before Claude reads it.
# 2. Claude writes a week-over-week report into $KAIZEN_REPORT_DIR.
# 3. Claude makes at most two evidence-backed fixes to this plugin on a kaizen/<date>
#    branch of its own clone ($TARGET), commits there (never pushes) and says how to merge.
# User settings are skipped (--setting-sources): their hooks may live in ~/Documents, and an
# unreadable PreToolUse hook blocks every tool call. Absolute paths in --allowedTools rules
# need a leading // (one / is project-relative), hence "/$OUTDIR".
set -euo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HIST="$HOME/.claude/introspect-history"
OUTDIR="${KAIZEN_REPORT_DIR:-$HOME/second-brain/_system/introspect}"
TARGET="$HOME/.claude/kaizen/$(basename "$(dirname "$PLUGIN")")"
SOURCE_HINT="${KAIZEN_SOURCE:-the plugin repo checkout}"
TODAY=$(date +%F)
BRANCH="kaizen/$TODAY"
WORK_DIR="$(dirname "$OUTDIR")"
mkdir -p "$HIST" "$OUTDIR"

CLAUDE_BIN="$HOME/.local/bin/claude"
[[ -x "$CLAUDE_BIN" ]] || CLAUDE_BIN=$(zsh -lc 'command -v claude')

python3 -I "$PLUGIN/skills/introspect/mine.py" --days 7 --out "$HIST/$TODAY.json"
python3 -I "$PLUGIN/scripts/harness-scan.py" > "$HIST/scan-$TODAY.txt"
python3 -I "$PLUGIN/scripts/shell-patterns.py" --days 7 --out "$HIST/shell-$TODAY.json"
cp "$HOME/.claude/learn-stats.json" "$HIST/learn-stats.json" 2>/dev/null || true
python3 -I "$PLUGIN/scripts/redact.py" "$HIST/$TODAY.json" "$HIST/scan-$TODAY.txt" "$HIST/shell-$TODAY.json"
PREV=$(ls "$HIST"/20*.json 2>/dev/null | grep -v "$TODAY" | tail -1 || true)

PRIVACY="Never write an employer, client or work-project name; the data is redacted to <work>, keep it that way."

REPORT_PROMPT="Weekly Claude Code self-review. Data: $HIST/$TODAY.json (last 7 days, from the introspect skill's mine.py)${PREV:+; previous run: $PREV}.
Read the JSON with jq or short python one-liners per key, not in one dump.
Write $OUTDIR/$TODAY.md. Frontmatter exactly: categories: [system], created: $TODAY, tags: [claude-code], related: []. Then:
1. One sentence: the single most important change since last week (or 'first report' if none).
2. A table: sessions, prompts, median prompt length, /clear count, Bash vs Read calls, interrupts, corrections, this week vs last week.
3. Learning tracks: uses of TaskCreate, CronCreate, Workflow, Artifact, LSP, EnterPlanMode, codebase-memory MCP this week (0 is a finding). Plus learn mode, from $HIST/learn-stats.json if it exists (running totals: sessions, turns, blockedEdits).
4. Up to 3 quoted correction samples and whether a skill/CLAUDE.md/memory file was edited the same week.
5. Harness upkeep, from $HIST/scan-$TODAY.txt: for each instruction file over budget, one line proposing what to cut or move. For each prompt repeated 3+ times in a project, propose a local skill: one-word name + what it would do. Propose only.
6. Shell recipes, from $HIST/shell-$TODAY.json: Bash calls and output (chars/4 = tokens), the 3 costliest repeated shapes with one sample each, and the shell-habits nudge hits (a rule mostly 'passed' means its helper lacks something).
7. Three concrete actions for next week, one line each.
Max 65 lines. Plain words, explain any jargon. Evidence or silence: every claim cites a number. $PRIVACY Do not edit any other file."

cd "$WORK_DIR"
"$CLAUDE_BIN" -p "$REPORT_PROMPT" \
  --model sonnet --setting-sources project,local \
  --add-dir "$HIST" --add-dir "$OUTDIR" \
  --allowedTools "Read" "Write(/$OUTDIR/**)" "Bash(jq *)" "Bash(python3 -c *)" "Bash(ls *)"

if ! git -C "$TARGET" fetch -q origin main; then
  echo "Self-improvement skipped: could not fetch origin for $TARGET." >> "$OUTDIR/$TODAY.md"
  exit 0
fi
git -C "$TARGET" checkout -q -f -B "$BRANCH" origin/main

IMPROVE_PROMPT="You are the weekly self-improvement run for this Claude Code setup. Your working directory ($TARGET) is a clone of the plugin marketplace on branch $BRANCH; the plugin to improve is kaizen/. Read the repo's README and kaizen/README.md first.
Evidence: $OUTDIR/$TODAY.md (this week's report), $HIST/shell-$TODAY.json (repeated shell recipes and nudge hits), $HIST/scan-$TODAY.txt (instruction files over budget).
Pick at most TWO changes, each backed by a number from the evidence, in order of preference:
- a shell recipe repeated in 3+ sessions costing 20K+ chars: a helper in kaizen/scripts/ (setup.sh links helpers onto PATH), a rule in kaizen/hooks/shell-habits.py pointing at it, a test in kaizen/hooks/tests/run.sh, and a line in kaizen/README.md;
- a shell-habits rule mostly 'passed': extend its helper so the pass-through is no longer needed, or narrow the pattern;
- a skill in this repo over its 500-line budget: move detail into a linked reference file, never dropping a rule that still earns its place.
Never edit files outside kaizen/, never delete a hook or skill, never weaken name-guard. $PRIVACY If nothing clears the bar, change nothing.
Run 'bash kaizen/hooks/tests/run.sh' BEFORE editing and again after. If a test that passed before now fails and you can't fix it, 'git checkout .' and report it. Otherwise bump the patch version in kaizen/.claude-plugin/plugin.json, and commit on $BRANCH with a '[chore][kaizen] <summary>' title and a body citing the evidence. Do not push.
Then append to $OUTDIR/$TODAY.md a section '## Self-improvement' (max 15 lines): what changed and why (with the numbers), or why nothing did, and the command to take it into $SOURCE_HINT: git fetch $TARGET $BRANCH && git merge FETCH_HEAD"

cd "$TARGET"
"$CLAUDE_BIN" -p "$IMPROVE_PROMPT" \
  --model sonnet --setting-sources project,local \
  --add-dir "$HIST" --add-dir "$OUTDIR" \
  --allowedTools "Read" "Edit(/$TARGET/**)" "Write(/$TARGET/**)" "Edit(/$OUTDIR/**)" "Write(/$OUTDIR/**)" \
    "Bash(git status*)" "Bash(git diff*)" "Bash(git add *)" "Bash(git commit *)" "Bash(git checkout .)" \
    "Bash(git log*)" "Bash(bash kaizen/hooks/tests/run.sh)" "Bash(python3 *)" "Bash(jq *)" "Bash(ls *)" "Bash(wc *)"
