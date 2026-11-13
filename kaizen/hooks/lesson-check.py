#!/usr/bin/env python3
"""Stop hook: if the user corrected Claude this session and no instruction file
was edited since, block once and ask Claude to write the lesson down.

Blocks at most once per session; the marker files that record it are deleted after
FLAG_MAX_AGE_DAYS. Fails open: any error lets Claude stop."""

import json
import pathlib
import re
import sys
import time

CORRECTION = re.compile(
    r"^\s*(no\b|nope|stop\b|don'?t\b|do not\b|never\b|wrong\b|revert\b|undo\b|"
    r"that'?s not\b|not what\b|why did you\b|instead\b)",
    re.IGNORECASE,
)
INSTRUCTION_FILE = re.compile(
    r"(SKILL\.md|CLAUDE\.md|AGENTS\.md|/memory/[^/]+\.md|/agents/[^/]+\.md|/rules/[^/]+\.md|/workflows/[^/]+\.md)$"
)
FLAG_DIR = pathlib.Path.home() / ".claude" / "lesson-check"
FLAG_MAX_AGE_DAYS = 30
# Only these transcript lines can hold a user prompt or a file edit; the rest (tool results,
# attachments, snapshots) are most of a long transcript and are skipped without parsing.
RELEVANT_LINE = re.compile(r'"type"\s*:\s*"(user|assistant)"')


def prune_flags():
    cutoff = time.time() - FLAG_MAX_AGE_DAYS * 86400
    for old in FLAG_DIR.iterdir():
        if old.is_file() and old.stat().st_mtime < cutoff:
            old.unlink(missing_ok=True)


def user_text(msg):
    content = msg.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = [c.get("text", "") for c in content if c.get("type") == "text"]
        return "\n".join(texts) if texts and len(texts) == len(content) else ""
    return ""


def main():
    event = json.load(sys.stdin)
    if event.get("stop_hook_active"):
        return
    sid = event.get("session_id", "")
    flag = FLAG_DIR / sid
    transcript = event.get("transcript_path")
    if not sid or flag.exists() or not transcript or not pathlib.Path(transcript).exists():
        return

    last_correction, lesson_written = None, False
    for line in open(transcript, encoding="utf-8", errors="replace"):
        if not RELEVANT_LINE.search(line):
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg = rec.get("message") or {}
        if rec.get("type") == "user" and not rec.get("isMeta"):
            text = user_text(msg).strip()
            if text and not text.startswith("<") and CORRECTION.match(text):
                last_correction, lesson_written = text, False
        elif rec.get("type") == "assistant" and last_correction:
            for block in msg.get("content") or []:
                if block.get("type") == "tool_use":
                    path = str((block.get("input") or {}).get("file_path", ""))
                    if INSTRUCTION_FILE.search(path):
                        lesson_written = True

    if not last_correction or lesson_written:
        return
    FLAG_DIR.mkdir(parents=True, exist_ok=True)
    prune_flags()
    flag.touch()
    quote = " ".join(last_correction.split())[:100]
    print(
        json.dumps(
            {
                "decision": "block",
                "reason": (
                    f'The user corrected you this session ("{quote}") and no skill, CLAUDE.md, '
                    "agent or memory file was updated since. Would the next run make the same mistake? "
                    "If yes, write the lesson now: repo-specific -> the repo's .claude/skills, agents or CLAUDE.md; "
                    "cross-repo -> the user's own config repo behind ~/.claude (skills, agents, CLAUDE.md); "
                    "neither fits -> memory. "
                    "Say in one line what you changed. If it was a one-off, say so in one line and stop."
                ),
            }
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001 - a broken check must never keep Claude from stopping
        pass
    sys.exit(0)
