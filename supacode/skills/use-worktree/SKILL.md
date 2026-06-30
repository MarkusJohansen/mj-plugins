---
name: use-worktree
description: Implement or execute a request inside a specified Supacode worktree. Use when the user says "do X in the <branch> worktree", "run this in worktree Y", "use the <name> worktree to ...", "/supacode:use-worktree", or wants work carried out in an isolated Supacode worktree without disturbing the current checkout. Focuses the target worktree and dispatches the work there via the supacode CLI.
---

# Use a Supacode worktree

Run an implementation task or command in a specific worktree. See the
`supacode-cli` skill for the full command reference and the ID-tracking rules
(always capture UUIDs from `tab new` / `surface split`; always pass `-t`/`-s`
for resources you create).

## Resolve the target

The user names a worktree (by branch or label). If ambiguous, list and confirm:

```sh
supacode worktree list
```

Capture its ID into `WT_ID`. Focus it so the user sees what's happening:

```sh
supacode worktree focus -w "$WT_ID"
```

## Dispatch the work

Pick by what the request needs:

- **Run a command / script** in that worktree — open a tab in it and feed the
  command. New tabs print a UUID; the initial surface ID equals the tab ID.

  ```sh
  TAB_ID=$(supacode tab new -w "$WT_ID" -i "<command>")
  ```

  For a configured run-kind script, use `supacode worktree run -w "$WT_ID"`
  (add `-c <script-uuid>` for a specific one; `supacode worktree script list`
  to find it).

- **Implement code changes** — if the worktree's files are accessible from the
  current session, edit them directly under the worktree path, then run
  checks/tests via a tab as above. If it needs its own Claude session, open a
  tab running `claude` in that worktree and hand off the request.

Keep all related commands in **one Bash call** so captured IDs survive.

## Close out

Report what ran and where (worktree + tab). Leave the tab open unless the user
asked to clean up — for full teardown, use `/supacode:remove-worktree`.

ponytail: reuse supacode-cli's mechanics — this skill is just target-resolution + dispatch, not a new command layer.
