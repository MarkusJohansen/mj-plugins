#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): after a vault note is saved, tells Claude what the
# note still lacks. Never blocks and never fixes anything itself.
#
# - frontmatter with `categories` and `date`;
# - an `>[!abstract]` (or `>[!summary]`) callout in the first 30 lines;
# - a body of at least ${CLAUDE_VAULT_STUB_WORDS:-40} words, not counting frontmatter, the
#   abstract callout and footnote definitions. Daily notes (YYYY-MM-DD.md) are exempt: they
#   start out stub-shaped and grow during the day.

# shellcheck source=vault-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/vault-lib.sh"

ABSTRACT_SEARCH_LINES=30
path=$(hook_field '.tool_input.file_path')
is_vault_note "$path" || exit 0

findings=()

if [[ "$(head -n 1 "$path")" != "---" ]]; then
  findings+=("no frontmatter block (the file should start with '---')")
else
  frontmatter=$(awk 'NR==1 && /^---$/ {inside=1; next} inside && /^---$/ {exit} inside' "$path")
  grep -q '^categories:' <<<"$frontmatter" || findings+=("frontmatter has no 'categories'")
  grep -q '^date:' <<<"$frontmatter" || findings+=("frontmatter has no 'date'")
fi

if ! head -n "$ABSTRACT_SEARCH_LINES" "$path" | grep -Eq '^>\[!(abstract|summary)\]'; then
  findings+=("no >[!abstract] callout near the top (/abstract-note writes one)")
fi

if [[ ! "$(basename "$path")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]]; then
  threshold="${CLAUDE_VAULT_STUB_WORDS:-40}"
  words=$(awk '
    NR == 1 && /^---$/ { in_frontmatter = 1; next }
    in_frontmatter && /^---$/ { in_frontmatter = 0; next }
    in_frontmatter { next }
    !in_callout && /^>\[!(abstract|summary)\]/ { in_callout = 1; next }
    in_callout && /^>/ { next }
    in_callout { in_callout = 0 }
    /^\[\^[^]]+\]:/ { next }
    { print }
  ' "$path" | wc -w | tr -d ' ')
  if (( words < threshold )); then
    findings+=("the body is $words words, under the $threshold-word stub threshold: possibly an unfinished note")
  fi
fi

(( ${#findings[@]} == 0 )) && exit 0

message="Vault note check for $path:"
for finding in "${findings[@]}"; do
  message+=$'\n'"- $finding"
done
message+=$'\n'"Tell the user in one line. Fix only what they asked for; /tidy-note repairs frontmatter and structure."
tell_claude PostToolUse "$message"
exit 0
