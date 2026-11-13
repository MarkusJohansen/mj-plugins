# worktree

Add, use, and clean up plain `git worktree` checkouts from Claude Code. Three
skills cover the lifecycle, so "make me a worktree, build X in it, then clean
up" is three named commands instead of remembered flags.

## Skills

| Skill                       | What it does                                                 |
|-----------------------------|--------------------------------------------------------------|
| `/worktree:add-worktree`    | Creates a sibling worktree via `git worktree add`.           |
| `/worktree:use-worktree`    | Resolves a worktree and runs a command or task inside it.    |
| `/worktree:remove-worktree` | Removes a worktree once its work is safe, and prunes stale entries. |

## Flow

```
add-worktree -> use-worktree -> remove-worktree
   (create)       (work in)       (clean up)
```

## Layout

Worktrees live next to the main checkout, never inside it:

```
~/code/
  shop/                      # main checkout
  shop--PROJ-42-checkout/    # worktree for branch PROJ-42-checkout
```

A worktree nested inside the checkout (`repo/.worktrees/x`) gets picked up by the
parent's file watchers, search tools and test discovery.

## Depends on

- `git` 2.17 or newer (for `git worktree remove`).

## Install

```sh
claude plugin marketplace add MarkusJohansen/mj-plugins
claude plugin install worktree@mj-plugins
```

## License

MIT
