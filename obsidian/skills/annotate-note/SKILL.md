---
name: annotate-note
description: Add useful footnotes to a single note in the vault-of-markus Obsidian vault — cross-references to related notes, author asides, optional/variant rules, citations, DM notes. Trigger when the user says "add footnotes", "annotate this note", "/annotate-note", or asks for footnote-style enrichment of a target note. Always proposes — never edits silently. For pure link discovery (footnote is one of several placement options), use `/link-notes` instead.
---

# annotate-note

Add load-bearing footnotes to a single target note. A footnote is the right tool when something *belongs with* the prose but doesn't fit inside it — a cross-reference, an aside, an alternative reading, a citation, a DM-eyes-only note. Footnotes keep the main flow clean; they let a reader pick up the extra context only when they want it.

This skill is narrower than `/link-notes`. Link-notes treats footnotes as a fallback placement for wikilinks that don't fit inline. This skill is footnote-first: it looks for *any* annotation a footnote would carry well, including but not limited to vault links.

## What counts as a useful footnote

A footnote earns its place when it:

1. **Points at a directly related vault note** that prose can't accommodate inline (same discipline as `/link-notes` — direct relationship, not grouping, no MOCs).
2. **Cites a source** — a book, an article, a conversation, a date — that the body shouldn't carry inline.
3. **Adds an author aside** — a parenthetical the writer wants to keep but doesn't want in the main voice. *"I changed my mind on this in 2025."* / *"Optional: see variant rule below."*
4. **Carries DM/reader-eyes-only context** in adventure or game notes — the kind of margin note a published module uses.
5. **Disambiguates or warns** — *"Not to be confused with the other Cassian."* / *"This used to be called X."*

A footnote does NOT earn its place when:

- It restates what the sentence already says.
- It points at a MOC (same exclusion as `/link-notes` — never link to or from MOCs).
- It links to a note the two notes only share a *category* with. That is grouping, not relationship.
- It adds material that should just live in the body.
- The note already has the same footnote (or one pointing at the same thing). One footnote per concept.

## The two hard rules (carried from /link-notes)

If a footnote would create or carry a `[[wikilink]]`, the same vault-wide linking discipline applies:

### Rule 1 — No links to or from Maps of Content (MOCs)
Detect MOCs by filename (`MOC`, `Map of Content`, `Index`), frontmatter `categories:` containing `MOC`/`Map`/`Index`, or body ≥60% bare wikilinks. Don't link to them. Don't add a footnote on a MOC.

### Rule 2 — Direct relationship only
Same thing, same engagement, lineage between drafts → link. "Both about fishing" → don't.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. One target note per invocation. Other vaults out of scope.

## Strategy

1. **Read the target note in full.** Note the frontmatter, the existing footnotes (numbering and style), and the overall voice. Match it.

2. **Walk the note and tag candidate footnote sites.** For each candidate, record:
   - Line number and the exact anchor phrase.
   - What kind of footnote it would be (link / source / aside / DM-note / disambiguation).
   - The single sentence the footnote would carry.

3. **For link footnotes**, check the vault: does the referenced thing exist as a note? Is it a MOC? Is the relationship direct?
   ```sh
   ls /Users/markusjohansen/vault-of-markus/*.md | xargs -n1 basename | sed 's/\.md$//' | grep -i "<term>"
   grep -inwF "<candidate>" /Users/markusjohansen/vault-of-markus/<target>.md
   ```
   Drop anything that fails Rule 1 or Rule 2.

4. **De-duplicate against existing footnotes.** If the note already carries the same reference, drop the candidate.

5. **Propose, don't apply.** Show each candidate as:
   ```
   - Line 75, anchor: "the Coppercoast in the west"
     Kind: link
     Footnote text: "The Coppercoast is [[The coppercoast league]] — a privateer thalassocracy whose 'piracy-as-law' charter is the legal world the Broken Compass operate under."
   ```
   Wait for go-ahead before editing. The vault rule is no silent changes.

## Footnote mechanics

- **Numbering.** Continue the note's existing numbering. If the note has `[^1]`, `[^2]`, `[^19]`, the next free number is `[^3]` (gaps are fine — pick the next unused integer, not next-after-max). If the note has named footnotes (`[^concept]`), follow that convention instead.
- **Placement of the marker.** Attach to the end of the clause/sentence the footnote pertains to, immediately after the punctuation: `...the Coppercoast in the west,[^3]`. No space before the marker.
- **Placement of the body.** A single blank line before each footnote body. Group all footnote bodies at the end of the note, in numerical order. If the note already has a footnote section at the bottom, insert there.
- **Prefix style for link footnotes.** Match `/link-notes`: lead with `Related:` / `See also:` / `Cf.` / `Contrast:` / `Grew out of:` / `The X is [[Note]] — …`.
- **One footnote per concept per note.** Don't double-footnote the same target from different anchors in the same note.
- **Don't add inside quoted read-aloud text if the marker would change how a DM reads the block.** Prefer placing the marker just outside the quote, or use the first occurrence outside read-aloud.

## Editing rules

- One `Edit` call at a time.
- Never `replace_all` for prose.
- Two edits per footnote: one to add the marker in the body, one to add the footnote body at the bottom of the file. Do them as separate `Edit` calls to keep diffs reviewable.
- Don't rewrite the surrounding prose. The footnote should attach to the existing sentence unchanged.

## Don't

- Don't add footnotes silently. Always propose first.
- Don't add a footnote to a MOC, or one that links to a MOC.
- Don't add a footnote just because a category matches.
- Don't restructure existing footnotes (re-numbering, re-ordering) unless the user asks. Append.
- Don't add a `## Notes` / `## Footnotes` heading — Obsidian renders the footnote section automatically.
- Don't invent vault notes. Only reference files that exist.
