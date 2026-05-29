---
name: tidy-note
description: Clean up a note in the vault-of-markus Obsidian vault so it matches the user's conventions — frontmatter (categories + date), abstract callout, heading hierarchy, collapsible callouts, no dangling links. Trigger when the user says "tidy this note", "clean up this Obsidian note", "/tidy-note", or after editing an existing note in the vault.
---

# tidy-note

Bring an existing vault note up to the user's documented conventions. Operate on one note at a time. Always show a diff of proposed changes before applying — the vault's `CLAUDE.md` requires explicit permission for any change.

## Scope

Vault: `/Users/markusjohansen/vault-of-markus/`. Skip notes under `Templates/`.

## Checklist (apply in order)

1. **Frontmatter present and well-formed.**
   - Required keys: `categories` (list), `date` (ISO-ish: `YYYY-MM-DDTHH:MM:SS` or `YYYY-MM-DD HH:MM`).
   - Optional: `aliases` (list). Other keys are fine — don't delete them.
   - If frontmatter is missing entirely, propose one. Use file mtime for `date` if you can't infer it: `stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' <file>`.
   - If `categories` is empty, look at the note body and propose 1–2 categories that already exist elsewhere in the vault (see [[new-note]] for how to list them).

2. **Abstract callout present.**
   - Convention is `>[!abstract]+ Abstract` immediately after the frontmatter, ≤150 words, summarising what the note is about + content + related notes.
   - If missing, propose one — but do NOT auto-generate from a quick skim. Either delegate to [[abstract-note]] or flag it as a follow-up. Don't write a low-quality abstract just to fill the slot.

3. **Heading hierarchy.**
   - Exactly one `#` (the title). If there's no top-level heading, propose adding one matching the filename.
   - Don't skip levels (`##` → `####`). If skipping occurs, propose flattening to the next valid level.

4. **Callouts collapsible where appropriate.**
   - Long callouts (`>[!info]`, `>[!warning]`, `>[!abstract]`, etc.) should use `+` (open) or `-` (collapsed) so they're collapsible. Inline `>[!note]` style without `+`/`-` is fine for short asides.

5. **Dangling wikilinks.**
   - `grep -oE '\[\[[^]]+\]\]' <file>` to list links. For each, check the target file exists:
     ```sh
     test -f "/Users/markusjohansen/vault-of-markus/<Target>.md"
     ```
   - Flag dangling links — don't auto-delete. The user may be intentionally seeding a note that doesn't exist yet.

6. **Tags vs categories.**
   - In `vault-of-markus`, grouping is done via `categories` (frontmatter list) — *not* `tags`. If the note has a `tags:` field, surface it as a question rather than silently moving the values into `categories`.

## Workflow

1. Read the note end-to-end.
2. Compile a list of findings against the checklist above.
3. Show the findings as a punch-list with each proposed edit (before / after).
4. Wait for the user's go-ahead. Apply with `Edit` (one Edit per logical change is fine, no need to batch into Write).
5. Print a one-line summary of what changed and what remains as a follow-up (e.g. abstract still needed).

## Don't

- Don't auto-fix anything without the user accepting the punch-list.
- Don't reformat prose, rewrite paragraphs, or "improve" the writing. This skill is structural cleanup only — content edits are a separate ask.
- Don't move the note to a folder. Notes live at the vault root.
