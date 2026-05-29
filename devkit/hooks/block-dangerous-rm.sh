#!/usr/bin/env bash
# PreToolUse hook (Bash matcher) — blocks rm -r commands targeting root, home,
# or parent directories. Allows rm of relative paths under cwd.
# Exit 0 = allow, exit 2 = block (stderr shown to Claude).

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Only inspect commands that use rm with a recursive flag (-r, -R, -rf, etc).
if [[ ! "$cmd" =~ (^|[^A-Za-z0-9_])rm[[:space:]]+-[a-zA-Z]*[rR] ]]; then
  exit 0
fi

# Extract the first non-flag argument as the target.
if [[ "$cmd" =~ rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)+([^[:space:]]+) ]]; then
  target="${BASH_REMATCH[2]}"
else
  exit 0
fi

# Patterns must be quoted so bash does not expand ~ or treat * as a glob.
case "$target" in
  '/' | '~' | '~/' | '..' | '/Users' | '$HOME' | '${HOME}')
    block=1 ;;
  '/*' | '~/*')
    block=1 ;;
  '..'/* | '/Users'/* | '$HOME'/* | '${HOME}'/*)
    block=1 ;;
  *)
    block=0 ;;
esac

if (( block )); then
  cat >&2 <<MSG
Blocked: 'rm -r' targeting "$target" — root, home, or a parent directory.
If you really mean this, run it manually outside Claude.
MSG
  exit 2
fi

exit 0
