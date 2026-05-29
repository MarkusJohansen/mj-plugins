# claude-config

My personal Claude Code configuration — subagents, skills, hooks, path-scoped
rules, and global instructions, kept in one git repo and symlinked into
`~/.claude/` by `bootstrap.sh`. Scaffolded by
[configure-claude](https://docs.claude.com/en/docs/claude-code/plugins).

## Layout

```
agents/         # subagent definitions          → ~/.claude/agents/   (symlinked)
skills/         # skill definitions             → ~/.claude/skills/   (symlinked)
hooks/          # shell scripts wired in settings.json
rules/          # path-scoped rules             → ~/.claude/rules/    (rendered)
templates/      # starter files to stamp into other repos
settings.template.json  # → ~/.claude/settings.json (rendered, __REPO__ substituted)
user-CLAUDE.md  # global instructions          → ~/.claude/CLAUDE.md (symlinked)
CLAUDE.md       # how to edit THIS repo
bootstrap.sh    # idempotent symlinker / renderer
```

## Install on a fresh machine

```sh
git clone <repo-url> ~/claude-config
cd ~/claude-config
./bootstrap.sh --dry-run   # preview
./bootstrap.sh             # install
```

`bootstrap.sh` is idempotent and safe to re-run after pulling updates. It:

- Validates source frontmatter, hook references, and rule paths first
  (`bootstrap.sh validate` runs the checks without touching anything).
- Prunes stale symlinks under `~/.claude/{agents,skills,rules}`.
- Refuses to overwrite a hand-edited `~/.claude/settings.json` (`--force` to override).
- Refuses to overwrite real files at the destination (locally-added agents are kept).
- Supports `--dry-run`.

## Growing the config

Use the configure-claude skills:

- `/add-skill` — interview, then author a new skill into `skills/`.
- `/add-agent` — interview, then author a new subagent into `agents/`.
- `/add-hook`  — interview, then author a hook and wire it into `settings.template.json`.

## Bundles

A `skills/<name>/` dir containing a `.bundle` marker is **opt-in**: bootstrap
skips it during the global install, and you stamp it into a specific repo with
`./bootstrap.sh bundle <name> <target-dir>`. Use bundles to keep
domain-specific skills out of every project's context.
