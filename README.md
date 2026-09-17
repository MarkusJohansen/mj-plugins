# mj-plugins

Markus Johansen's personal [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins).
A marketplace is just a git repo with a `.claude-plugin/marketplace.json` at its
root; each plugin lives in its own subdirectory.

## Add the marketplace

```sh
claude plugin marketplace add MarkusJohansen/mj-plugins
```

Then install any plugin below (or browse interactively with `/plugin`):

```sh
claude plugin install <plugin>@mj-plugins
```

## Plugins

| Plugin | Contents | Description |
|--------|----------|-------------|
| [`scaffold`](./scaffold) | 4 skills | Scaffolds and maintains a personal Claude Code config space — skills, subagents, hooks, rules, a global `CLAUDE.md`, and a `bootstrap.sh` that symlinks it all into `~/.claude/`. |
| [`devkit`](./devkit) | 8 skills, 3 agents, 3 hooks | Coding toolkit — planning, commit/PR/review/quality/docs skills, code-focused subagents, and auto-format / secret / dangerous-`rm` safety hooks. |
| [`obsidian`](./obsidian) | 6 skills, 1 agent, 3 hooks | Obsidian vault toolkit — note skills, the `vault-librarian` subagent, a path-scoped vault rule, and edit-guard / frontmatter / stub hooks. |
| [`notify`](./notify) | 3 hooks | Desktop attention cues — a Stop chime that fires when you've walked away, its idle-tracker, and a macOS notification banner. |
| [`opsx-orchestrate`](./opsx-orchestrate) | 2 skills | Orchestration over the opsx (OpenSpec) plugin — partition change items into non-overlapping scopes, then fan them out across isolated worktrees as one branch + PR each. |
| [`supacode`](./supacode) | 3 skills | Work with the Supacode agent terminal — add, use, and clean up worktrees through the supacode CLI. |
| [`htmlify`](./htmlify) | 1 skill | Turn anything from the conversation into one self-contained, offline HTML artifact you can open and share. |

```sh
claude plugin install scaffold@mj-plugins
claude plugin install devkit@mj-plugins
claude plugin install obsidian@mj-plugins
claude plugin install notify@mj-plugins
claude plugin install opsx-orchestrate@mj-plugins
claude plugin install supacode@mj-plugins
claude plugin install htmlify@mj-plugins
```

> **Note:** the `devkit`, `obsidian` and `notify` hooks read a few env vars for tuning —
> `CLAUDE_AUTOFORMAT`, `CLAUDE_CHIME`, `CLAUDE_CHIME_VOLUME`, `CLAUDE_CHIME_MIN_IDLE`,
> `CLAUDE_VAULT_PATH`, `CLAUDE_VAULT_AUTHORIZED`, `CLAUDE_VAULT_STUB_WORDS`. Plugins
> can't set env vars, so keep any override in your `settings.json`; unset, each script
> falls back to its in-script default.

## Adding a plugin to this marketplace

1. Create a `<plugin-name>/` directory at the repo root.
2. Add `<plugin-name>/.claude-plugin/plugin.json` (manifest) plus the plugin's
   `commands/`, `agents/`, `skills/`, or `hooks/` as needed.
3. Add an entry to `.claude-plugin/marketplace.json` with
   `"source": "./<plugin-name>"`.
4. Commit and push — `claude plugin marketplace update mj-plugins` picks it up.

When **changing** an existing plugin rather than adding one, bump `version` in its
`plugin.json`. `claude plugin update` compares that version, so a new skill shipped
without a bump reports "already at the latest version" and never reaches an existing
install.

## License

[MIT](./LICENSE) © Markus Johansen
