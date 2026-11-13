---
name: weave-notes
description: Identify linking opportunities across multiple notes in the vault-of-markus Obsidian vault and propose direct-relationship links between them. Use when the user says "find linking opportunities", "weave my notes", "/weave-notes", or "find related notes that should link". Different from `/link-notes`, which targets a single note — this skill operates across a set or the whole vault. Strict rule: never propose links whose only purpose is grouping; never link to or from Map-of-Content notes.
---

# weave-notes

Scan a set of notes (or the whole vault) and surface pairs that should link to each other because they are **directly related in content** — same concept, same project, one references the other's idea, one updates the other. Propose links inline where prose accommodates them, and as **markdown footnotes** where it doesn't.

## The two hard rules

These are non-negotiable. The user has explicitly called them out.

### Rule 1 — No links to or from Maps of Content (MOCs)

A MOC is a note whose job is to group other notes. The user is deliberately moving away from MOCs; the vault relies on direct note-to-note relationships and `categories` for grouping. Never:

- Propose a link **from** a regular note **to** a MOC.
- Propose a link **from** a MOC **to** a regular note.
- Suggest creating a new MOC.

**How to detect a MOC.** Treat a note as a MOC if any of these hold:

1. Filename matches: contains `MOC`, `Map of Content`, `Index`, or starts with `Map -`, `MoC -`, etc.
2. Frontmatter `categories:` contains `MOC` / `Map` / `Index`.
3. Content heuristic: the body has ≥4 wikilinks AND ≥60% of its non-blank, non-frontmatter, non-heading lines are *just* `[[wikilinks]]` (with little or no surrounding prose). Compute this only when filename + frontmatter don't already decide.

If unsure, ask the user once: "Is `[[Note X]]` a MOC?" — and remember the answer for the rest of the run.

### Rule 2 — Direct relationship only

A link is justified when the two notes are about the **same thing or directly engage with each other's content**, not when they happen to fall under the same broad topic.

Justified:
- "Note A explicitly discusses the concept Note B defines."
- "Note A is a follow-up to a decision Note B records."
- "Note A and Note B describe the same project / book / place / person."
- "Note A cites or contradicts Note B."

Not justified (do not propose):
- "Both notes are about fishing." → that's a category, not a relationship.
- "Both notes are in the Books category." → grouping, not relationship.
- "Both notes mention the same generic term (project, work, idea)." → too weak.

When in doubt, drop the link. False positives erode the graph's signal.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. Skip `Templates/` and `.obsidian/`. Meta-files (`CLAUDE.md`, `README.md`, `AGENTS.md`, `Home.md`, `Index.md`) are out of scope on both ends — don't propose links to or from them.

The user can scope the run three ways:

- **A specific set of notes** they name → operate only on that set.
- **A recent window** ("notes touched this week") → use `ls -t` + cutoff.
- **Whole vault** → delegate the heavy reading to the `vault-librarian` agent and merge proposals here.

Default to asking which scope they want if it isn't obvious from the prompt.

## Workflow

1. **Build the working set.** List the notes in scope.
2. **Filter out MOCs and meta-files** up front. Print the exclusion list so the user can correct it.
3. **For each note in the set, read it.** For large sets (>15 notes), delegate to `vault-librarian` — give it the working set and ask for a relationship matrix back.
4. **Identify candidate pairs.** A pair is a candidate when:
   - One mentions the other's title or a known alias, AND it's not already linked, OR
   - Both contain a distinctive shared proper noun (length ≥ 8, not a generic term), AND a quick read confirms they're discussing it from related angles.
5. **Apply the direct-relationship test** to every candidate. Drop pairs that fail.
6. **Decide placement** for each surviving link (see below).
7. **Present proposals as a punch-list.** No edits until the user accepts.

## Where to put the link

For each accepted pair, decide one of:

**(a) Inline link** — when the link target can be substituted naturally into existing prose:

> "I've been working through [[Active Reading]] techniques while reading [[Foundation]]…"

Use this whenever the note already names the concept in flowing prose. Show the exact `Edit` you'd apply, with enough surrounding context that the user can judge fit.

**(b) Footnote link** — when the relationship is real but prose doesn't accommodate it, or the link would feel grafted-on. Use a numbered markdown footnote:

> "…the approach I've been refining since 2024.[^1]
>
> [^1]: Related: [[Earlier note on the same approach]] — captures the original framing."

Rules for footnotes:

- Numbered (`[^1]`, `[^2]`) per note. Continue numbering if footnotes already exist.
- Footnote text starts with `Related: ` (or `See also: `, `Cf. `, `Contrast: ` if the relationship is contrast/disagreement) followed by the `[[Wikilink]]`, then a brief reason.
- Place all footnotes at the end of the note, after the body.
- One footnote per related note. Don't bundle multiple links into one footnote.

**(c) "Related notes" section** — *only* if the user explicitly asks for one. Default behavior is inline-or-footnote. The vault prefers organic linking over append-a-list-at-the-bottom.

## Output format

```
## Scope
- N notes considered
- Excluded as MOCs / meta: [[X]], [[Y]]

## Proposed links

### [[Note A]] ↔ [[Note B]]
- Why: <one-line relationship>
- Placement on A: inline at line 42 (`Edit` preview below) / footnote at end
- Placement on B: footnote at end / inline at line 17
- Edit preview:
  ```
  - before: ...
  + after:  ...
  ```

### [[Note C]] ↔ [[Note D]]
...

## Pairs considered and dropped
- [[Note A]] ↔ [[Note Q]] — both in Fishing category but no direct relationship. Dropped (Rule 2).
- [[Note Z]] → [[Some MOC]] — target is a MOC. Dropped (Rule 1).
```

The "Pairs dropped" section is important — it shows the user the discipline is being applied, not bypassed.

## Application

After the user accepts, apply edits one at a time with `Edit`. Never `replace_all` for prose. After each edit, the post-tool-use frontmatter hook may fire — that's fine, the warning is informational.

If the user accepts in bulk ("apply all"), still apply sequentially so each edit is reviewable in the diff.

## Don't

- Don't link to MOCs. Repeat: don't link to MOCs.
- Don't propose a link because two notes share a category.
- Don't add a "## Related" / "## See also" section by default.
- Don't insert ≥3 links to the same target in one note — once is the signal, more is noise.
- Don't fabricate notes. Only propose links to files that exist in the vault.
- Don't silently apply edits, even small ones. Vault rule: explicit permission per edit.
