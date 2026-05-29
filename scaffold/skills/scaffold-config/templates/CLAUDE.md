# CLAUDE.md

This repo is the source of truth for my Claude Code agents, skills, hooks, and
settings. `bootstrap.sh` symlinks (or renders) everything into `~/.claude/`, so
edits to symlinked files go live immediately — no copy step.

This file is loaded **only when editing this repo**. Machine-wide behavioral
defaults live in `user-CLAUDE.md` (which becomes `~/.claude/CLAUDE.md`).

## Layout

- `agents/` — subagent definitions (`.md` with frontmatter). Symlinked flat into `~/.claude/agents/`.
- `skills/` — skill definitions (`<name>/SKILL.md`). Each linked to `~/.claude/skills/<name>`. A dir with a `.bundle` marker is opt-in — bootstrap skips it globally; stamp it into a repo with `bootstrap.sh bundle <name> <target>`.
- `hooks/` — shell scripts referenced by `settings.template.json`. Paths there use `__REPO__`.
- `rules/` — path-scoped rules (`.md` with a `paths:` glob). **Rendered** (not symlinked) into `~/.claude/rules/` so `__REPO__` is substituted. Re-run bootstrap after editing.
- `templates/` — starter files to stamp into other repos.
- `settings.template.json` — rendered → `~/.claude/settings.json` with `__REPO__` substituted. Drift-protected: bootstrap refuses to clobber a hand-edited `settings.json` (`--force` to override).
- `user-CLAUDE.md` — global instructions; symlinked → `~/.claude/CLAUDE.md`.

## Naming conventions (load-bearing)

- **Agents = nouns / roles** you delegate to: `code-reviewer`, `solution-architect`.
- **Skills = verbs** the main session performs: `commit`, `write-pr`, `tidy-note`.

`name` in frontmatter must match the filename (agents) / folder name (skills).
Don't drift them — `~/.claude/` symlinks reference these names.

## Adding things

- **Agent:** create `agents/<name>.md` (frontmatter `name`, `description`, optional `tools`, `model`). Live via symlink after one bootstrap. Or use `/add-agent`.
- **Skill:** create `skills/<name>/SKILL.md` (frontmatter `name`, `description`). Live via the dir symlink. Or use `/add-skill`.
- **Hook:** add a script under `hooks/`, wire it in `settings.template.json` with a `__REPO__` path, re-run bootstrap. Or use `/add-hook`.
- **Rule:** create `rules/<name>.md` with `paths:` frontmatter, re-run bootstrap.

## Leave alone

- `settings.local.json` — never commit; per-machine permission allowlists only.
- The symlinks themselves — if one looks broken, re-run `bootstrap.sh`; don't replace it with a real file.
- No implementation code here. Configuration only.
