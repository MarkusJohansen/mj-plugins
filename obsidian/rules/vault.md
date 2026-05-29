---
paths:
  - "__VAULT_PATH__/**"
---

# Working in the Obsidian vault

These rules load when Claude reads a file under `__VAULT_PATH__/`. They do **not** load in other projects — keeping the user-global CLAUDE.md smaller.

When the current path is under the vault, the vault's own `CLAUDE.md` and its "How I do my Vaults in Obsidian" note are the source of truth — read them. The vault rule is **never change anything without explicit user permission**; a `PreToolUse` hook (`vault-write-guard.sh`) emits a reminder on every edit there. A `PostToolUse` hook (`vault-frontmatter-check.sh`) warns when a saved note is missing frontmatter (`categories`, `date`) or the abstract callout.

## Skills that target the vault

- **Creating a note** — invoke `/new-note`. Stamps frontmatter + abstract callout + proposes backlinks.
- **Cleaning up a note** — invoke `/tidy-note` after edits, or when the frontmatter-check hook warns.
- **Adding links to one note** — invoke `/link-notes`. Always proposes, never edits silently.
- **Finding linking opportunities across many notes** — invoke `/weave-notes`. Cross-vault pass. Enforces the same two hard rules below.
- **Writing the abstract callout** — invoke `/abstract-note` (≤150 words, strict).
- **Today's journal** — invoke `/daily-note`.
- **Searching the vault** — invoke `/vault-search`. For broad/fuzzy queries it delegates to the `vault-librarian` agent.
- **Finding unfinished stubs** — invoke `/find-stubs`. Vault-wide audit. The `vault-stub-check.sh` hook also warns at save time when a note's body is under ~40 words.
- **Pruning low-value notes** — invoke `/cull-vault`. Reports candidates (orphans, abandoned stubs, duplicates, scratch leftovers) with reasons. Never deletes — the user decides.

For wide reads across many notes (finding related content, duplicates, topic organisation), delegate to the `vault-librarian` agent rather than reading dozens of files in the main session.

## Linking rules (load-bearing)

Apply these in every vault skill that proposes a `[[wikilink]]`.

1. **No links to or from Maps of Content (MOCs).** A MOC is a note whose purpose is grouping. The vault is deliberately moving away from MOCs; grouping is done via `categories` and direct relationships, not index notes. Detect MOCs by filename (`MOC`, `Map of Content`, `Index`), frontmatter category (`MOC`/`Map`/`Index`), or content (body ≥60% bare wikilinks).
2. **Direct relationship only.** Two notes share a category → that's not a reason to link. Two notes discuss the same specific thing, or one engages with the other's ideas → that's a reason to link. When in doubt, drop.
3. **Inline link first, footnote fallback.** If the relationship is real but prose doesn't accommodate the link, add a numbered markdown footnote at the end of the note (`[^1]: Related: [[Note]] — reason.`) rather than forcing the link or appending a "## Related" section.

## Vault skill chains

- Note creation: `/new-note` → `/link-notes` (propose links from the new note) → `/abstract-note` (if not yet written)
- Note maintenance: edit → `/tidy-note` → `/link-notes` if structure changed
- Graph health: `/weave-notes` over a recent batch or topic-scoped set when the graph feels under-connected
