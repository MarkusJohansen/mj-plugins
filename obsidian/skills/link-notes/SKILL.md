---
name: link-notes
description: Find and propose missing links for a single target note in the vault-of-markus Obsidian vault. Trigger when the user says "add backlinks", "link this to related notes", "/link-notes", or asks which existing notes a target note should connect to. Always proposes — never edits silently. For a cross-vault pass over many notes at once, use `/weave-notes` instead.
---

# link-notes

Surface candidate links between a single target note and the rest of the vault. The vault embraces graph-style connections (no folders, no MOCs going forward — connections come from `[[wikilinks]]`), so good links are load-bearing for the user's workflow.

## The two hard rules

These match `/weave-notes` — same discipline, same exclusions.

### Rule 1 — No links to or from Maps of Content (MOCs)

Never propose a link from the target to a MOC, or from a MOC to the target. Detect MOCs by:

1. Filename contains `MOC`, `Map of Content`, `Index`, or starts with `Map -` / `MoC -`.
2. Frontmatter `categories:` includes `MOC`, `Map`, or `Index`.
3. Body is ≥60% bare wikilinks (≥4 of them) with little surrounding prose.

If unsure whether a candidate is a MOC, ask once and remember the answer.

Meta-files (`CLAUDE.md`, `README.md`, `AGENTS.md`, `Home.md`, `Index.md`) are also out of scope as link targets.

### Rule 2 — Direct relationship only

A link is justified when the two notes are about the **same thing or directly engage with each other's content** — not when they happen to share a category or broad topic. "Both about fishing" is grouping, not relationship; drop it.

See `/weave-notes` for the full justified / not-justified list. When in doubt, drop.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. Operate on one target note per invocation. Other vaults are out of scope.

## Strategy

1. **Read the target note.** Extract:
   - Title (filename without `.md`)
   - `aliases` from frontmatter (if any)
   - `categories` from frontmatter
   - Distinctive nouns / proper nouns from the body — names, places, projects, books, technical terms

2. **Find candidate matches.**
   - List vault note titles: `ls /Users/markusjohansen/vault-of-markus/*.md | xargs -n1 basename | sed 's/\.md$//'`
   - For each candidate title (length ≥ 8 chars, or matches an alias) — grep for a case-insensitive whole-word occurrence in the target note's body:
     ```sh
     grep -inwF "<candidate>" /Users/markusjohansen/vault-of-markus/<target>.md
     ```
   - Also match common aliases by reading the frontmatter `aliases:` lists of other notes.
   - If the scope is broad (e.g. "find everything that could link to this") → delegate to the `vault-librarian` agent rather than grepping yourself; it can read many files without polluting this context.

3. **Filter.**
   - Drop candidates already linked (`[[X]]` already appears).
   - Drop generic short titles (< 8 chars) unless the user added them as aliases — too many false positives.
   - Drop the target itself.

4. **Apply the two hard rules** to every candidate. Drop MOCs. Drop pairs that fail the direct-relationship test.

5. **Propose.** Show each surviving candidate with the line number where it occurs in the target. Format:
   ```
   - [[Candidate Note]]  (line 42: "...some phrase mentioning Candidate Note...")
     Why: <one-line direct relationship>
     Placement: inline at line 42 / footnote at end of note
   ```

   For placement, decide one of:

   - **Inline link** when the prose already names the concept naturally — substitute `[[Wikilink]]` into the existing sentence.
   - **Footnote link** when the relationship is real but prose doesn't accommodate it inline. Use a numbered markdown footnote at the end of the note:

     ```
     ...the approach I've been refining since 2024.[^1]

     [^1]: Related: [[Earlier note on the same approach]] — captures the original framing.
     ```

     Footnote rules: numbered (`[^1]`, `[^2]`), continue existing numbering if the note already has footnotes, prefix the text with `Related:` / `See also:` / `Cf.` / `Contrast:`, one footnote per related note.

   Default to inline when it fits; fall back to footnote rather than forcing a grafted-on sentence.

   Do **not** add a `## Related` / `## See also` section unless the user explicitly asks.

   Apply with `Edit` (one edit at a time, never `replace_all` for prose).

## Reverse direction

If asked "what should link *to* this note":

- Pick distinctive terms from the target (title + aliases + frontmatter `categories` items if specific).
- Grep across the vault for unlinked occurrences:
  ```sh
  grep -lnwiF "<term>" /Users/markusjohansen/vault-of-markus/*.md | grep -v "<target>.md"
  ```
- Propose updates to the other notes. Always one-edit-at-a-time, always with permission.

## Don't

- Don't insert links silently.
- Don't link to or from MOCs. Repeat: don't link to MOCs.
- Don't propose a link because two notes share a category — that's grouping, not relationship.
- Don't add a `## Related` / `## See also` section by default. Inline or footnote only.
- Don't link the same target twice in the same paragraph. One link per concept is enough; Obsidian's graph counts them all.
- Don't fabricate notes that don't exist. Only propose links to files actually present in the vault.
