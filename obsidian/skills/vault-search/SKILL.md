---
name: vault-search
description: Search across the vault-of-markus Obsidian vault for notes matching a query — content, titles, frontmatter categories, or fuzzy/semantic intent. Trigger when the user says "find notes about X", "search my vault", "/vault-search", or asks where something is in their notes. Delegates broad/fuzzy searches to the vault-librarian agent.
---

# vault-search

Locate notes in `/Users/markusjohansen/vault-of-markus/` that match a query. Pick the right tool based on how specific the query is.

## Decision tree

| Query shape | Use |
| --- | --- |
| Exact phrase or keyword (`"OAuth callback"`) | `grep` here in the main session |
| A single category (`Books`, `Daily`, `Project`) | `grep` on frontmatter |
| Title fragment | `ls` + `grep` |
| Broad/fuzzy ("notes about my approach to fishing", "everything related to my day job") | delegate to the `vault-librarian` agent |
| "What's connected to X?" | delegate to `vault-librarian` or use [[link-notes]] |

## Recipes

**Content search (case-insensitive, whole-word):**

```sh
grep -liwF "<term>" /Users/markusjohansen/vault-of-markus/*.md
```

Add `-n` and drop `-l` to see line numbers / matched lines.

**Category search:**

```sh
awk '/^---$/{f=!f; next} f && /^  - <Category>$/{print FILENAME}' \
  /Users/markusjohansen/vault-of-markus/*.md
```

**Title match:**

```sh
ls /Users/markusjohansen/vault-of-markus/*.md | grep -i "<fragment>"
```

**Recent notes:**

```sh
ls -t /Users/markusjohansen/vault-of-markus/*.md | head -10
```

## Delegation

When delegating to `vault-librarian`, give it:

- The exact query in the user's words.
- The vault path (`/Users/markusjohansen/vault-of-markus/`).
- Whether you want a short list of paths or a synthesised summary.
- A cap (e.g. "top 10 matches").

The agent reads many files without polluting this context — use it whenever a `grep` would need post-filtering across more than ~10 hits.

## Output

Return as a list:

```
- [[Note Title]] — <one-line relevance hint>
```

Keep it short. If there are >10 hits, show top 10 and ask whether to expand.

## Don't

- Don't open and read every match yourself when the result count is large — delegate.
- Don't recursively search outside the vault directory.
- Don't return raw file paths — render as `[[wikilinks]]` so the user can click through in their terminal/Obsidian.
