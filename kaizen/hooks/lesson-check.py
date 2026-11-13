#!/usr/bin/env python3
"""Stop hook: if the user corrected Claude this session and no instruction file
was edited since, block once and ask Claude to write the lesson down."""

import json
import pathlib
import re
import sys

CORRECTION = re.compile(
    r"^\s*(no\b|nope|stop\b|don'?t\b|do not\b|never\b|wrong\b|revert\b|undo\b|"
    r"that'?s not\b|not what\b|why did you\b|instead\b)",
    re.IGNORECASE,
)
INSTRUCTION_FILE = re.compile(
    r"(SKILL\.md|CLAUDE\.md|AGENTS\.md|/memory/[^/]+\.md|/agents/[^/]+\.md|/rules/[^/]+\.md|/workflows/[^/]+\.md)$"
)
FLAG_DIR = pathlib.Path.home() / ".claude" / "lesson-check"


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
    main()
