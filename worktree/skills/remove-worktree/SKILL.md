---
name: remove-worktree
description: Clean up a git worktree once work in it is done. Use when the user says "remove this worktree", "delete the worktree", "clean up the <branch> worktree", "/worktree:remove-worktree", or is finished with an isolated branch checkout. Removes it with git worktree remove and prunes stale entries.
---

# Remove a git worktree

## Resolve the target

If the user didn't name one, list them and confirm which. Don't guess:

```sh
git worktree list
```

Never remove the main checkout (the first entry in the list).

## Check before removing

Removing deletes the working directory. Before it:

```sh
git -C "$WT_PATH" status --short                   # uncommitted or untracked work
git -C "$WT_PATH" log --oneline @{upstream}..HEAD  # unpushed commits (errors if no upstream)
```

If either shows anything, tell the user what would be lost and wait for a go-ahead.
Untracked build output (`.venv`, `node_modules`) is fine to lose; say so rather than
treating it as work.

## Remove

Run it from outside the worktree being removed:

```sh
git -C "$MAIN" worktree remove "$WT_PATH"
git -C "$MAIN" worktree prune
```

`git worktree remove` refuses a dirty worktree. Add `--force` only after the user
confirmed the changes can go.

## After removing

The **branch** stays. Tell the user it still exists and how to drop it:
`git branch -d <branch>` once merged, `-D` to discard it unmerged. Don't delete the
branch unless asked.
