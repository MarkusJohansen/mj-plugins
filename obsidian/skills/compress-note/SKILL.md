---
name: compress-note
description: Trim a note in the vault-of-markus Obsidian vault down to its essentials by cutting non-essential text — deletion only, surviving text stays word-for-word the user's. Takes an aggressiveness level 1–5. Trigger when the user says "compress this note", "trim this note down", "cut the fat from this note", "/compress-note", "/compress-note 4", or asks for a shorter/denser version of an existing note.
---

# compress-note

Make one note shorter by **removing** text, never by rewriting it. Every sentence that survives a compression pass is exactly what the user wrote — this skill deletes whole units (sentences, bullets, sections, examples) and nothing else. Always show what would be cut and get a go-ahead before touching the file.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. One note per invocation. Skip `Templates/`.

## Arguments

`/compress-note [level] [note]` — level is `1`–`5`, default `3`. Reject anything outside 1–5. If no note is given, use the one under discussion; if that's ambiguous, ask.

## Level ladder

Each level cuts everything the levels below it cut, plus its own class. No target ratio — a tight note at level 3 barely shrinks, and that's the correct outcome.

| Level | Cuts |
|---|---|
| 1 | Filler: empty sections, duplicate headings, sentences that restate the previous one, throat-clearing openers, trailing "more to come" notes. |
| 2 | + tangents and asides, and passages already covered by a note this one links to. |
| 3 | + secondary examples, hedging ("probably", "it might be that…" as whole clauses only if the clause stands alone), background the intended reader already has. |
| 4 | + all but the single best example; keep only what's needed to reconstruct the idea from scratch. |
| 5 | Bare essentials: the definition and the key claims. Everything else goes — still as the user's own lines, not a summary. |

## Steps

1. **Resolve** target note and level. Read the note end-to-end.
2. **Bail out early** if the body is under ~150 words (`wc -w`) — say it's already tight and stop. Compressing a stub produces nothing.
3. **Check for a safety net**: `git -C /Users/markusjohansen/vault-of-markus status --short` — if the vault isn't a git repo or the note has uncommitted changes, say so in the report so the user knows the cut isn't trivially reversible.
4. **Mark the protected zones** (never cut, see Rules): frontmatter, the abstract callout, headings that still have surviving content beneath them, source/citation lines, code blocks, footnote definitions still referenced.
5. **Build the punch-list.** One entry per proposed cut:
   - the exact excerpt (truncate long ones with `…`)
   - the level tier that triggered it (`L1 filler`, `L3 secondary example`, …)
   - one line of why
6. **Flag the collateral** separately from the cuts:
   - `[[wikilinks]]` that exist *only* inside a cut passage — the graph loses that edge. Offer the footnote fallback from the vault linking rules (`[^1]: Related: [[Note]] — reason.`) instead of dropping it.
   - whether the abstract callout still describes the note after the cut → follow-up `/abstract-note`.
   - headings left with no body.
7. **Report the size**: words before → after, and the level used.
8. **Wait for the go-ahead.** The user may veto individual entries by number — honour that and re-report the size.
9. **Apply with `Edit`, one edit per cut**, `old_string` = the text being removed, `new_string` = `""` or the joining whitespace. Never `Write` the whole file.
10. **Summarise** in one line: level, words before → after, follow-ups outstanding.

## Rules

- **Deletion only.** If you catch yourself typing a word that isn't already in the note, stop — that's a rewrite, and this skill doesn't do rewrites at any level. Joining whitespace and punctuation needed to keep a sentence grammatical after a clause is removed is the only exception; if a cut needs more than that to read correctly, drop the cut instead.
- **Cut-only is load-bearing, not a style choice.** It's what makes this skill legal under the vault's "don't reword his prose" rule. Never relax it, even if the user asks for "shorter, rewrite it if you have to" — that's a different ask; say so and offer to draft a separate note instead of overwriting this one.
- **Nothing is cut without the punch-list being accepted.** No silent trims, no "obvious" ones applied up front.
- **Never cut**: frontmatter, the abstract callout, a source/citation/attribution line, a quote of someone else's words, or a `TODO`/open question the user left for themselves.
- **Repetition isn't automatically filler.** A point made twice for emphasis, in different words, is the user's rhetoric. Only cut a restatement when it adds nothing and reads as an accident.
- **Don't escalate.** Cut at the level asked for, not the level you think the note deserves. If a level-2 pass looks pointless, say "level 2 finds ~30 words, try 4" and let the user pick.
- **One note at a time.** If asked to compress a folder or the whole vault, do the first note and list the rest.

## Chains

- Compress → `/abstract-note` when the abstract no longer matches.
- Compress → `/link-notes` when cuts removed wikilinks worth re-placing.
- `/tidy-note` is the structural pass; run it first if the note is also messy. This skill assumes structure is fine and only removes content.
