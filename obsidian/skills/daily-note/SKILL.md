---
name: daily-note
description: Create today's daily note in vault-of-markus, linking yesterday and tomorrow, and surfacing open TODOs from recent notes. Trigger when the user says "daily note", "today's journal", "/daily-note", or "start today".
---

# daily-note

Create a daily note for today in `/Users/markusjohansen/vault-of-markus/`. Filename format: `YYYY-MM-DD.md` (e.g. `2026-05-14.md`). If today's note already exists, open it and append a new timestamped section instead of overwriting.

## Template

The angle-bracket placeholders below (`<...>`) are slots — substitute real values before writing. Don't leave any literal `<placeholder>` in the final note.

```markdown
---
categories:
  - Daily
date: <today, ISO date>
---
>[!abstract]+ Abstract
> Daily note for <weekday, YYYY-MM-DD>. Captures what I worked on, decisions, and open threads.

---
# <YYYY-MM-DD>

← [[<yesterday's YYYY-MM-DD>]] | [[<tomorrow's YYYY-MM-DD>]] →

## Focus
- 

## Notes


## Open from recent days

<bullet list of unchecked `- [ ]` items found in the last 3 daily notes>

## Done
- 
```

## Steps

1. Check if today's note exists: `test -f /Users/markusjohansen/vault-of-markus/<today>.md`.
   - If yes: read it, propose an appended `## <HH:MM>` section. Stop here unless the user wanted a fresh one.
2. Determine yesterday and tomorrow (just date math; no need to check if those notes exist — wikilinks to missing notes are fine in Obsidian, the user may create them later).
3. Find recent open TODOs:
   ```sh
   ls -t /Users/markusjohansen/vault-of-markus/20*-*-*.md 2>/dev/null | head -3 | \
     xargs grep -hn '^- \[ \]' 2>/dev/null
   ```
   Include up to ~10. Skip ones older than 14 days.
4. Render the template, show it to the user, write on confirmation.
5. Remind the user to switch to Obsidian if they want live editing.

## Don't

- Don't write daily notes for past or future dates from this skill — that's a different ask.
- Don't fabricate "Done" items. The skill seeds the structure; the user fills it in.
- Don't change the filename format (`YYYY-MM-DD`). Obsidian's calendar / daily-note plugins assume it.
