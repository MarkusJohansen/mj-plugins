---
name: plan-first
description: Write a structured implementation plan before starting a non-trivial change. Use when the user says "plan this out", "draft a plan for X", or before code on work that warrants thinking through first. Produces a consistent format you can review, redirect, or paste into a ticket.
---

# plan

Produce a written plan before code. The plan reduces mid-implementation surprises by surfacing approach, risks, and test strategy up front. It should be reviewable in under two minutes.

## When to use

- The change touches more than one or two files.
- The approach isn't obvious from the ticket / request.
- The work has rollback risk, migration steps, or external dependencies.
- The user explicitly asked for a plan.

Skip the plan for one-line fixes, typo edits, or obviously trivial work.

## Preparation

1. **Read the request in full.** Quote it back to yourself if there's any chance of misreading.
2. **Read the touched code.** Plan against the actual paths, not assumptions.
3. **Look for prior art.** Has this problem, or one like it, been solved before, in this codebase or elsewhere? Is there a conventional architecture or a known design pattern for it? Asked after the code exists, a "yes" means a rewrite.
4. **List the unknowns** — questions you'd want answered before committing to an approach.

## Format

```
## Problem
<One paragraph. What needs solving and why now. Reference the ticket or request.>

## Approach
<2–4 sentences describing the strategy. Not implementation — strategy.>

## Prior art
<Where this, or something like it, is already solved, and the conventional architecture or pattern the approach follows. One or two lines. "Looked, found none" is an answer.>

## Implementation steps
1. <Ordered, atomic. Each step should be reviewable as a discrete commit.>
2. <...>

## PR split (only when the work is more than one PR)
1. <PR title: which steps, ~lines, reviewable alone because...>
2. <...>

## Risks / unknowns
- <What could go wrong. What you don't know yet. Things to validate before step N.>

## Test plan
- <How the change will be verified. Existing tests, new tests, manual checks.>

## Done when
- <The commands that must pass before this is finished: the tests above, `verify`, a spec check. Checkable by a script, not by opinion.>

## Out of scope
- <Adjacent things you'll explicitly not address in this work.>

## Rollback
<If non-trivial: how to revert if this goes sideways. Skip for low-risk changes.>
```

## Rules

- **No code in the plan.** Pseudo-code is fine sparingly; real implementations belong in the edit.
- **Implementation steps are ordered and atomic.** "Update X to do Y" not "refactor everything".
- **List unknowns as questions.** "Does the API rate-limit by IP or by token?" beats "TBD".
- **Decide the PR split here, not after coding.** Past ~400 changed lines, or when the work mixes a refactor with a behaviour change, group the steps into PRs: a preparatory refactor with no behaviour change first, then vertical slices that each work end to end (feature flag if a slice isn't ready to show). Never split by layer (models, then routes, then UI); no such PR can be reviewed alone.
- **Don't pad.** If a section has nothing real to say, omit it. A short plan is a good plan.
- **Pause after the plan.** Once written, wait for the user's go-ahead before implementing. Don't slide into code on the same turn.

## After approval

When the user accepts the plan, work through the implementation steps in order, to the end, without checking in between steps. Finish by running every command under *Done when* and showing the result; the work is not done until they pass. If you discover a step needs to change mid-flight, surface that explicitly ("step 3 turns out to need…") rather than silently deviating.
