#!/usr/bin/env python3
"""PreToolUse (Bash): before a `git commit`, scan what it would commit for secrets.

The diff is read from the repository the commit runs in, following `cd` and `git -C`, so a
commit made from another working directory is checked in the right place. The hook runs
before the command does, so what is staged now is not all a commit can hold: `git commit -a`
is checked against the whole working tree, and `git add x && git commit` against the files
that add names, new ones included. Only added lines are read: removing a secret cannot leak
it.

Patterns are high precision: each is nearly always a real credential. A line carrying
`pragma: allowlist secret` is skipped. The report names the file and the kind of secret,
never the text, so the secret does not land in the transcript.

A speed bump, not a control: encoded or split secrets and home-made token formats get past
it. Exit 0 = allow, exit 2 = block (stderr goes to Claude). Fails open.
"""

import json
import os
import re
import subprocess
import sys

from shell_commands import resolve, simple_commands

ALLOW_MARKER = "pragma: allowlist secret"
MAX_REPORTED = 5
MAX_UNTRACKED_FILES = 200
MAX_UNTRACKED_BYTES = 1_000_000
GIT_TIMEOUT_SECONDS = 10
GIT_OPTIONS_WITH_VALUE = {
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--exec-path",
}
SECRET_PATTERNS = [
    ("AWS access key id", r"\b(AKIA|ASIA)[0-9A-Z]{16}\b"),
    (
        "AWS secret access key",
        r"aws_secret_access_key\s*[=:]\s*[\"']?[A-Za-z0-9/+=]{40}",
    ),
    ("GitHub token", r"\bgh[pousr]_[A-Za-z0-9]{36,}"),
    ("GitHub fine-grained token", r"\bgithub_pat_[A-Za-z0-9_]{82,}"),
    ("GitLab token", r"\bglpat-[A-Za-z0-9_-]{20,}"),
    ("private key", r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    ("Slack token", r"\bxox[abporsu]-[A-Za-z0-9-]{10,}"),
    ("Anthropic API key", r"\bsk-ant-[A-Za-z0-9_-]{20,}"),
    (
        "OpenAI API key",
        r"\bsk-(proj|svcacct|admin)-[A-Za-z0-9_-]{20,}|\bsk-[A-Za-z0-9]{32,}",
    ),
    ("Google API key", r"\bAIza[0-9A-Za-z_-]{35}\b"),
    ("Stripe live key", r"\b[sr]k_live_[0-9A-Za-z]{24,}"),
    ("npm token", r"\bnpm_[A-Za-z0-9]{36}\b"),
    ("Hugging Face token", r"\bhf_[A-Za-z0-9]{34,}"),
]
COMPILED_PATTERNS = [(kind, re.compile(pattern)) for kind, pattern in SECRET_PATTERNS]


def commits(command, directory):
    """Yield (repository directory, commits unstaged changes, paths added first) per commit.

    The hook runs before the command, so in `git add x && git commit` nothing is staged yet.
    The paths of every `git add` that comes before a commit are handed along with it: an
    empty list means "everything" (`git add -A`, `git add .`), None means no add at all.
    """
    added = None
    for argv, where in simple_commands(command, directory):
        if os.path.basename(argv[0]) != "git":
            continue
        index = 1
        while index < len(argv) and argv[index].startswith("-"):
            if argv[index] == "-C" and index + 1 < len(argv):
                where = resolve(argv[index + 1], where) or where
                index += 2
            elif argv[index] in GIT_OPTIONS_WITH_VALUE:
                index += 2
            else:
                index += 1
        subcommand, arguments = (argv[index], argv[index + 1 :]) if index < len(argv) else ("", [])
        if subcommand == "add":
            paths = [resolve(word, where) for word in arguments if not word.startswith("-")]
            everything = not paths or None in paths or added == []
            added = [] if everything else [*(added or []), *paths]
        elif subcommand == "commit":
            includes_unstaged = any(
                flag == "--all" or (flag.startswith("-") and flag[1:2] != "-" and "a" in flag)
                for flag in arguments
            )
            yield where, includes_unstaged, added


def git_output(directory, *arguments):
    result = subprocess.run(
        ["git", *arguments],
        cwd=directory,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=GIT_TIMEOUT_SECONDS,
    )
    return result.stdout if result.returncode == 0 else ""


def git_diff(directory, *arguments):
    return git_output(directory, "diff", "--unified=0", "--no-color", "--no-ext-diff", *arguments)


def untracked_as_diff(directory, paths):
    """New files a `git add` would pick up, written as added lines so they scan like a diff."""
    listing = git_output(directory, "ls-files", "--others", "--exclude-standard", "-z", "--", *paths)
    lines = []
    for name in [name for name in listing.split("\0") if name][:MAX_UNTRACKED_FILES]:
        path = os.path.join(directory, name)
        if not os.path.isfile(path) or os.path.getsize(path) > MAX_UNTRACKED_BYTES:
            continue
        with open(path, errors="replace") as file:
            lines.append(f"+++ b/{name}")
            lines.extend("+" + line.rstrip("\n") for line in file)
    return "\n".join(lines)


def pending_diff(directory, includes_unstaged, added):
    """Everything the commit could contain: what is staged, plus what -a or a git add brings."""
    parts = [git_diff(directory, "--cached")]
    if includes_unstaged:
        parts.append(git_diff(directory, "HEAD"))
    if added is not None:
        parts.append(git_diff(directory, "HEAD", "--", *added))
        parts.append(untracked_as_diff(directory, added))
    return "\n".join(parts)


def secrets_in(diff):
    """(file, kind) for each added line that holds a secret, in order, without duplicates."""
    found, current_file = [], "?"
    for line in diff.splitlines():
        if line.startswith("+++ "):
            current_file = line[6:] if line.startswith("+++ b/") else line[4:]
        elif line.startswith("+") and ALLOW_MARKER not in line:
            for kind, pattern in COMPILED_PATTERNS:
                if pattern.search(line) and (current_file, kind) not in found:
                    found.append((current_file, kind))
                    break
    return found


def main():
    event = json.load(sys.stdin)
    tool_input = event.get("tool_input") or {}
    command = tool_input.get("command") or ""
    if "commit" not in command:
        return 0
    start = tool_input.get("cwd") or event.get("cwd") or os.getcwd()
    for directory, includes_unstaged, added in commits(command, start):
        found = secrets_in(pending_diff(directory, includes_unstaged, added))
        if not found:
            continue
        listed = "\n".join(f"  {path}: {kind}" for path, kind in found[:MAX_REPORTED])
        more = (
            f"\n  ... and {len(found) - MAX_REPORTED} more"
            if len(found) > MAX_REPORTED
            else ""
        )
        print(
            f"Blocked: this commit in {directory} would add what looks like a secret.\n"
            f"{listed}{more}\n"
            "Remove it and load the value from the environment. If it is a test fixture, end "
            f"the line with '{ALLOW_MARKER}'. Tell the user: a real key that touched disk "
            "should be rotated.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # noqa: BLE001 - a guard that crashes must not block every Bash call
        sys.exit(0)
