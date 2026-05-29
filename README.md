# markusjohansen

Markus Johansen's personal [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins).
A marketplace is just a git repo with a `.claude-plugin/marketplace.json` at its
root; each plugin lives in its own subdirectory.

## Add the marketplace

```sh
claude plugin marketplace add MarkusJohansen/markusjohansen
```

Then install any plugin below (or browse interactively with `/plugin`):

```sh
claude plugin install <plugin>@markusjohansen
```

## Plugins

| Plugin | Description |
|--------|-------------|
| [`configure-claude`](./configure-claude) | Scaffolds and grows a personal Claude Code config space — skills, subagents, hooks, rules, a global `CLAUDE.md`, and a `bootstrap.sh` that symlinks it all into `~/.claude/`. |

```sh
claude plugin install configure-claude@markusjohansen
```

## Adding a plugin to this marketplace

1. Create a `<plugin-name>/` directory at the repo root.
2. Add `<plugin-name>/.claude-plugin/plugin.json` (manifest) plus the plugin's
   `commands/`, `agents/`, `skills/`, or `hooks/` as needed.
3. Add an entry to `.claude-plugin/marketplace.json` with
   `"source": "./<plugin-name>"`.
4. Commit and push — `claude plugin marketplace update markusjohansen` picks it up.

## License

[MIT](./LICENSE) © Markus Johansen
