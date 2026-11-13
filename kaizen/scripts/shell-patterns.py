#!/usr/bin/env python3
"""Mine Claude Code transcripts for repeated shell recipes worth turning into a helper.

Usage: shell-patterns.py [--days N] [--out FILE]

Reads every Bash tool call and its result from ~/.claude/projects/**/*.jsonl modified in the
last N days, normalises each command into a "shape" (paths, numbers, quoted text and heredoc
bodies removed) and ranks shapes by the output they cost and how many sessions repeat them.
Also reports how often the shell-habits nudges fired. Output is JSON for the weekly
self-improvement run; sizes are characters (about 4 per token).
"""

import argparse
import collections
import json
import re
import time
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"
HABIT_HITS = Path.home() / ".claude" / "shell-habits" / "hits.jsonl"
MIN_SESSIONS = 3
TOP_SHAPES = 25
SAMPLES_PER_SHAPE = 3


def bash_calls(days):
    cutoff = time.time() - days * 86400
    for transcript in PROJECTS.rglob("*.jsonl"):
        if transcript.stat().st_mtime < cutoff:
            continue
        pending = {}
        for line in open(transcript, errors="ignore"):
            try:
                content = json.loads(line).get("message", {}).get("content")
            except (json.JSONDecodeError, AttributeError):
                continue
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use" and block.get("name") == "Bash":
                    pending[block["id"]] = (block.get("input") or {}).get("command", "")
                elif block.get("type") == "tool_result" and block.get("tool_use_id") in pending:
                    output = block.get("content") or ""
                    if isinstance(output, list):
                        output = " ".join(
                            part.get("text", "") for part in output if isinstance(part, dict)
                        )
                    yield (
                        transcript.stem,
                        pending.pop(block["tool_use_id"]),
                        len(output),
                        bool(block.get("is_error")),
                    )


def shape(command):
    text = re.sub(r"<<-?\s*'?(\w+)'?\n.*?\n\1\b", "<<HEREDOC", command, flags=re.S)
    text = re.sub(r"^\s*cd\s+\S+\s*(&&|;)\s*", "", text)
    text = re.sub(r"\b[A-Z_]+=\S+\s*(&&|;)?\s*", "", text)
    text = re.sub(r"'[^']*'|\"[^\"]*\"", "Q", text)
    text = re.sub(
        r"(~|\.{0,2})?/[\w./@+-]+|\b[\w-]+\.(py|md|ts|svelte|json|toml|ya?ml|txt|sh)\b", "P", text
    )
    text = re.sub(r"\b[0-9a-f]{7,40}\b|\b\d+\b", "N", text)
    parts = [" ".join(part.split()[:3]) for part in re.split(r"&&|\|\||;|\|", text) if part.strip()]
    return " ; ".join(parts[:6])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--out", type=Path)
    options = parser.parse_args()

    shapes = collections.defaultdict(
        lambda: {
            "calls": 0,
            "output_chars": 0,
            "input_chars": 0,
            "errors": 0,
            "sessions": set(),
            "samples": [],
        }
    )
    total_calls = total_output = 0
    for session, command, output_chars, is_error in bash_calls(options.days):
        total_calls += 1
        total_output += output_chars
        entry = shapes[shape(command)]
        entry["calls"] += 1
        entry["output_chars"] += output_chars
        entry["input_chars"] += len(command)
        entry["errors"] += is_error
        entry["sessions"].add(session)
        if len(entry["samples"]) < SAMPLES_PER_SHAPE:
            entry["samples"].append(command[:300])

    repeated = [
        {
            "shape": key,
            **{field: value for field, value in entry.items() if field != "sessions"},
            "sessions": len(entry["sessions"]),
        }
        for key, entry in shapes.items()
        if len(entry["sessions"]) >= MIN_SESSIONS
    ]
    repeated.sort(key=lambda entry: -(entry["output_chars"] + entry["input_chars"]))

    habit_hits = collections.Counter()
    if HABIT_HITS.exists():
        cutoff = time.time() - options.days * 86400
        for line in open(HABIT_HITS, errors="replace"):
            try:
                hit = json.loads(line)
            except json.JSONDecodeError:  # a half-written line must not sink the weekly run
                continue
            if hit.get("ts", 0) >= cutoff and "rule" in hit:
                outcome = hit.get("outcome") or ("denied" if hit.get("denied") else "later")
                habit_hits[f"{hit['rule']}:{outcome}"] += 1

    report = {
        "days": options.days,
        "bash_calls": total_calls,
        "bash_output_chars": total_output,
        "habit_hits": dict(habit_hits),
        "repeated_shapes": repeated[:TOP_SHAPES],
    }
    text = json.dumps(report, indent=1)
    if options.out:
        options.out.write_text(text)
    else:
        print(text)


if __name__ == "__main__":
    main()
