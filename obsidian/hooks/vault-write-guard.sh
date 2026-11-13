#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit): the first time a session is about to
# change a file inside the Obsidian vault, tells Claude the vault's own rule ("never change
# anything in this vault without requesting permission"). The edit itself is not blocked.
#
# Bypass: set CLAUDE_VAULT_AUTHORIZED=1 in the session env.

# shellcheck source=vault-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/vault-lib.sh"

path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path')
case "$path" in
  "$VAULT_ROOT"/.obsidian/*) exit 0 ;;
  "$VAULT_ROOT" | "$VAULT_ROOT"/*) ;;
  *) exit 0 ;;
esac
[[ "${CLAUDE_VAULT_AUTHORIZED:-}" == "1" ]] && exit 0

session=$(hook_field '.session_id')
reminded_dir="${TMPDIR:-/tmp}/claude-vault-guard"
reminded="$reminded_dir/${session//[^A-Za-z0-9_-]/_}"
[[ -n "$session" && -f "$reminded" ]] && exit 0
mkdir -p "$reminded_dir" 2>/dev/null && touch "$reminded" 2>/dev/null
find "$reminded_dir" -type f -mtime +7 -delete 2>/dev/null

tell_claude PreToolUse "Vault edit reminder: \"$path\" is inside the Obsidian vault at $VAULT_ROOT. The vault's CLAUDE.md requires explicit user permission for any change. If the user has not OK'd this specific edit, undo it and ask first. This reminder is given once per session."
exit 0
