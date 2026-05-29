#!/usr/bin/env bash
# UserPromptSubmit hook — records the time of the user's last prompt so the
# Stop chime can tell whether the user is still actively engaged.

STATE="${TMPDIR:-/tmp}/claude-last-prompt-$(id -u)"
date +%s > "$STATE"
exit 0
