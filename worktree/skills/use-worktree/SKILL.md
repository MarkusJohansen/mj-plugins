---
name: use-worktree
description: Implement or execute a request inside a specified git worktree. Use when the user says "do X in the <branch> worktree", "run this in worktree Y", "use the <name> worktree to ...", "/worktree:use-worktree", or wants work carried out in an isolated worktree without disturbing the current checkout.
---

# Use a git worktree

## Resolve the target

The user names a worktree by branch or folder. List them and match:

```sh
git worktree list --porcelain
```

Each entry has a `worktree <path>` line and a `branch refs/heads/<name>` line. If
nothing matches, or more than one does, show the list and ask. If no worktree exists
for the branch, offer `/worktree:add-worktree`.

## Do the work

- **Edit files** with absolute paths under the worktree path. Check every path
  starts with `$WT_PATH` so nothing lands in the main checkout by mistake.
- **Run commands** from the worktree. Shell `cd` may not persist between calls, so
  prefix each command (`cd "$WT_PATH" && uv run test`) or use
  `git -C "$WT_PATH" ...` for git.
- **Per-checkout setup** (virtualenvs, `node_modules`, build output) is not shared
  with the main checkout. Run the repo's install step in the worktree before
  running its tests.
- **Long or independent work** can go to a subagent: give it `$WT_PATH` and tell it
  to work only under that path.

## Close out

Report what ran and in which worktree, and whether there are uncommitted changes
there (`git -C "$WT_PATH" status --short`). Commit only if the user asked. Leave
the worktree in place; teardown is `/worktree:remove-worktree`.
