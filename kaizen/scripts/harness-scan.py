#!/usr/bin/env python3
"""Weekly harness scan for weekly.sh: instruction files over budget,
and prompts repeated per project (candidates for a local skill). Prints text."""

import collections
import json
import os
import pathlib
import re
import time

HOME = pathlib.Path.home()
# The config repo behind ~/.claude/CLAUDE.md when that is a symlink (resolving it reads nothing,
# so it works under launchd too), else ~/.claude itself.
CFG = pathlib.Path(
    os.environ.get("CLAUDE_CONFIG_REPO", os.path.realpath(HOME / ".claude/CLAUDE.md"))
).parent
DAYS = 30
BUDGET = {
    "CLAUDE.md": 200,
    "AGENTS.md": 200,
    "user-CLAUDE.md": 200,
    "SKILL.md": 500,
    "MEMORY.md": 200,
}


def lines(p):
    try:
        return sum(1 for _ in p.open(errors="replace"))
    except OSError:
        return 0


def recent_projects():
    cutoff = (time.time() - DAYS * 86400) * 1000
    prompts = collections.defaultdict(list)
    for raw in (HOME / ".claude/history.jsonl").open(errors="replace"):
        try:
            r = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if (
            r.get("timestamp", 0) >= cutoff
            and r.get("project")
            and "/.supacode/repos/" not in r["project"]
        ):
            prompts[r["project"]].append(r.get("display", ""))
    return prompts


def instruction_files(projects):
    files = [CFG / "user-CLAUDE.md", *sorted(CFG.glob("skills/*/SKILL.md"))]
    for proj in projects:
        p = pathlib.Path(proj)
        files += [p / "CLAUDE.md", p / "AGENTS.md", *sorted(p.glob(".claude/skills/*/SKILL.md"))]
    files += sorted((HOME / ".claude/projects").glob("*/memory/*.md"))
    out = []
    for f in dict.fromkeys(files):
        if not f.is_file():
            continue
        n = lines(f)
        budget = BUDGET.get(f.name, 40 if "/memory/" in str(f) else None)
        out.append((n, budget, f))
    return out


def repeated(prompts):
    found = []
    for proj, texts in prompts.items():
        keys = collections.Counter()
        for t in texts:
            t = t.strip().lower()
            if not t or t.startswith(("/", "!")) or len(t) < 15:
                continue
            keys[" ".join(re.findall(r"[a-zæøå0-9]+", t)[:5])] += 1
        for k, c in keys.most_common():
            if c >= 3:
                has_local = any(pathlib.Path(proj).glob(".claude/skills/*/SKILL.md"))
                found.append((c, proj, k, has_local))
    return sorted(found, reverse=True)[:10]


def main():
    prompts = recent_projects()
    files = instruction_files(prompts)
    print(f"## Instruction files over budget (lines / budget)")
    over = [(n, b, f) for n, b, f in files if b and n > b]
    for n, b, f in sorted(over, reverse=True):
        print(f"- {n}/{b}  {f}")
    if not over:
        print("- none")
    print("\n## Largest instruction files (always-loaded cost)")
    for n, b, f in sorted(files, reverse=True)[:5]:
        print(f"- {n} lines  {f}")
    print(
        f"\n## Prompts typed 3+ times in one project (last {DAYS} days) -> local skill candidates"
    )
    rep = repeated(prompts)
    for c, proj, k, has_local in rep:
        print(f'- {c}x  {proj}  "{k} ..."  (repo has local skills: {"yes" if has_local else "no"})')
    if not rep:
        print("- none")


if __name__ == "__main__":
    main()
