#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit) — warns to stderr when a markdown
# file inside the vault is missing required frontmatter (categories, date)
# or the abstract callout. Non-blocking. Does not auto-fix.

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

# Meta-files at the vault root aren't knowledge notes — don't enforce the
# frontmatter + abstract convention on them.
case "$(basename "$path")" in
  CLAUDE.md|AGENTS.md|README.md|Home.md|Index.md) exit 0 ;;
esac

[[ -f "$path" ]] || exit 0

warnings=()

# Frontmatter must be the first thing in the file.
first=$(head -n 1 "$path")
if [[ "$first" != "---" ]]; then
  warnings+=("missing frontmatter block (file should start with '---')")
else
  # Extract the frontmatter block (between first and second '---').
  fm=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$path")

  grep -q '^categories:' <<<"$fm" || warnings+=("frontmatter missing 'categories'")
  grep -q '^date:' <<<"$fm" || warnings+=("frontmatter missing 'date'")
fi

# A summary-style callout should appear in the first ~30 lines.
# Accept >[!abstract] (preferred per vault convention) or >[!summary] — both
# serve the "what is this note about" role. Other callouts (info, warning,
# note) don't count.
if ! head -n 30 "$path" | grep -Eq '^>\[!(abstract|summary)\]'; then
  warnings+=("missing >[!abstract] (or >[!summary]) callout near the top")
fi

if (( ${#warnings[@]} > 0 )); then
  {
    echo "Vault frontmatter check — $path:"
    for w in "${warnings[@]}"; do
      echo "  - $w"
    done
    echo "  (warning only — run /tidy-note to address)"
  } >&2
fi

exit 0
