#!/usr/bin/env python3
"""PreToolUse (Bash): steer hand-built shell recipes onto the helpers that replace them.

Each rule denies the first matching call per session with a pointer to the cheaper route;
re-issuing the same call, or any later match, goes through. Every hit is appended to
~/.claude/shell-habits/hits.jsonl, which the weekly self-improvement run reads to see which
nudges fire and which recipes still need a helper. Fails open: any error -> exit 0.
"""

import json
import re
import sys
import time
from pathlib import Path

STATE = Path.home() / ".claude" / "shell-habits"

RULES = {
    "instruction-reread": (
        re.compile(
            r"(^|[;&|]\s*)(cat|head|tail|less|sed -n \S+)\s+(\S*/)?(CLAUDE|AGENTS)(\.local)?\.md\b"
        ),
        "CLAUDE.md / AGENTS.md files on the path from the working directory up to the repo root, "
        "and ~/.claude/CLAUDE.md, are already in your context. Re-issue only if this file is "
        "outside that path (e.g. a sibling package) and so not loaded.",
    ),
    "python-edit": (
        re.compile(
            r"(read_text\(\)|\.read\(\)).*\.replace\(.*(write_text\(|open\([^)]*['\"]w)", re.S
        ),
        "This is a hand-rolled string replacement. Use the Edit tool: it checks the old text is "
        "unique, keeps file state current, and the format-on-edit hook formats the result. "
        "Re-issue if this rewrite really spans many files or needs a regex.",
    ),
    "hand-verify": (
        re.compile(
            # Command position only (line start, after ; & | ( or a path /, or after `uv run`),
            # so a commit message or `grep pytest` doesn't trip it.
            r"(^|[;&|(]\s*|/|\buv run\s+)(pytest|ruff (format|check)|basedpyright|vitest|pnpm (check|test))\b",
            re.M,
        ),
        "Run `verify` instead: it finds the packages your diff touches and runs ruff, related "
        "tests (pytest/vitest) and, with --types, basedpyright/pnpm check, printing only "
        "failures. Flags: --base origin/main, --all, --types, --no-tests, or explicit paths. "
        "Re-issue if you need a specific test selection verify can't express.",
    ),
    "branch-overview": (
        re.compile(r"(main|master)\.\.\.?HEAD|gh pr (view|checks)\b"),
        "Run `branch-brief` instead: one call gives base, commits, capped diffstat, uncommitted "
        "files, PR state, failing checks only and the gh-stack position. Re-issue if you need "
        "a field it doesn't print.",
    ),
}


def main():
    event = json.load(sys.stdin)
    command = (event.get("tool_input") or {}).get("command") or ""
    if command.lstrip().startswith(("verify", "branch-brief")):
        return
    session = event.get("session_id", "none")
    STATE.mkdir(parents=True, exist_ok=True)
    for rule, (pattern, advice) in RULES.items():
        if not pattern.search(command):
            continue
        # The flag holds the denied command, so a hit can be told apart as the nudge itself,
        # the same command re-issued (the helper didn't fit) or a later, different call.
        flag = STATE / f"{session}.{rule}"
        denied = not flag.exists()
        if denied:
            flag.write_text(command)
            outcome = "denied"
        else:
            outcome = "reissued" if flag.read_text() == command else "later"
        with open(STATE / "hits.jsonl", "a") as log:
            log.write(
                json.dumps(
                    {
                        "ts": int(time.time()),
                        "rule": rule,
                        "denied": denied,
                        "outcome": outcome,
                        "cwd": event.get("cwd"),
                        "command": command[:300],
                    }
                )
                + "\n"
            )
        if denied:
            print(
                json.dumps(
                    {
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "deny",
                            "permissionDecisionReason": advice,
                        }
                    }
                )
            )
        return


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
