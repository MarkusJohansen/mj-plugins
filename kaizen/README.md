# kaizen

A loop that makes Claude Code better at working with you, week by week, and a guard that
keeps private names where they belong.

`verify` covers Python (ruff, related pytest files), frontend (prettier, vitest) and shell
(`bash -n`, shellcheck when installed). A `tests/run.sh` next to or above a changed file is
that file's suite and runs once. `verify <dir>` checks everything under a directory, changed
or not.

## What it does

| Piece                          | Kind      | Job                                                       |
|--------------------------------|-----------|-----------------------------------------------------------|
| `introspect`                   | skill     | Evidence-backed overview of how you use Claude Code       |
| `scripts/weekly.sh`            | launchd   | Weekly report, then up to two fixes on a review branch    |
| `hooks/shell-habits.py`        | PreToolUse| Nudges hand-built shell recipes onto the helpers below    |
| `hooks/name-guard.py`          | PreToolUse| Blocks private names in anything written outside a root   |
| `hooks/lesson-check.py`        | Stop      | After a correction, asks Claude to write the lesson down  |
| `hooks/config-size-check.sh`   | PostToolUse | Flags instruction files over their line budget          |
| `scripts/verify`               | helper    | Lint, format and related tests for the packages you touched |
| `scripts/branch-brief`         | helper    | Branch, PR, failing checks and stack position in one call |

## The weekly loop

The LaunchAgent starts `weekly.sh` at every login and every morning at 08:30, and the script
leaves at once unless the newest report is a week old. A single weekly slot would not do:
launchd drops a run that was due while the Mac was off. `KAIZEN_FORCE=1` runs it regardless.

1. `shell-patterns.py`, `harness-scan.py` and the introspect miner read the last 7 days of
   transcripts. `redact.py` replaces every private term with `<work>` before Claude sees it.
2. Claude writes a report (default `~/second-brain/_system/introspect/<date>.md`, override with
   `KAIZEN_REPORT_DIR`). It includes tokens per model, main sessions apart from subagents, which
   the miner sums from each reply's usage record (`usage.tokens` in its JSON).
3. Claude picks at most two changes backed by numbers, for example a new helper for a shell
   recipe repeated across sessions, implements them in its own clone of this marketplace on a
   `kaizen/<date>` branch, runs the hook tests before and after, bumps the plugin version
   and commits. It never pushes. The report ends with the `git fetch` / `git merge` command.

The `shell-habits` hit log (`~/.claude/shell-habits/hits.jsonl`) closes the loop: a nudge that
is mostly re-issued means its helper falls short, and the next run sees that.

## Setup

```sh
claude plugin install kaizen@mj-plugins
bash ~/.claude/plugins/marketplaces/mj-plugins/kaizen/scripts/setup.sh
```

`setup.sh` links `verify` and `branch-brief` into `~/.local/bin`, clones the marketplace to
`~/.local/share/kaizen/mj-plugins` and loads the LaunchAgent (at login and daily 08:30, so a
report that is due is written on the spot). Everything runs
from paths outside `~/Documents`, which launchd jobs can't read. The clone sits outside
`~/.claude` because Claude Code protects that folder from edits in unattended runs.

## Private names

Copy `private-terms.example.json` to `~/.claude/private-terms.json` and list the names (employer,
clients, internal repos) and the roots they may appear under. Outside those roots, `name-guard`
denies file writes, commits, GitHub and network commands, artifact publishes and web searches
that name one. The file stays on your machine; without it the guard does nothing.

## Tests

```sh
bash kaizen/hooks/tests/run.sh
```
