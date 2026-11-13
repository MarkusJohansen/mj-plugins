#!/usr/bin/env python3
"""Replace every private term from ~/.claude/private-terms.json with <work>, in place.

Usage: redact.py FILE [FILE ...]. Matches case-insensitively, also inside paths and
identifiers (a mined path like ~/work/acme-repo becomes ~/work/<work>-repo). No config -> no-op.
"""

import json
import re
import sys
from pathlib import Path

CONFIG = Path.home() / ".claude" / "private-terms.json"
REPLACEMENT = "<work>"


def main():
    if not CONFIG.exists():
        return
    terms = sorted(
        (term for term in json.loads(CONFIG.read_text()).get("terms", []) if term.strip()),
        key=len,
        reverse=True,
    )
    if not terms:
        return
    pattern = re.compile("|".join(re.escape(term) for term in terms), re.I)
    for name in sys.argv[1:]:
        path = Path(name)
        if path.is_file():
            path.write_text(pattern.sub(REPLACEMENT, path.read_text(errors="replace")))


if __name__ == "__main__":
    main()
