---
name: add-worktree
description: Create a new Supacode worktree following Supacode conventions. Use when the user says "add a worktree", "spin up a worktree in Supacode", "new worktree for <branch>", "/supacode:add-worktree", or wants an isolated branch checkout managed by the Supacode agent terminal. Creates the worktree via the supacode CLI and focuses it.
---

# Add Supacode worktree

Create a worktree through the `supacode` CLI so the Supacode app manages and
discovers it. See the `supacode-cli` skill for the full command reference.

## What you need from the user

- **Branch name.** Follow the repo's branch convention (`feature/x`, `fix/y`).
- **Base ref** (optional). Defaults to current HEAD; pass `--base main` to branch off something else.

If the branch isn't given, ask for it — don't invent one.

## Create it

Run from inside the repo (or pass `-r <repo-id>`). Capture the printed worktree ID.

```sh
WT_ID=$(supacode repo worktree-new --branch <branch> --fetch)
supacode worktree focus -w "$WT_ID"
```

- `--fetch` updates remotes first so `--base` resolves against current refs. Drop it if offline.
- `--base <ref>` to branch off something other than HEAD.
- Let Supacode choose the location — it manages worktree discovery. Only pass
  `--location <dir>` / `--name <folder>` if the user wants a specific spot. (For
  manual `git worktree add` outside Supacode, the sibling-of-checkout convention
  applies — but `worktree-new` handles placement itself.)

## After creating

Report the worktree ID and branch. If the user already said what to do in it,
hand off to `/supacode:use-worktree`; otherwise stop — the worktree is ready.

ponytail: thin wrapper over `worktree-new` — no local bookkeeping, Supacode owns worktree state.
