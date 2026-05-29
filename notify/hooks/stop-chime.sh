#!/usr/bin/env bash
# Stop hook — plays a quiet chime when Claude finishes a turn, but only if
# the user hasn't submitted a prompt recently. Suppresses chime spam during
# active back-and-forth (where the user is at the keyboard) regardless of
# how long Claude took to respond; only fires when you've likely walked away.

[[ "${CLAUDE_CHIME:-true}" != "true" ]] && exit 0

THRESHOLD="${CLAUDE_CHIME_MIN_IDLE:-30}"
STATE="${TMPDIR:-/tmp}/claude-last-prompt-$(id -u)"
now=$(date +%s)
last=$(cat "$STATE" 2>/dev/null || echo 0)

if (( now - last > THRESHOLD )); then
  if command -v afplay >/dev/null 2>&1; then
    afplay -v "${CLAUDE_CHIME_VOLUME:-0.6}" /System/Library/Sounds/Glass.aiff &
    disown
  fi
fi

exit 0
