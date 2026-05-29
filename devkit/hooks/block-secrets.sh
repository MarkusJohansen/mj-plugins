#!/usr/bin/env bash
# PreToolUse hook (Bash matcher) — when Claude is about to run `git commit`,
# scan the staged diff for strong-signal secret patterns and block if found.
# Designed for high precision (low false-positive rate) — only blocks on
# patterns that are nearly always real secrets.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Only intercept git commit invocations.
case "$cmd" in
  *"git commit"*|*"git "*"commit "*) ;;
  *) exit 0 ;;
esac

cwd=$(printf '%s' "$input" | jq -r '.tool_input.cwd // .cwd // "."')

diff=$(cd "$cwd" 2>/dev/null && git diff --cached 2>/dev/null) || exit 0
[[ -z "$diff" ]] && exit 0

# Only inspect added lines (+) — removing a secret can't leak it. Strip the
# leading `+` and drop the `+++ file` header lines.
diff=$(printf '%s\n' "$diff" | awk '/^\+\+\+/ {next} /^\+/ {print substr($0,2)}')
[[ -z "$diff" ]] && exit 0

# Strong-signal patterns — each is rarely a false positive in a real diff.
patterns=(
  'AKIA[0-9A-Z]{16}'
  'aws_secret_access_key[[:space:]]*='
  'ghp_[A-Za-z0-9]{36,}'
  'gho_[A-Za-z0-9]{36,}'
  'ghs_[A-Za-z0-9]{36,}'
  'ghu_[A-Za-z0-9]{36,}'
  'github_pat_[A-Za-z0-9_]{82,}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'xox[abporsu]-[A-Za-z0-9-]{10,}'
  'sk-[A-Za-z0-9]{32,}'
  'sk-ant-[A-Za-z0-9-]{20,}'
)

for pat in "${patterns[@]}"; do
  match=$(printf '%s' "$diff" | grep -nE -- "$pat" | head -1 || true)
  if [[ -n "$match" ]]; then
    cat >&2 <<MSG
Blocked: staged diff appears to contain a secret.
Pattern: $pat
Match (line, redacted): ${match%%=*}
Review with 'git diff --cached', unstage with 'git restore --staged <file>',
or commit manually if you are certain this is intentional.
MSG
    exit 2
  fi
done

exit 0
