#!/usr/bin/env python3
"""Check that the marketplace describes itself truthfully. Prints one line per problem.

Everything here has drifted at least once: a plugin table that miscounts, a hook pointing
at a script that was renamed, a skill that tells Claude to invoke one that was deleted.

- every plugin directory is listed in marketplace.json and the other way round, under the
  name its own plugin.json gives;
- every script a hooks.json runs exists;
- every skill and agent has frontmatter whose `name` matches its folder or file, and a
  description; no SKILL.md is over SKILL_LINE_BUDGET lines;
- every `/skill` named in backticks in a plugin's markdown is a skill of this marketplace
  or one listed in tests/external-skills.txt;
- the README plugin table counts the skills, agents and hooks each plugin really has;
- no file names a private term from ~/.claude/private-terms.json (the list kaizen's
  name-guard reads). This repo is public. The check runs wherever that file exists, so on
  your machine and not in CI, and reports the file and a count, never the term.

Usage: check_repo.py [REPO]. Exits 1 when it finds a problem.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

PRIVATE_TERMS = Path.home() / ".claude" / "private-terms.json"
SKILL_LINE_BUDGET = 500
FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
PLUGIN_ROOT_PATH = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"'\s]+)")
# `/name`, `/name args` or `/plugin:name` inside backticks. A path such as `/tmp/x` has a
# second slash right after the first word and does not match.
SKILL_REFERENCE = re.compile(
    r"`/(?:[a-z][a-z0-9-]*:)?([a-z][a-z0-9-]*)(?=[`\s])[^`\n]*`"
)
README_ROW = re.compile(r"^\| \[`([a-z-]+)`\]\([^)]*\) \| ([^|]+) \|", re.MULTILINE)
COUNTED = re.compile(r"(\d+) (skill|agent|hook)s?")


def frontmatter(path):
    match = FRONTMATTER.match(path.read_text(errors="replace"))
    fields = {}
    for line in (match.group(1) if match else "").splitlines():
        key, separator, value = line.partition(":")
        if separator and key.strip().isidentifier():
            fields[key.strip()] = value.strip().strip("'\"")
    return fields


def hook_commands(plugin):
    hooks_file = plugin / "hooks" / "hooks.json"
    if not hooks_file.is_file():
        return []
    events = json.loads(hooks_file.read_text()).get("hooks", {})
    return [
        hook.get("command", "")
        for groups in events.values()
        for group in groups
        for hook in group.get("hooks", [])
    ]


def check_marketplace(repo, plugins):
    manifest = json.loads((repo / ".claude-plugin" / "marketplace.json").read_text())
    listed = {
        entry["name"]: entry.get("source", "") for entry in manifest.get("plugins", [])
    }
    for name in sorted(set(plugins) - set(listed)):
        yield f"{name}/ is a plugin but marketplace.json does not list it"
    for name, source in sorted(listed.items()):
        if name not in plugins:
            yield f"marketplace.json lists {name}, which has no .claude-plugin/plugin.json"
        elif source != f"./{name}":
            yield f"marketplace.json gives {name} the source {source!r}, expected './{name}'"
    for name, plugin in sorted(plugins.items()):
        manifest_name = json.loads(
            (plugin / ".claude-plugin" / "plugin.json").read_text()
        ).get("name")
        if manifest_name != name:
            yield f"{name}/.claude-plugin/plugin.json is named {manifest_name!r}"


def check_hooks(repo, plugins):
    for name, plugin in sorted(plugins.items()):
        for command in hook_commands(plugin):
            for relative in PLUGIN_ROOT_PATH.findall(command):
                if not (plugin / relative).is_file():
                    yield f"{name}/hooks/hooks.json runs {relative}, which does not exist"


def check_components(repo, plugins):
    for plugin in plugins.values():
        for skill in sorted(plugin.glob("skills/*/SKILL.md")):
            yield from check_frontmatter(skill, skill.parent.name, repo)
            lines = len(skill.read_text(errors="replace").splitlines())
            if lines > SKILL_LINE_BUDGET:
                yield f"{skill.relative_to(repo)} is {lines} lines, over the {SKILL_LINE_BUDGET}-line budget"
        for agent in sorted(plugin.glob("agents/*.md")):
            yield from check_frontmatter(agent, agent.stem, repo)


def check_frontmatter(path, expected_name, repo):
    fields = frontmatter(path)
    where = path.relative_to(repo)
    if fields.get("name") != expected_name:
        yield f"{where} has frontmatter name {fields.get('name')!r}, expected {expected_name!r}"
    if not fields.get("description"):
        yield f"{where} has no description, so nothing will ever trigger it"


def check_skill_references(repo, plugins):
    known = {
        skill.parent.name
        for plugin in plugins.values()
        for skill in plugin.glob("skills/*/SKILL.md")
    }
    external_file = repo / "tests" / "external-skills.txt"
    if external_file.is_file():
        known |= {
            line.split("#")[0].strip()
            for line in external_file.read_text().splitlines()
            if line.split("#")[0].strip()
        }
    for plugin in plugins.values():
        for document in sorted(plugin.rglob("*.md")):
            text = document.read_text(errors="replace")
            for referenced in sorted(set(SKILL_REFERENCE.findall(text)) - known):
                yield f"{document.relative_to(repo)} names `/{referenced}`, which is not a skill here"


def check_readme(repo, plugins):
    readme = (repo / "README.md").read_text()
    rows = dict(README_ROW.findall(readme))
    for name, plugin in sorted(plugins.items()):
        if name not in rows:
            yield f"README.md has no table row for {name}"
            continue
        actual = {
            "skill": len(list(plugin.glob("skills/*/SKILL.md"))),
            "agent": len(list(plugin.glob("agents/*.md"))),
            "hook": len(hook_commands(plugin)),
        }
        claimed = {kind: int(count) for count, kind in COUNTED.findall(rows[name])}
        for kind, count in actual.items():
            if claimed.get(kind, 0) != count:
                yield f"README.md says {name} has {claimed.get(kind, 0)} {kind}s; it has {count}"


def check_private_terms(repo, plugins):
    if not PRIVATE_TERMS.is_file():
        return
    terms = [
        term
        for term in json.loads(PRIVATE_TERMS.read_text()).get("terms", [])
        if term.strip()
    ]
    if not terms:
        return
    pattern = re.compile(
        "|".join(
            rf"(?<![A-Za-z0-9]){re.escape(term)}(?![A-Za-z0-9])" for term in terms
        ),
        re.IGNORECASE,
    )
    listed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=repo,
        capture_output=True,
        text=True,
    )
    for name in listed.stdout.splitlines():
        path = repo / name
        if path.is_file():
            count = len(pattern.findall(path.read_text(errors="replace")))
            if count:
                yield f"{name} names a private term {count} time(s); this repo is public"


def main():
    repo = Path(
        sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    )
    plugins = {
        manifest.parent.parent.name: manifest.parent.parent
        for manifest in sorted(repo.glob("*/.claude-plugin/plugin.json"))
    }
    checks = (
        check_marketplace,
        check_hooks,
        check_components,
        check_skill_references,
        check_readme,
        check_private_terms,
    )
    problems = [problem for check in checks for problem in check(repo, plugins)]
    for problem in problems:
        print(f"  {problem}")
    print(f"check_repo: {len(plugins)} plugins, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
