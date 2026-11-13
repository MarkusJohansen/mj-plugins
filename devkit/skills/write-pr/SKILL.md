---
name: write-pr
description: Create or update a GitHub pull request with a consistent title and description format. Use when the user says "write a PR", "open a PR for this", "create a pull request", or asks to update an existing PR's description.
---

# write-pr

You are writing a Pull Request for GitHub. The goal is to make the reviewer's job as easy as possible — they should understand what changed, why, and where to focus their attention before reading a single line of code.

Before submitting, verify:
- [ ] Diff against main has been reviewed in full
- [ ] No unintended files, debug code, or commented-out blocks in the diff
- [ ] Title follows the format and is specific
- [ ] Motivation references the originating issue or ticket
- [ ] Technical overview is grounded in the actual diff, not assumptions
- [ ] Out of scope section is filled in, even if minimal

ALWAYS RESPOND WITH A MARKDOWN CODE BLOCK USING 4 FENCES.

---

## Preparation

Before writing the PR, ground yourself in the actual changes:

1. **Check the diff against main** — run `bash <skill-dir>/pr-context.sh [base]`: branch, commits, diffstat, then each file's diff capped at 120 lines and 2,500 in total (lockfiles, generated and binary files skipped; files past the budget listed with their +/- counts). Read it in full; run `git diff <base>...HEAD -- <file>` only where a cut-off file could change the PR's story. Do not summarize from memory or assumptions.
2. **Identify the scope** — how many files changed, what domains are touched, and whether the changes are cohesive or span multiple concerns.
3. **Note anything surprising** — unintended changes, leftover debug code, files that shouldn't be in this diff, or changes that belong in a separate PR.

Only begin writing the PR after completing this step.

---

## Shape check

A good PR is one a reviewer can fully verify in one sitting. A good description cannot rescue a badly shaped diff, so check the shape before writing, and if it fails, tell the author and propose a split instead of describing it.

- **One purpose.** A refactor (code moves, renames) and a behaviour change in one diff hide which lines change logic. Propose the refactor as its own PR first.
- **Size.** Aim for ~400 changed lines (lockfiles, generated files and fixtures excluded), 800 at most. Reviewers find fewer defects per line past ~200-400 lines or ~60-90 minutes per session (SmartBear/Cisco study of 2,500 reviews). The number is a rule of thumb; the mechanism is attention running out.
- **Reviewable alone.** A PR split by layer (models, then routes, then UI) can't be judged without the others. Split by vertical slice instead: each PR works end to end, with a feature flag if the slice isn't ready to show.
- **Evidence.** Prefer a test that fails without the change, before/after screenshots for UI, or before/after numbers for a performance claim over "tests pass". Put it in Testing Notes.

---

## Title

Format: `[type][Domain] Summarizing title`

**Type options:**
- `feat` — new functionality
- `fix` — bug fix
- `refactor` — structural change with no behavior change
- `perf` — performance improvement
- `test` — test coverage changes
- `chore` — maintenance, dependencies, config, tooling

**Rules:**
- Be specific, not generic ("Add JWT expiry handling to AuthService", not "Fix auth bug")
- Keep it under 72 characters
- Use present tense ("Add", "Fix", "Remove" — not "Added", "Fixed")

---

## Body

### Summary
2–4 sentences. What changed and why, written for someone who hasn't seen the code. Should make sense without reading the diff. Include a table summarising the diff and ensure the counts add up.

### Motivation
Why was this change necessary? Reference the problem it solves — a bug, a performance issue, a design smell, a product requirement. If there's a related Jira ticket, link it here.

### Technical Overview
A structured walkthrough of what changed and where, **derived directly from the diff**. Group by area of concern, not by file. For each change, explain *what* was done and *why* that approach was chosen.

Use this format where helpful:
```
**[Area or component]**
What changed and the reasoning behind it.
```

Keep it precise and scannable. Reviewers should be able to jump to the relevant part of the diff after reading each section.

### Out of Scope
Explicitly list what this PR does *not* address. Prevents reviewers from raising comments about known gaps and signals you've thought about the boundaries of the change.

Format:
- `[Thing not addressed]` — brief reason or follow-up reference

### Testing Notes *(when applicable)*
How was this tested? What should reviewers pay special attention to? Edge cases hard to test automatically?

### Screenshots / recordings *(for UI changes)*
Before / after if relevant.

---

## Submission

Always open PRs as drafts. The author marks them ready for review themselves once they're satisfied.

Create the PR:
```
gh pr create --draft --title "<title>" --body "<body>"
```

Edit an existing PR:
```
gh pr edit <number> --title "<title>" --body "<body>"
```

Do not run `gh pr ready` — leaving the PR in draft is intentional.
