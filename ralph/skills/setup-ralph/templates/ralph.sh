#!/usr/bin/env bash
# Supervised Ralph loop for __PROJECT_NAME__.
#
# Each iteration: feeds PROMPT.md to the agent in headless (non-interactive)
# mode, then pauses so you can inspect the diff before the next loop.
# Graduate to an unattended loop
# (`while :; do cat PROMPT.md | __AGENT_CMD__ -p --permission-mode acceptEdits; done`)
# only once you trust the setup.
#
# IMPORTANT: the agent MUST run in headless mode (`-p` / `--print` for the
# `claude` CLI) so each iteration exits on its own. Without `-p` the CLI
# drops into an interactive REPL and the loop hangs waiting for you to
# Ctrl+C out of it.

set -u

AGENT_CMD="${AGENT_CMD:-__AGENT_CMD__}"
# Flags passed to the agent CLI. Defaults assume `claude`:
#   -p / --print            run once and exit (headless)
#   --permission-mode       skip per-tool prompts so the loop is unattended
AGENT_FLAGS="${AGENT_FLAGS:- -p --permission-mode acceptEdits}"

if [[ ! -f PROMPT.md ]]; then
  echo "PROMPT.md not found in $(pwd). Run /init-ralph first." >&2
  exit 1
fi

iter=0
while true; do
  iter=$((iter + 1))
  echo "── Ralph loop iteration $iter ──"
  cat PROMPT.md | $AGENT_CMD $AGENT_FLAGS
  echo
  echo "── Iteration $iter finished. Press Enter for next loop, Ctrl+C to stop. ──"
  read -r
done
