#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit): when an instruction file Claude just
# edited is over budget, tells Claude (via additionalContext) to compact it now.
# Plain stderr with exit 0 never reaches the model, hence the JSON output.
#
# Budgets (lines, override via env):
#   CLAUDE_CONFIG_CLAUDEMD_MAX (200)  CLAUDE.md, user-CLAUDE.md, AGENTS.md, rules
#   CLAUDE_CONFIG_SKILLMD_MAX  (500)  SKILL.md
#   CLAUDE_CONFIG_MEMINDEX_MAX (200)  MEMORY.md (lines past 200 are cut at load)
#   CLAUDE_CONFIG_MEMFILE_MAX  (40)   one memory file = one fact

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
[[ -n "$path" && -f "$path" ]] || exit 0

real=$(readlink -f "$path" 2>/dev/null || python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$path")
base=$(basename "$real")

case "$real" in
  */.claude/rules/*.md)       max="${CLAUDE_CONFIG_CLAUDEMD_MAX:-200}"; kind="rule" ;;
  */memory/MEMORY.md)         max="${CLAUDE_CONFIG_MEMINDEX_MAX:-200}"; kind="memory index" ;;
  */.claude/projects/*/memory/*.md) max="${CLAUDE_CONFIG_MEMFILE_MAX:-40}"; kind="memory file" ;;
  *)
    case "$base" in
      CLAUDE.md|user-CLAUDE.md|CLAUDE.local.md|AGENTS.md) max="${CLAUDE_CONFIG_CLAUDEMD_MAX:-200}"; kind="$base" ;;
      SKILL.md) max="${CLAUDE_CONFIG_SKILLMD_MAX:-500}"; kind="SKILL.md" ;;
      *) exit 0 ;;
    esac
    ;;
esac

lines=$(wc -l < "$real" | tr -d ' ')
(( lines > max )) || exit 0

msg="$path is a $kind of $lines lines, over its $max-line budget. Compact it now, in this turn: merge duplicates, delete stale or superseded rules, fold one-off lessons into the general rule, move long examples or reference detail into a linked file. Never drop a rule that still earns its place. Report what you cut in one line. If it's a shared team file, propose the compaction instead of applying it."
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
exit 0
