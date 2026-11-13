#!/usr/bin/env python3
"""PreToolUse: keep employer and client names out of everything written outside their roots.

Reads ~/.claude/private-terms.json (never committed; see private-terms.example.json):
  {"terms": ["Acme", "acme-repo"], "allowed_roots": ["~/work/acme"]}
Denies, every time:
- Write / Edit / MultiEdit / NotebookEdit of a file outside the allowed roots whose new text
  names a term;
- Bash run outside the allowed roots that commits, talks to GitHub or the network, or writes a
  file (redirect, tee, sed -i) with a term in the command;
- Artifact publishes and web searches started outside the allowed roots that name a term.
Paths under an allowed root, and Claude's own per-project folders for them, don't count.
No config file -> no-op. Any error -> exit 0 (fails open).
"""

import json
import os
import re
import sys
from pathlib import Path

CONFIG = Path.home() / ".claude" / "private-terms.json"
OUTWARD_BASH = re.compile(
    r"\bgit\s+(commit|tag|notes|push)\b|\bgh\s|\bcurl\s|\bwget\s|\btee\s|\bsed\s+-i|>\s*[^&\s]|<<"
)
EDIT_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}


def load_config():
    config = json.loads(CONFIG.read_text())
    # Both the written and the symlink-resolved form: Claude names its per-project folders after
    # the path as given (/tmp/x), while realpath gives /private/tmp/x.
    roots = set()
    for root in config.get("allowed_roots", []):
        expanded = os.path.abspath(os.path.expanduser(root))
        roots.update({expanded, os.path.realpath(expanded)})
    terms = [term for term in config.get("terms", []) if term.strip()]
    return terms, sorted(roots)


def under_allowed_root(path, roots):
    expanded = os.path.abspath(os.path.expanduser(path or ""))
    candidates = {expanded, os.path.realpath(expanded)}
    encoded = [root.replace("/", "-") for root in roots]
    return any(
        candidate == root
        or candidate.startswith(root + os.sep)
        or any(marker in candidate for marker in encoded)
        for candidate in candidates
        for root in roots
    )


def strip_allowed_paths(text, roots):
    home = str(Path.home())
    for root in roots:
        forms = {
            root,
            root.replace(home, "~", 1),
            root.replace(home, "$HOME", 1),
            root.replace("/", "-"),
        }
        for form in forms:
            text = re.sub(re.escape(form) + r"[^\s'\"]*", " ", text)
    return text


def named_terms(text, terms, roots):
    text = strip_allowed_paths(text, roots)
    return sorted(
        {
            term
            for term in terms
            if re.search(rf"(?<![A-Za-z0-9]){re.escape(term)}(?![A-Za-z0-9])", text, re.I)
        }
    )


def written_text(tool, tool_input):
    if tool == "Write":
        return tool_input.get("content", "")
    if tool == "Edit":
        return tool_input.get("new_string", "")
    if tool == "MultiEdit":
        return "\n".join(edit.get("new_string", "") for edit in tool_input.get("edits", []))
    return tool_input.get("new_source", "")


def offending(tool, tool_input, cwd, terms, roots):
    """Return (terms, where) when the call would leak a term, else None."""
    if tool in EDIT_TOOLS:
        path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
        if under_allowed_root(path, roots):
            return None
        found = named_terms(written_text(tool, tool_input) + "\n" + path, terms, roots)
        return (found, path) if found else None
    if under_allowed_root(cwd, roots):
        return None
    if tool == "Bash":
        command = tool_input.get("command", "")
        if not OUTWARD_BASH.search(command):
            return None
        found = named_terms(command, terms, roots)
        return (found, f"a shell command run in {cwd}") if found else None
    if tool == "Artifact":
        path = tool_input.get("file_path") or ""
        text = Path(path).read_text(errors="replace") if path and Path(path).is_file() else ""
        found = named_terms(text + json.dumps(tool_input), terms, roots)
        return (found, f"an artifact published from {cwd}") if found else None
    if tool in ("WebSearch", "WebFetch"):
        found = named_terms(json.dumps(tool_input), terms, roots)
        return (found, f"a web request from {cwd}") if found else None
    return None


def main():
    if not CONFIG.exists():
        return
    event = json.load(sys.stdin)
    terms, roots = load_config()
    hit = offending(
        event.get("tool_name", ""),
        event.get("tool_input") or {},
        event.get("cwd") or os.getcwd(),
        terms,
        roots,
    )
    if not hit:
        return
    found, where = hit
    reason = (
        f"name-guard: {', '.join(found)} may only appear inside {', '.join(roots)}, and this would put it in "
        f"{where}. Rewrite without the name (say 'my employer', 'the work repo', or describe the thing "
        f"generically). If this location really is work material, the user adds it to allowed_roots in {CONFIG}."
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
