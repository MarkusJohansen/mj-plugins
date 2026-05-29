# configure-claude

A Claude Code plugin that scaffolds and grows a **personal config space** — a
versioned git repo of your skills, subagents, hooks, path-scoped rules, and a
global `CLAUDE.md`, plus a `bootstrap.sh` that symlinks it all into `~/.claude/`
so your customizations are reproducible on any machine.

## What's in the box

| Skill | What it does |
|-------|--------------|
| `/scaffold-config` | Creates the config repo: folder structure, global `CLAUDE.md`, `settings.template.json`, and an idempotent `bootstrap.sh` symlinker. |
| `/add-skill` | Interviews you, then authors a new skill into `skills/`. |
| `/add-agent` | Interviews you, then authors a new subagent into `agents/`. |
| `/add-hook`  | Interviews you, then writes a hook script and wires it into `settings.template.json`. |

The three `add-*` skills ask targeted questions first, so the generated config
has specific, reliably-triggering descriptions instead of vague boilerplate.

## Install

`configure-claude` ships from the [`claude-marketplace`](../) marketplace:

```sh
claude plugin marketplace add MarkusJohansen/claude-marketplace
claude plugin install configure-claude@claude-marketplace
```

You can also browse and install interactively with the `/plugin` command inside
Claude Code.

## Usage

```
/scaffold-config        # one-time: create ~/claude-config and wire it up
/add-skill              # grow it: add a workflow skill
/add-agent              # add a delegated subagent
/add-hook               # add lifecycle automation
```

After scaffolding, `cd ~/claude-config && ./bootstrap.sh` links everything into
`~/.claude/`. Re-run `bootstrap.sh` any time after pulling updates — it's
idempotent, validates sources first, prunes stale symlinks, and refuses to
clobber a hand-edited `settings.json`.

## What the scaffold produces

```
~/claude-config/
  agents/        skills/        hooks/        rules/        templates/
  user-CLAUDE.md          → ~/.claude/CLAUDE.md      (symlink)
  settings.template.json  → ~/.claude/settings.json  (rendered, __REPO__ substituted)
  CLAUDE.md               # how to edit the config repo itself
  bootstrap.sh            # the symlinker / renderer
  README.md  .gitignore
```

## How it works

- **Symlinked** (edits go live immediately): `agents/`, `skills/`, `user-CLAUDE.md`.
- **Rendered** (re-run bootstrap after editing): `rules/*.md` and
  `settings.template.json`, because they carry a `__REPO__` placeholder that
  bootstrap substitutes with the repo's absolute path.
- **Bundles**: a `skills/<name>/` dir with a `.bundle` marker is opt-in — kept
  out of the global skill list and stamped per-repo with
  `bootstrap.sh bundle <name> <target-dir>`.

## Requirements

`bash`, `jq`, `awk`, `find`, `git` — all standard on macOS/Linux dev machines.

## License

MIT
