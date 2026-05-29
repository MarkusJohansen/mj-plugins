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

| Plugin | Description |
|--------|-------------|
| [`scaffold`](./scaffold) | Scaffolds and maintains a personal Claude Code config space — skills, subagents, hooks, rules, a global `CLAUDE.md`, and a `bootstrap.sh` that symlinks it all into `~/.claude/`. |
| [`devkit`](./devkit) | Coding toolkit — planning, commit/PR/review/quality skills, code-focused subagents, and auto-format / secret / dangerous-`rm` safety hooks. |
| [`obsidian`](./obsidian) | Obsidian vault toolkit — note skills, the `vault-librarian` subagent, a path-scoped vault rule, and edit-guard / frontmatter / stub hooks. |
| [`notify`](./notify) | Desktop attention cues — a Stop chime that fires when you've walked away, its idle-tracker, and a macOS notification banner. |
| [`ralph`](./ralph) | Sets up a Ralph Wiggum development environment — scaffolds `PROMPT.md`, `AGENT.md`, `fix_plan.md`, `specs/`, and a supervised loop runner for unattended agent iteration. |

```sh
claude plugin install scaffold@mj-plugins
claude plugin install devkit@mj-plugins
claude plugin install obsidian@mj-plugins
claude plugin install notify@mj-plugins
claude plugin install ralph@mj-plugins
```

> **Note:** `devkit`, `obsidian` and `notify` hooks read a few env vars
> for tuning (`CLAUDE_CHIME*`, `CLAUDE_VAULT_PATH`). Plugins can't set env vars,
> so keep those in your `settings.json` if you want to override the in-script
> defaults.

## Adding a plugin to this marketplace

1. Create a `<plugin-name>/` directory at the repo root.
2. Add `<plugin-name>/.claude-plugin/plugin.json` (manifest) plus the plugin's
   `commands/`, `agents/`, `skills/`, or `hooks/` as needed.
3. Add an entry to `.claude-plugin/marketplace.json` with
   `"source": "./<plugin-name>"`.
4. Commit and push — `claude plugin marketplace update mj-plugins` picks it up.

## License

[MIT](./LICENSE) © Markus Johansen
