#!/usr/bin/env python3
"""PreToolUse (Bash): block a recursive rm whose target is the root, the home directory,
a top-level directory of either, another user's home, or anything reached through `..`.

Every target of every rm in the command is checked, quoted or not, after `cd`, `~`, `$HOME`
and other environment variables are resolved. A variable the environment does not define
counts as empty, so `rm -rf "$BUILD/"` is judged as `rm -rf /`; `${BUILD:?}` is the safe
spelling and passes. Deeper paths, relative paths under the working directory and temp
directories pass.

A speed bump, not a control: `find -delete`, `xargs rm` and a command built at run time
get past it. Exit 0 = allow, exit 2 = block (stderr goes to Claude). Fails open.
"""

import json
import os
import sys

from shell_commands import resolve, simple_commands, variables_set_in

MATCH_ALL_GLOBS = {"*", ".*", ".[!.]*", "{*,.*}", "{.*,*}"}


def is_recursive(flags):
    return any(
        flag in ("--recursive", "--no-preserve-root")
        or (not flag.startswith("--") and set(flag[1:]) & {"r", "R"})
        for flag in flags
    )


def rm_targets(argv):
    """The targets of a recursive rm, or nothing for any other command."""
    if os.path.basename(argv[0]) != "rm":
        return []
    flags, targets, flags_ended = [], [], False
    for word in argv[1:]:
        if word == "--" and not flags_ended:
            flags_ended = True
        elif word.startswith("-") and len(word) > 1 and not flags_ended:
            flags.append(word)
        else:
            targets.append(word)
    return targets if is_recursive(flags) else []


def danger(target, directory, set_in_command):
    """Why deleting `target` from `directory` is dangerous, or None."""
    if ".." in target.split("/"):
        return "it climbs out of the working directory through '..'"
    path = resolve(target, directory, set_in_command)
    if path is None:
        return None
    contents = ""
    if os.path.basename(path) in MATCH_ALL_GLOBS:
        path, contents = os.path.dirname(path), "everything in "
    # Judged as written and with symlinks resolved: on macOS /tmp and /etc live under /private.
    for candidate in dict.fromkeys([path, os.path.realpath(path)]):
        reason = protected(candidate)
        if reason:
            resolved = f" (resolves to {candidate})" if candidate != target else ""
            return f"it is {contents}{reason}{resolved}"
    return None


def protected(path):
    home = os.path.realpath(os.path.expanduser("~"))
    parent = os.path.dirname(path)
    if path == "/":
        return "the filesystem root"
    if path == home:
        return "your home directory"
    if home.startswith(path + "/"):
        return "a directory that contains your home directory"
    if parent == "/":
        return "a top-level system directory"
    if parent == home:
        return "a top-level directory of your home"
    if parent == os.path.dirname(home):
        return "another user's home directory"
    return None


def main():
    event = json.load(sys.stdin)
    command = (event.get("tool_input") or {}).get("command") or ""
    if "rm" not in command:
        return 0
    set_in_command = variables_set_in(command)
    for argv, directory in simple_commands(command, event.get("cwd") or os.getcwd()):
        for target in rm_targets(argv):
            reason = danger(target, directory, set_in_command)
            if reason:
                print(
                    f'Blocked: recursive rm of "{target}": {reason}.\n'
                    "If an unset variable is the risk, write ${VAR:?}. "
                    "If you really mean this, ask the user to run it outside Claude.",
                    file=sys.stderr,
                )
                return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # noqa: BLE001 - a guard that crashes must not block every Bash call
        sys.exit(0)
