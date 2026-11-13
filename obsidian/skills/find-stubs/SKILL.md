---
name: find-stubs
description: Scan the vault-of-markus Obsidian vault for short, unfinished, or stub notes — anything whose body is suspiciously thin. Use when the user says "find stubs", "/find-stubs", "what notes are unfinished", or wants a vault-wide audit of note completeness. Reports findings only — does NOT edit notes.
---

# find-stubs

Audit the vault for notes that look like stubs — short bodies, placeholder content, single-heading shells. Reports a grouped list with suggestions. Companion to the `vault-stub-check.sh` hook, which fires the same check at save time for one file.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. Skip:

- `Templates/` and `.obsidian/`
- Meta-files: `CLAUDE.md`, `README.md`, `AGENTS.md`, `Home.md`, `Index.md`
- Daily notes (`YYYY-MM-DD.md`) — they're expected to be short on creation; audit separately if asked

## Detection

Cheap heuristics, in priority order. A note that hits any one of these is flagged.

### 1. Short body (default threshold: 40 words)

Count words in the body — meaning: file minus frontmatter, minus the abstract/summary callout, minus footnote definitions. The `vault-stub-check.sh` hook uses the same logic; reuse its awk shape:

```sh
awk '
  BEGIN { in_fm = 0; in_callout = 0 }
  NR == 1 && /^---$/ { in_fm = 1; next }
  in_fm && /^---$/ { in_fm = 0; next }
  in_fm { next }
  !in_callout && /^>\[!(abstract|summary)\]/ { in_callout = 1; next }
  in_callout && /^>/ { next }
  in_callout { in_callout = 0 }
  /^\[\^[^]]+\]:/ { next }
  { print }
' "$file" | wc -w
```

Threshold is tunable — let the user override (`/find-stubs threshold=80`). Default 40.

### 2. Placeholder content

Body contains markers suggesting work-in-progress:

- `TODO`, `TBD`, `FIXME`, `XXX`, `???`
- Standalone `...` lines
- `<placeholder>` / `<replace>` style angle-bracket slots
- A heading immediately followed by another heading (empty section)

Grep is enough:

```sh
grep -liE '(\bTODO\b|\bTBD\b|\bFIXME\b|\bXXX\b)' /Users/markusjohansen/vault-of-markus/*.md
```

### 3. Skeleton-only

The note has the conventional shell — frontmatter + abstract + one `#` heading — and almost nothing else. Detect by:

- Total non-empty body lines (after stripping FM + callout) ≤ 3, OR
- Body is entirely heading lines

### 4. Missing required structure

(These overlap with `/tidy-note` but surface them here too so the audit is one-stop.)

- No frontmatter
- No `categories`
- No `>[!abstract]` / `>[!summary]` callout

Don't double-warn — if a note is flagged for short body, mention these as a secondary detail rather than separate flags.

## Workflow

1. List the working set: `ls /Users/markusjohansen/vault-of-markus/*.md`, then strip the exclusions above.
2. For each note, compute: word count, placeholder hits, skeleton-only check.
3. Group findings by suspected reason. Sort within each group by word count ascending (shortest first — most likely to be a stub).
4. Print the grouped report.

For vaults with hundreds of notes, this is still cheap (one `awk` + one `grep` per file). No need to delegate to `vault-librarian`.

## Output format

```
## Stubs audit — N notes scanned, M flagged

### Short body (under 40 words)
- [[Note Title]] — 12 words. Body is one paragraph; consider expanding or merging.
- [[Another Note]] — 24 words. Has only an abstract; no real content.

### Placeholder / WIP markers
- [[Note Title]] — contains `TODO: explain the approach` at line 18.
- [[Other Note]] — heading "## Next steps" followed by no content.

### Skeleton-only
- [[Note Title]] — frontmatter + abstract + single heading; body is empty.

### Missing required structure (also short)
- [[Note Title]] — no frontmatter; 18 words total.

## Suggestion
- Top candidates to address first: <list 3–5 by name>.
- Consider merging short notes that overlap with a richer note (run /weave-notes to spot duplicates).
- For genuinely-stub notes that should grow: leave them and revisit; for ones that won't, delete or fold into another note.
```

## Don't

- Don't edit notes. Reporting only.
- Don't auto-merge or auto-delete. The user decides.
- Don't double-flag the same note in multiple sections — pick the most relevant category and mention overlaps as secondary detail.
- Don't include daily notes unless the user explicitly asks.
- Don't slow down on the abstract-callout body — the abstract often contains the only prose in a stub; that's *why* it's a stub.
