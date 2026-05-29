---
name: scaffold-config
description: Scaffold a personal Claude Code config repo — a versioned source of truth for skills, subagents, hooks, rules and a global CLAUDE.md, plus a bootstrap.sh that symlinks it all into ~/.claude. Use when the user says "set up my claude config", "scaffold my config", "configure claude for me", "/scaffold-config", or wants a managed dotfiles-style home for their Claude customizations. Greenfield-only — refuse to scaffold on top of a populated config repo without explicit confirmation.
---

# scaffold-config

Create the folder structure and starter files for a personal Claude Code config
repo, modeled on the layout Anthropic recommends: agents, skills, hooks, and
rules live in one git repo and `bootstrap.sh` symlinks (or renders) them into
`~/.claude/` so edits go live without a copy step.

This skill **creates files only**. It does not run `bootstrap.sh` itself unless
the user explicitly asks — it offers to.

## What gets created

```
<config-repo>/
  agents/        # subagent definitions (.md w/ frontmatter)  → ~/.claude/agents/
  skills/        # skill definitions (each <name>/SKILL.md)   → ~/.claude/skills/
  hooks/         # shell scripts referenced by settings.json
  rules/         # path-scoped rules (.md w/ paths:)          → ~/.claude/rules/ (rendered)
  templates/     # starter files to stamp into other repos
  user-CLAUDE.md # global instructions                        → ~/.claude/CLAUDE.md
  CLAUDE.md      # how to edit THIS repo (project-scoped)
  settings.template.json  # rendered → ~/.claude/settings.json (__REPO__ substituted)
  bootstrap.sh   # idempotent symlinker / renderer
  README.md
  .gitignore
```

## Steps

1. **Pick the location.** Ask the user where the repo should live (default
   `~/claude-config`). Use AskUserQuestion if they haven't said. Expand `~`.

2. **Guard against clobbering.** If the target dir already exists and is
   non-empty (especially if it already has `bootstrap.sh` / `settings.template.json`),
   STOP and confirm before writing. Greenfield-only by default.

3. **Stamp the templates.** Copy byte-for-byte from this plugin's template dir —
   do **not** hand-retype them (shebangs and `__REPO__` placeholders get eaten
   when transcribed):

   ```bash
   DEST="$HOME/claude-config"          # or the user's chosen path
   TPL="${CLAUDE_PLUGIN_ROOT}/skills/scaffold-config/templates"
   mkdir -p "$DEST"/{agents,skills,hooks,rules,templates}
   touch "$DEST"/{agents,skills,rules}/.gitkeep
   cp "$TPL/bootstrap.sh"            "$DEST/bootstrap.sh"
   cp "$TPL/settings.template.json" "$DEST/settings.template.json"
   cp "$TPL/user-CLAUDE.md"         "$DEST/user-CLAUDE.md"
   cp "$TPL/CLAUDE.md"              "$DEST/CLAUDE.md"
   cp "$TPL/README.md"              "$DEST/README.md"
   cp "$TPL/gitignore"              "$DEST/.gitignore"
   cp "$TPL/hooks/statusline.sh"    "$DEST/hooks/statusline.sh"
   chmod +x "$DEST/bootstrap.sh" "$DEST/hooks/"*.sh
   ```

   If `${CLAUDE_PLUGIN_ROOT}` is unset (running outside the plugin), fall back to
   this skill's own directory.

4. **Personalize `user-CLAUDE.md`.** Ask the user a couple of identity questions
   (their role / stack, and one or two working preferences) and fill the marked
   sections. Keep it short — under 50 lines. Don't invent preferences.

5. **Initialize git** (offer, don't force): `git -C "$DEST" init -q && git -C "$DEST" add -A && git -C "$DEST" commit -qm "scaffold claude config"`.

6. **Validate, then offer to install.** Run `bash "$DEST/bootstrap.sh" validate`
   to confirm sources are sound, then `bash "$DEST/bootstrap.sh" --dry-run` to
   preview. Show the user the dry-run output and ask before running the real
   `./bootstrap.sh` (it touches `~/.claude/`).

7. **Report.** One line per created file, then point them at the next skills:
   `/add-skill`, `/add-agent`, `/add-hook` to populate the repo.

## Rules

- **Greenfield by default.** Refuse to overwrite a populated config repo without
  explicit confirmation.
- **Don't run bootstrap without asking** — it mutates `~/.claude/`.
- **Don't invent the user's preferences** in `user-CLAUDE.md`. Ask, or leave the
  section as a short prompt for them to fill later.
- **Copy templates, don't retype them.** `cp` avoids shebang/placeholder corruption.
- Keep stamped config files lean (CLAUDE.md / user-CLAUDE.md under ~150 lines).
