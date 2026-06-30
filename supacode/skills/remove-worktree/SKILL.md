---
name: remove-worktree
description: Clean up a Supacode worktree once work in it is done. Use when the user says "remove this worktree", "delete the worktree", "clean up the <branch> worktree", "archive the worktree", "/supacode:remove-worktree", or is finished with an isolated branch checkout in the Supacode agent terminal. Deletes (or archives) it via the supacode CLI.
---

# Remove Supacode worktree

Tear down a worktree through the `supacode` CLI. See the `supacode-cli` skill
for the full command reference.

## Resolve the target

If the user didn't name a worktree, list them and confirm which one — don't
guess:

```sh
supacode worktree list
```

## Check before deleting

Deletion is hard to reverse. Before removing, confirm the branch's work is
committed and merged/pushed if it matters. Surface uncommitted changes to the
user rather than silently destroying them — `supacode worktree delete` removes
the working directory.

If the user only wants it out of the way (not gone), archive instead:

```sh
supacode worktree archive -w "$WT_ID"     # reversible: unarchive later
```

## Delete

```sh
supacode worktree delete -w "$WT_ID"
```

Deleting the worktree leaves the **branch** in place (it just removes the
checkout). Tell the user the branch still exists and how to drop it if they
want — `git branch -d <branch>` — since merged work often wants the branch
around briefly.

ponytail: delete vs archive is the whole decision — default to archive when unsure, it's reversible.
