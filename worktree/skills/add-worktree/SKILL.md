---
name: add-worktree
description: Create a new git worktree as a sibling of the repo checkout. Use when the user says "add a worktree", "spin up a worktree", "new worktree for <branch>", "/worktree:add-worktree", or wants an isolated branch checkout to work in without disturbing the current one. Creates it with git worktree add.
---

# Add a git worktree

## What you need from the user

- **Branch name.** Follow the repo's branch convention (e.g. `EE-416-short-description`).
- **Base ref** (optional). Defaults to the current HEAD.

If the branch isn't given, name it after the task in the repo's own convention (look at
`git branch -a`) and say which name you chose. Ask only when the convention needs something you
don't have, such as a ticket number.

## Where it goes

Always a **sibling of the main checkout**, named `<repo>--<branch>` with `/` in the
branch replaced by `-`. Never nest it inside the checkout: the parent's watchers,
search and test discovery would pick it up.

Resolve the main checkout from the shared git dir, so running this from inside
another worktree still lands the new one next to the main repo:

```sh
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
REPO=$(basename "$MAIN")
WT_PATH="$(dirname "$MAIN")/$REPO--${BRANCH//\//-}"
```

## Create it

Keep it all in one Bash call so the variables survive.

```sh
git fetch --quiet origin                       # drop if offline
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git worktree add "$WT_PATH" "$BRANCH"        # existing local branch
elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git worktree add --track -b "$BRANCH" "$WT_PATH" "origin/$BRANCH"
else
  git worktree add -b "$BRANCH" "$WT_PATH" "${BASE:-HEAD}"
fi
```

- `git worktree add` refuses a branch already checked out elsewhere. Report which
  worktree holds it (`git worktree list`) instead of forcing it.
- If `$WT_PATH` already exists, stop and ask. Don't overwrite.

## After creating

The new checkout has no virtualenvs, `node_modules` or other untracked setup. If
the repo needs setup to run (e.g. `uv sync`, `pnpm install`), say so, or run it if
the user asked for work in the worktree.

Report the path and branch. If the user already said what to do in it, continue
with `/worktree:use-worktree`. Otherwise stop: the worktree is ready.
