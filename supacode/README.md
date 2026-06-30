# supacode

Work with the [Supacode](https://supacode.dev) agent terminal from Claude Code.
Three skills wrap the `supacode` CLI's worktree lifecycle so "make me a worktree
and build X in it, then clean up" is three named commands instead of remembered
flags.

## Skills

| Skill | What it does |
|-------|--------------|
| `/supacode:add-worktree`    | Creates a worktree via `supacode repo worktree-new` and focuses it. |
| `/supacode:use-worktree`    | Resolves a target worktree, focuses it, and dispatches a command or implementation task there. |
| `/supacode:remove-worktree` | Archives (reversible) or deletes a worktree once its work is done. |

## Flow

```
add-worktree ─▶ use-worktree ─▶ remove-worktree
   (create)        (work in)        (clean up)
```

## Depends on

- The **`supacode` CLI**, available inside every Supacode terminal session.
- The **`supacode-cli`** skill for the full command reference and the
  ID-tracking rules the `use-worktree` skill relies on.

## Install

```sh
claude plugin marketplace add MarkusJohansen/mj-plugins
claude plugin install supacode@mj-plugins
```

## License

MIT
