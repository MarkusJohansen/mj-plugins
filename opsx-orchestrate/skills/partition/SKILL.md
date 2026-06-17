---
name: partition
description: Map a set of OpenSpec change items to non-overlapping scopes before any parallel work starts, and STOP if they can't be cleanly split. Use when the user says "partition these items", "/opsx-orchestrate:partition", "can these change IDs be worked in parallel", "check for overlap before fan-out", or right before /opsx-orchestrate:dispatch. Reads the OpenSpec changes on disk (deltas + tasks) and writes a per-item scope manifest, or surfaces the conflicting files/sections instead of guessing a split.
---

# partition

The pre-flight gate for parallel OpenSpec work. Given several change **items**
(by default one `openspec/changes/<id>/` per item), work out exactly what each
one touches, prove the items don't overlap, and write a **scope manifest** that
`/opsx-orchestrate:dispatch` consumes. If two items can't be cleanly separated,
**stop and surface the conflict** — never invent a split.

## Steps

1. **Resolve inputs.** Take the item IDs from the user. If none are given, list
   the active changes under `openspec/changes/` (ignore `archive/`) and confirm
   which to partition. Capture the base ref (default: the current branch).
2. **Compute each item's touch-set from the artifacts on disk — not from the ID:**
   - **Spec sections:** the capabilities/requirements the item changes, from its
     delta specs (`openspec/changes/<id>/specs/<cap>/spec.md` — the
     `ADDED`/`MODIFIED`/`REMOVED` blocks).
   - **Code files:** the paths the item will touch, inferred from its `tasks.md`,
     any paths named in the proposal/deltas, and a quick scan. Record concrete
     paths where known, narrow globs otherwise.
3. **Detect overlap.** Two items overlap if they share a code file **or** the
   same spec section (same capability + requirement). Build the pairwise set.
4. **Gate:**
   - **Clean** → write the manifest (below) and report the partition as a table
     (item → files → spec sections).
   - **Overlap** → **STOP.** Report exactly which items collide on which files /
     sections, with the evidence. Do **not** propose or apply a split. Offer
     options (sequence the colliding items, merge them, or re-slice) and hand
     back to the user.
5. **Be conservative.** When a file set is uncertain, flag it low-confidence and
   treat ambiguous sharing as overlap. A false stop is cheap; a wrong split
   corrupts sibling PRs.

## Manifest

Write `.opsx-orchestrate/partition.json` at the repo root (create the dir):

```json
{
  "base": "<branch-or-sha the items were scoped against>",
  "generatedFrom": "openspec/changes",
  "items": [
    {
      "id": "<change-id>",
      "slug": "<short-kebab-slug>",
      "specSections": ["<capability>/<requirement>"],
      "files": ["src/foo/**", "path/to/exact.ts"],
      "applyArg": "<id>",
      "confidence": "high|low",
      "notes": "<anything dispatch or a bleed-check should know>"
    }
  ],
  "overlaps": []
}
```

`overlaps` is empty only when the partition is clean. If it isn't, still write
the file with the collisions listed — `dispatch` reads it and must refuse to run.

## Rules

- **Never guess a split.** Overlap → stop and surface, with the conflicting paths.
- **Read the artifacts.** Scope from the deltas/tasks/code, not the ID name.
- **The manifest is the contract.** `dispatch` and any scope/bleed review read it;
  keep `files` accurate and as tight as the evidence allows.
- **One item = one eventual PR.** Only model an item finer than a whole change
  when the apply tool can scope below the change level.
