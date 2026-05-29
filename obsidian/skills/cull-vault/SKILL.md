---
name: cull-vault
description: Recommend notes in the vault-of-markus Obsidian vault that may not be worth keeping — orphans, abandoned stubs, duplicates, never-revisited captures. Use when the user says "clean up my vault", "/cull-vault", "find notes to delete", or wants a pruning pass. Reports candidates with reasons; the user decides — never deletes anything.
---

# cull-vault

Identify notes that have likely lost their value: orphans with no graph connections, stubs that haven't grown, duplicates of richer notes, captures that were never returned to. Output is a ranked candidate list with a reason per note. **No deletions.** The user decides note-by-note.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. Skip:

- `Templates/` and `.obsidian/`
- Meta-files: `CLAUDE.md`, `README.md`, `AGENTS.md`, `Home.md`, `Index.md`
- Daily notes (`YYYY-MM-DD.md`) — they're append-only logs; don't propose deleting them
- MOCs — out of scope here. If the user wants to retire MOCs, that's a separate dedicated ask

## Signals

Score each note on the signals below. Multiple signals on the same note → stronger candidate. None of these is conclusive on its own.

### A. Orphan in the graph
Zero inbound `[[wikilinks]]` from any other note **and** zero outbound `[[wikilinks]]` (excluding links inside the abstract callout). Cheap to compute:

```sh
# Outbound: count wikilinks outside the abstract block (use the awk shape
# from vault-stub-check.sh to strip frontmatter + callout).
# Inbound: for note title T,
grep -lF "[[T]]" /Users/markusjohansen/vault-of-markus/*.md | wc -l
```

Account for aliases: a note's `aliases:` frontmatter list also matches inbound `[[Alias]]` links.

### B. Stale stub
Body is short (run the same logic as `vault-stub-check.sh`) **and** the file hasn't been modified in ≥ 90 days. A note that's been a stub for three months is unlikely to grow.

```sh
# mtime check
find /Users/markusjohansen/vault-of-markus -maxdepth 1 -name '*.md' -mtime +90
```

### C. Likely duplicate
Another note shares ≥ 3 distinctive keywords with this one and is materially longer or better-developed. Detection is expensive — delegate to the `vault-librarian` agent for the candidate set, not the main session. Ask the librarian: "Find pairs of notes where one looks like a thinner draft of the other."

### D. Abandoned capture
Note contains placeholder markers (`TODO`, `TBD`, `FIXME`, `???`) **and** hasn't been modified in ≥ 60 days. The user captured an intention and never returned to it.

### E. Single-link bookmark
The entire body is essentially one URL or one wikilink with no surrounding thought. Either fold the link into a richer note or drop it.

### F. Test / scratch leftovers
Filenames like `Untitled`, `Untitled 1`, `New note`, `test`, `asdf`, `xxx`. Cheap regex.

## Workflow

1. List the working set with `ls /Users/markusjohansen/vault-of-markus/*.md`, apply exclusions.
2. Build a per-note record: word count, inbound link count, outbound link count, mtime, placeholder markers present, scratch-name match.
3. Compute signals A, B, D, E, F directly in the main session — they're all cheap (grep + find + awk).
4. **For signal C only**, hand the working set's stubs / short notes to `vault-librarian` and ask it to find duplicate or near-duplicate pairs across the vault.
5. Rank candidates by number of signals hit, then by mtime (older first). Group by reason category in the output.
6. Show the candidate list. Wait for the user to triage. Apply nothing without explicit "delete X" per note.

## Output format

```
## Cull candidates — N notes scanned, M flagged

### Strong candidates (multiple signals)
- [[Note Title]] — orphan + stale stub + abandoned capture
  - 18 words, last modified 142 days ago
  - "TODO: come back to this" at line 12
  - No inbound or outbound links
- [[Other Note]] — orphan + likely duplicate of [[Richer Note]]
  - 32 words; [[Richer Note]] (210 words) covers the same topic
  - No inbound links

### Single-signal candidates
- [[Note A]] — orphan only (worth keeping if you'll link it later)
- [[Note B]] — scratch-name leftover (`Untitled 3.md`)
- [[Note C]] — single-link bookmark to https://example.com

### Possibly stale, but check first
- [[Note Title]] — last modified 187 days ago, but has 4 inbound links — keep
- [[Note Title]] — stub, but linked from [[Active Project]] — keep, may grow

## Suggested actions
- Delete: <list of strong candidates the skill is confident about — usually scratch names and single-link bookmarks>
- Merge: <duplicate pairs, with merge direction>
- Revisit: <stale stubs that have inbound links — worth filling in, not deleting>
- Leave: anything not above
```

## Rules

- **Report only.** No `rm`, no `Edit`, no `Write` from this skill. The user reviews and either runs the deletions themselves or asks Claude to delete them one by one with explicit names.
- **No MOC links.** Don't treat absence of links to a MOC as relevant; the vault rule is no MOC links anyway.
- **Don't propose deletion of long, well-formed notes.** Even if they're orphans, length and structure suggest value the user thought worth recording.
- **Be conservative on duplicates.** "Same topic" ≠ duplicate. Two notes on the same book by different authors, or the same project from different angles, are valid. Only propose merge when one is clearly a thin draft of the other.
- **Respect age the right direction.** Old + linked + complete = mature, not stale. Old + unlinked + stub = candidate.
- **Daily notes are off-limits.** They're history, not knowledge.

## When NOT to use this skill

- Right after a heavy capture session — give notes time to mature.
- When the user is mid-migration (e.g. importing notes from the other vaults they mentioned consolidating). Run this *after* migration settles.
