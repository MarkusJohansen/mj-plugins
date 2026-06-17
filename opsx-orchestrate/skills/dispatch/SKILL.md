---
name: dispatch
description: Fan out OpenSpec change items in parallel — one isolated git worktree, one branch, and one PR per item — applying only each item's scope. Use when the user says "work these items in parallel", "/opsx-orchestrate:dispatch", "fan these change IDs out across worktrees", "one PR per item", or hands over several OpenSpec items to apply at once. Runs the partition gate first and STOPS on un-splittable overlap; verifies each item before opening its PR; never shares branches, commits, or PRs between items.
---

# dispatch

Take several OpenSpec change **items** and land each as an independent PR, in
parallel, without their work bleeding into one another. Each item gets its own
worktree, its own branch off a single captured base, its own apply + verify, and
its own PR. This skill orchestrates with the **Workflow tool** — invoking it is
your authorization to use Workflow for the fan-out.

It reuses rather than re-implements: `/opsx-orchestrate:partition` (the gate),
the apply command (default `/opsx:apply` — confirm the real name), and `gh`
for the PRs.

## Steps

1. **Inputs & preconditions.** Item IDs (or an existing
   `.opsx-orchestrate/partition.json`); the base branch (default `main`); the
   per-item apply command (default `/opsx:apply <id>` — **parameterize it**, the
   opsx plugin may spell it differently). Require a clean working tree and
   authenticated `gh`. If anything's missing, ask before touching the repo.
2. **Capture the base once.** `git rev-parse <base-branch>` → `BASE`. Every item
   branches off this exact SHA, so the items stay independent and the PRs stay
   clean even if the base moves while they run.
3. **Run the partition gate.** Invoke `/opsx-orchestrate:partition` (or load its
   manifest). If `overlaps` is non-empty, **STOP** — surface the conflict and
   create nothing. This is the "don't guess a split" rule; honor it.
4. **Fan out with the Workflow tool**, one agent per item, worktree-isolated,
   concurrently. Recommended script:

   ```js
   export const meta = {
     name: 'opsx-dispatch',
     description: 'Apply OpenSpec items in parallel — one worktree + PR each',
     phases: [{ title: 'Apply' }],
   }
   const RESULT = { type: 'object', required: ['id', 'status'], properties: {
     id: {type:'string'}, branch: {type:'string'}, prUrl: {type:'string'},
     status: {enum: ['opened','blocked','skipped']}, notes: {type:'string'} } }
   const items = args.items   // from the manifest: {id, slug, files, applyArg}
   const out = await parallel(items.map(it => () => agent(
     `Create branch ${it.id}-${it.slug} off ${args.base} in an isolated worktree.\n` +
     `Apply ONLY this item's scope via: ${args.applyCmd.replace('<id>', it.applyArg)}.\n` +
     `Its files are limited to ${JSON.stringify(it.files)} — if applying would ` +
     `touch anything outside that set, STOP and return status "blocked".\n` +
     `Then build and run tests. Green → commit, push, open ONE PR targeting ` +
     `${args.baseBranch}. Red → return "blocked" with the failure; do NOT open a PR.`,
     { label: `dispatch:${it.id}`, phase: 'Apply', isolation: 'worktree', schema: RESULT }
   )))
   return out.filter(Boolean)
   ```

   Pass `base`, `baseBranch`, `applyCmd`, and `items` (from the manifest) as the
   Workflow `args`.
5. **Roll up.** Report a table: item → branch → PR link, or **blocked** (with the
   reason) / **skipped**. Make failures impossible to miss.
6. **Stop there.** No merging, no worktree cleanup — leave the PRs for review.
   Point the user at `wt.sh rm` / a land step for cleanup once the PRs merge.

## Constraints (non-negotiable)

- **No shared branches, commits, or PRs** between items — each runs in its own
  worktree and never writes outside its scope.
- **Overlap → stop**, never guess a split (enforced by step 3).
- **Verify before PR.** An item whose build/tests fail is reported blocked; its
  PR is not opened.
- **Apply is the integration seam.** If the apply command is a slash-skill that
  can't run inside a Workflow agent, either inline its steps into the agent
  prompt or fall back to one `Agent` per item — keep every other rule the same.
