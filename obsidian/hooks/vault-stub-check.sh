#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit) — warns when a vault note's body
# (excluding frontmatter, abstract callout, and footnotes) is suspiciously
# short, i.e. likely an unfinished stub. Non-blocking; pure stderr.
#
# Threshold: ${CLAUDE_VAULT_STUB_WORDS:-40} words. Override via env var.

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')

if [[ -z "$path" ]]; then
  exit 0
fi

VAULT_ROOT="${CLAUDE_VAULT_PATH:-/Users/markusjohansen/vault-of-markus}"

case "$path" in
  "$VAULT_ROOT"/Templates/*) exit 0 ;;
  "$VAULT_ROOT"/.obsidian/*) exit 0 ;;
  "$VAULT_ROOT"/*.md) ;;
  *) exit 0 ;;
esac

case "$(basename "$path")" in
  CLAUDE.md|AGENTS.md|README.md|Home.md|Index.md) exit 0 ;;
esac

# Skip daily notes — they grow during the day and are stub-shaped on creation.
if [[ "$(basename "$path")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]]; then
  exit 0
fi

[[ -f "$path" ]] || exit 0

threshold="${CLAUDE_VAULT_STUB_WORDS:-40}"

# Strip frontmatter (first --- ... ---), abstract callout block, and footnote
# definitions, then count words in what remains.
words=$(awk '
  BEGIN { in_fm = 0; fm_done = 0; in_callout = 0 }
  NR == 1 && /^---$/ { in_fm = 1; next }
  in_fm && /^---$/ { in_fm = 0; fm_done = 1; next }
  in_fm { next }
  # Abstract / summary callout — skip until the first non-quoted line.
  !in_callout && /^>\[!(abstract|summary)\]/ { in_callout = 1; next }
  in_callout && /^>/ { next }
  in_callout { in_callout = 0 }
  # Footnote definitions at end of file.
  /^\[\^[^]]+\]:/ { next }
  { print }
' "$path" | wc -w | tr -d ' ')

if (( words < threshold )); then
  cat >&2 <<MSG
Vault stub check — $path:
  - body is $words words (threshold: $threshold). Possible stub / unfinished note.
  (warning only — run /find-stubs for a vault-wide audit)
MSG
fi

exit 0
