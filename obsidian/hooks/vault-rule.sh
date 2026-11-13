#!/usr/bin/env bash
# SessionStart: when the session starts inside the Obsidian vault, prints the vault rule
# (rules/vault.md) so it lands in Claude's context. Plugins cannot ship path-scoped rules,
# and a SessionStart hook's stdout is added to the context, so this is how the rule loads.

# shellcheck source=vault-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/vault-lib.sh"

cwd=$(hook_field '.cwd')
case "${cwd:-$PWD}/" in
  "$VAULT_ROOT"/*) ;;
  *) exit 0 ;;
esac

rule="$(dirname "${BASH_SOURCE[0]}")/../rules/vault.md"
[[ -f "$rule" ]] || exit 0
awk -v vault="$VAULT_ROOT" '{ gsub(/__VAULT_PATH__/, vault); print }' "$rule"
exit 0
