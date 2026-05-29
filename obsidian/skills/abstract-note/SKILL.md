---
name: abstract-note
description: Write or refresh the 150-word abstract callout at the top of an Obsidian note in vault-of-markus. Trigger when the user says "write an abstract", "refresh the abstract", "/abstract-note", or when `/tidy-note` flagged a missing abstract. Strict ≤150 word cap.
---

# abstract-note

Produce the abstract callout that sits at the top of every vault note. The callout has three jobs (per the user's `How I do my Vaults in Obsidian.md`):

1. What this note is about
2. What it contains
3. Important related notes (`[[wikilinks]]`)

## Format

```markdown
>[!abstract]+ Abstract
> <One paragraph, ≤150 words, covering points 1–3 above.>
```

- Single paragraph. No bullet list inside the callout — keep prose dense.
- Always `>[!abstract]+` (collapsible, default open).
- Sits *immediately* after the closing `---` of the frontmatter. Nothing between frontmatter and abstract.
- Then a `---` separator, then the body.

## Workflow

1. Read the whole note. Don't abstract from the title alone.
2. Count words: aim for 80–130. Hard cap 150. Re-tighten if you spill over.
3. If the note already has an abstract:
   - Compare against the current body. If the body has drifted, propose an updated abstract showing the diff (old → new).
   - Don't rewrite an already-good abstract.
4. Reference 1–3 related notes by `[[Wikilink]]`. Only include links to notes that actually exist (`ls /Users/markusjohansen/vault-of-markus/*.md`).
5. Show the user the proposed abstract before applying. Apply with `Edit`.

## Tone

Match the user's existing voice in the vault: matter-of-fact, first-person where appropriate, Norwegian if the surrounding note is in Norwegian. Don't add filler like "This note discusses…" — the callout itself signals what it is.

## Don't

- Don't exceed 150 words. Count.
- Don't invent content not in the note body.
- Don't add a `## Abstract` heading — it's a callout, not a heading.
- Don't strip metadata or rearrange the note while you're in there. Abstract only.
