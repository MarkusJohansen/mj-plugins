---
name: new-note
description: Create a new note in the vault-of-markus Obsidian vault, matching the user's conventions. Trigger when the user says "new note about X", "create a vault note", "/new-note", or asks to capture something into Obsidian. Stamps the note with the standard frontmatter (categories, date), an abstract callout, and proposes 1–3 backlinks from existing notes.
---

# new-note

Create a new Obsidian note in `/Users/markusjohansen/vault-of-markus/` that conforms to the user's vault conventions. Never overwrite an existing note. Always show the proposed filename + frontmatter + abstract before writing; ask for confirmation only if the title is ambiguous or the category isn't obvious.

## Preconditions

- Vault root: `/Users/markusjohansen/vault-of-markus/`. If you're somewhere else and the user clearly wants an Obsidian note, still write here.
- The vault's own `CLAUDE.md` says "never change ANYTHING in this vault without requesting permission." Creating a new file counts — get a clear go-ahead before the Write, but you don't need a second prompt for the proposed content if the user kicked off the skill.
- No folders. Notes live at the vault root. The exception is `Templates/` which you don't touch from this skill.

## Inputs

- **Title.** Use the user's words. Filename = `<Title>.md` with title-case kept as the user wrote it. Don't slugify, don't kebab-case — Obsidian likes spaces.
- **Category** (frontmatter `categories:` list). Ask if not stated. Look at existing categories with:
  ```sh
  grep -h '^  - ' /Users/markusjohansen/vault-of-markus/*.md | sort -u | head -40
  ```
  to propose an existing one. Don't invent a new category unless nothing fits.

## Template

```markdown
---
categories:
  - <category>
date: <YYYY-MM-DDTHH:MM:SS local>
---
>[!abstract]+ Abstract
> <One-paragraph summary, ≤150 words. What this note is about, what it contains, important related notes.>

---
# <Title>

<Body — leave a useful starter scaffold based on what the user asked for, or a single placeholder heading if they didn't say.>
```

Rules for the stamped content:

- `date` is **now**, local time, ISO-ish format matching the existing notes (`2026-05-14T09:30:00`).
- Abstract callout is mandatory. If you don't have content for it yet, write a one-line placeholder summary — don't leave the callout body empty.
- Use `>[!abstract]+` (collapsible, default open). Match other callouts (`>[!info]`, `>[!warning]`) when the user asks for a different vibe — the `+`/`-` controls expansion.
- Markdown heading hierarchy: one `#` for the title, `##` for sections, no skipping levels.

## Backlinks

Before writing, run a quick check for related existing notes:

```sh
ls /Users/markusjohansen/vault-of-markus/*.md | head
# then grep for keywords from the title:
grep -lFi "<keyword>" /Users/markusjohansen/vault-of-markus/*.md | head
```

If 1–3 strong matches exist, propose adding `[[Wikilinks]]` to them in either the abstract or the body. Always show the suggestions — don't silently insert links. Wide / fuzzy searches → delegate to the `vault-librarian` agent instead of grepping here.

**Linking discipline (same rule as `/link-notes` and `/weave-notes`):**

- **No Maps of Content.** Don't propose a link to any note whose role is grouping (filename contains `MOC` / `Map` / `Index`, frontmatter category `MOC`, or body is ≥60% bare wikilinks). Connections come from direct relationships.
- **Direct relationship only.** "Both about fishing" is grouping, not relationship — drop it. Link only when the new note and the candidate are about the same thing or directly engage with each other's content.
- If a backlink is real but doesn't fit naturally inline, use a markdown footnote at the end of the body: `[^1]: Related: [[Note Title]] — short reason.`

## Output

Write the file with `Write`. Then print:
- Path written
- Suggested backlinks (if any) the user might want to weave in
- Reminder to open it in Obsidian if they want to keep editing there
