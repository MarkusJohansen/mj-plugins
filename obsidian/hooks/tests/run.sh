#!/usr/bin/env bash
# Tests for the obsidian hooks. Each case feeds a hook event on stdin and reads the note
# the hook hands to Claude (hookSpecificOutput.additionalContext), or the stdout a
# SessionStart hook adds to the context.
#
# Run:   hooks/tests/run.sh
# Exit:  0 if all assertions pass, 1 otherwise.

set -u

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
VAULT="$SANDBOX/vault"
mkdir -p "$VAULT/Templates" "$VAULT/.obsidian" "$SANDBOX/elsewhere" "$SANDBOX/tmp"
export CLAUDE_VAULT_PATH="$VAULT" TMPDIR="$SANDBOX/tmp"
unset CLAUDE_VAULT_AUTHORIZED CLAUDE_VAULT_STUB_WORDS
pass=0
fail=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1))
  else
    printf '  FAIL  %s: expected %s, got %s\n' "$name" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

# context <hook> <session> <file path>: the note the hook gives Claude, empty when silent.
context() {
  jq -n --arg session "$2" --arg path "$3" '{session_id: $session, tool_input: {file_path: $path}}' \
    | bash "$HOOKS/$1" 2>/dev/null | jq -rs '.[0].hookSpecificOutput.additionalContext // ""'
}
mentions() { grep -c -- "$1" <<<"$2"; }

long_body=$(printf 'word %.0s' $(seq 1 60))
printf -- '---\ncategories: [fishing]\ndate: 2026-01-01\n---\n>[!abstract]\n> About trout.\n\n%s\n' "$long_body" > "$VAULT/Complete.md"
printf 'Just a line.\n' > "$VAULT/Bare.md"
printf -- '---\ncategories: [fishing]\ndate: 2026-01-01\n---\n>[!abstract]\n> About trout.\n\nToo short.\n' > "$VAULT/Stub.md"
printf 'Today.\n' > "$VAULT/2026-01-01.md"
cp "$VAULT/Bare.md" "$VAULT/Templates/Template.md"
cp "$VAULT/Bare.md" "$VAULT/README.md"
cp "$VAULT/Bare.md" "$SANDBOX/elsewhere/Note.md"

echo "vault-note-check.sh:"
check "a complete note is silent" "" "$(context vault-note-check.sh s1 "$VAULT/Complete.md")"
bare=$(context vault-note-check.sh s1 "$VAULT/Bare.md")
check "a bare note is reported for its frontmatter" 1 "$(mentions 'no frontmatter block' "$bare")"
check "a bare note is reported for its abstract" 1 "$(mentions 'abstract. callout' "$bare")"
check "a bare note is reported as a stub" 1 "$(mentions 'stub threshold' "$bare")"
stub=$(context vault-note-check.sh s1 "$VAULT/Stub.md")
check "a short note with good frontmatter is only a stub" 0 "$(mentions '^- .*frontmatter' "$stub")"
check "the stub report gives the word count" 1 "$(mentions 'the body is 2 words' "$stub")"
daily=$(context vault-note-check.sh s1 "$VAULT/2026-01-01.md")
check "a daily note is not a stub" 0 "$(mentions 'stub threshold' "$daily")"
check "a template is silent" "" "$(context vault-note-check.sh s1 "$VAULT/Templates/Template.md")"
check "a vault meta-file is silent" "" "$(context vault-note-check.sh s1 "$VAULT/README.md")"
check "a note outside the vault is silent" "" "$(context vault-note-check.sh s1 "$SANDBOX/elsewhere/Note.md")"
check "the hook names its event" PostToolUse \
  "$(jq -n --arg path "$VAULT/Bare.md" '{tool_input: {file_path: $path}}' \
      | bash "$HOOKS/vault-note-check.sh" | jq -r '.hookSpecificOutput.hookEventName')"

echo "vault-write-guard.sh:"
first=$(context vault-write-guard.sh g1 "$VAULT/Complete.md")
check "the first vault edit of a session is flagged" 1 "$(mentions 'requires explicit user permission' "$first")"
check "the reminder comes once per session" "" "$(context vault-write-guard.sh g1 "$VAULT/Stub.md")"
check "another session is reminded again" 1 "$(mentions 'Vault edit reminder' "$(context vault-write-guard.sh g2 "$VAULT/Stub.md")")"
check "an edit outside the vault is silent" "" "$(context vault-write-guard.sh g3 "$SANDBOX/elsewhere/Note.md")"
check "Obsidian's own files are silent" "" "$(context vault-write-guard.sh g3 "$VAULT/.obsidian/app.json")"
check "an authorised session is silent" "" "$(CLAUDE_VAULT_AUTHORIZED=1 context vault-write-guard.sh g4 "$VAULT/Stub.md")"
check "the guard never sets a permission decision" null \
  "$(jq -n --arg path "$VAULT/Bare.md" '{session_id: "g5", tool_input: {file_path: $path}}' \
      | bash "$HOOKS/vault-write-guard.sh" | jq -r '.hookSpecificOutput.permissionDecision')"

echo "vault-rule.sh:"
rule_for() { jq -n --arg cwd "$1" '{cwd: $cwd}' | bash "$HOOKS/vault-rule.sh"; }
in_vault=$(rule_for "$VAULT")
check "a session in the vault gets the rule" 1 "$(mentions '^# Working in the Obsidian vault' "$in_vault")"
check "the vault path is filled in" 0 "$(mentions '__VAULT_PATH__' "$in_vault")"
check "a session in a vault subfolder gets the rule" 1 \
  "$(mentions '^# Working in the Obsidian vault' "$(rule_for "$VAULT/Templates")")"
check "a session elsewhere gets nothing" "" "$(rule_for "$SANDBOX/elsewhere")"
check "a folder that only shares the vault's prefix gets nothing" "" "$(rule_for "$VAULT-archive")"

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
