#!/usr/bin/env bash
# Notification hook — shows a macOS banner when Claude wants the user's
# attention (e.g. permission requests, idle prompts, long-task completion
# announcements). Complementary to stop-chime.sh: chime = "I'm done",
# banner = "I need you".

input=$(cat)
message=$(printf '%s' "$input" | jq -r '.message // "Claude needs your attention"')
title=$(printf '%s' "$input" | jq -r '.title // "Claude Code"')

# Escape backslashes and double quotes so they survive AppleScript's string parsing.
escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
m=$(escape "$message")
t=$(escape "$title")

if command -v osascript >/dev/null 2>&1; then
  /usr/bin/osascript -e "display notification \"$m\" with title \"$t\"" >/dev/null 2>&1 &
  disown
fi

exit 0
