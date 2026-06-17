# opsx-orchestrate

An orchestration layer over the `opsx` (OpenSpec) plugin. It turns "apply these
change items in parallel, one PR each" from a hand-written prompt into two
composable skills: a **pre-flight gate** that proves the items don't overlap, and
a **fan-out** that lands each as an isolated PR.

## Skills

| Skill | What it does |
|-------|--------------|
| `/opsx-orchestrate:partition` | Maps OpenSpec change items to non-overlapping scopes, writes a scope manifest, and **stops** (never guesses a split) if they collide. |
| `/opsx-orchestrate:dispatch`  | Fans the items out with the Workflow tool — one worktree, branch, and PR per item, each verified before its PR opens. |

## Flow

```
items ─▶ partition ─(clean)─▶ dispatch ─▶ one worktree + branch + PR per item
             │
         (overlap) ─▶ STOP, surface the conflict
```

`partition` writes `.opsx-orchestrate/partition.json`; `dispatch` consumes it.

## Depends on

- **opsx** (the OpenSpec plugin) for the per-item apply command. `dispatch` calls
  it as `/opsx:apply <id>` by default — confirm the real command in your install
  and adjust the single parameter.
- **git worktrees** + **gh** for the isolated branches and PRs.

## Install

```sh
claude plugin marketplace add MarkusJohansen/mj-plugins
claude plugin install opsx-orchestrate@mj-plugins
```

## License

MIT
