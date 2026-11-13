#!/usr/bin/env bash
# Shared by the vault hooks. Source it; it reads the hook event from stdin.
#
# A hook that exits 0 and writes to stderr is never shown to Claude, so every note these
# hooks have for the model goes out as JSON `additionalContext` through tell_claude.

VAULT_ROOT="${CLAUDE_VAULT_PATH:-$HOME/vault-of-markus}"
VAULT_ROOT="${VAULT_ROOT%/}"
HOOK_INPUT=$(cat)

hook_field() {
  printf '%s' "$HOOK_INPUT" | jq -r "$1 // \"\"" 2>/dev/null
}

# tell_claude <hook event name> <message>
tell_claude() {
  jq -n --arg event "$1" --arg message "$2" \
    '{hookSpecificOutput: {hookEventName: $event, additionalContext: $message}}'
}

# Succeeds when the path is a knowledge note: a markdown file in the vault that is not a
# template, an Obsidian internal or one of the meta-files at the vault root.
is_vault_note() {
  case "$1" in
    "$VAULT_ROOT"/Templates/* | "$VAULT_ROOT"/.obsidian/*) return 1 ;;
    "$VAULT_ROOT"/*.md) ;;
    *) return 1 ;;
  esac
  case "$(basename "$1")" in
    CLAUDE.md | AGENTS.md | README.md | Home.md | Index.md) return 1 ;;
  esac
  [[ -f "$1" ]]
}
