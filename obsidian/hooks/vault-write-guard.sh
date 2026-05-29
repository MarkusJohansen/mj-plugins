#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit) — emits a stderr
# reminder when the target file is inside the Obsidian vault, per the vault's
# own CLAUDE.md rule ("never change ANYTHING in this vault without requesting
# permission"). Non-blocking: surfaces context, lets Claude decide.
#
# Bypass: set CLAUDE_VAULT_AUTHORIZED=1 in the session env.

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')

if [[ -z "$path" ]]; then
  exit 0
fi

VAULT_ROOT="${CLAUDE_VAULT_PATH:-/Users/markusjohansen/vault-of-markus}"

# Match the vault root and anything under it. Skip .obsidian/ internals.
case "$path" in
  "$VAULT_ROOT"/.obsidian/*) exit 0 ;;
  "$VAULT_ROOT"|"$VAULT_ROOT"/*) ;;
  *) exit 0 ;;
esac

if [[ "${CLAUDE_VAULT_AUTHORIZED:-}" == "1" ]]; then
  exit 0
fi

cat >&2 <<MSG
Vault edit reminder: "$path" is inside the Obsidian vault.
The vault's CLAUDE.md requires explicit user permission for any change.
Confirm the user has OK'd this specific edit before proceeding. Set
CLAUDE_VAULT_AUTHORIZED=1 in this session to silence further reminders.
MSG

exit 0
