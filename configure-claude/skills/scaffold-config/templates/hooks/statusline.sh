#!/usr/bin/env bash
# Claude Code statusLine hook. Prints: model · dir (git-branch)
# Receives a JSON blob on stdin describing the current session.
set -euo pipefail

input="$(cat)"

model="$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "claude"' 2>/dev/null || echo claude)"
cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null || true)"
[[ -z "$cwd" ]] && cwd="$PWD"
dir="$(basename "$cwd")"

branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"
fi

if [[ -n "$branch" ]]; then
  printf '%s · %s (%s)' "$model" "$dir" "$branch"
else
  printf '%s · %s' "$model" "$dir"
fi
