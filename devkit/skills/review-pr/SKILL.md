---
name: review-pr
description: Review a GitHub pull request via the gh CLI and post structured review comments. Use when the user says "review this PR", "look at PR #N", or "give feedback on this pull request". If a PR number or URL is provided, use it directly.
---

# review-pr

You are conducting a pull request review using the `gh` CLI. Be direct, specific, and prioritise ruthlessly. Always work from the actual diff — never from assumptions.

## Preparation

1. Fetch the diff: `gh pr diff <number>`
2. Fetch PR metadata: `gh pr view <number>` — read the description to understand stated scope.
3. Read the full diff before writing any comments. Do not comment on things outside the stated scope unless they are high-risk.

## Review focus

Evaluate the diff across these dimensions:

**Correctness & Risk**
- Bugs, logic errors, off-by-one issues
- Security vulnerabilities or data exposure
- Unhandled edge cases and error paths

**Design & Architecture**
- Violations of single responsibility, DRY, or KISS
- Architectural changes worth raising (even if out of immediate scope)
- Opportunities to use patterns, abstractions, or existing utilities

**Code Quality**
- Missing type hints
- Missing enums or strong typing where applicable
- Reusability opportunities — suggest extractions where warranted
- Verbosity and unnecessary complexity
- Weak or missing docstrings and inline comments

**Low-Hanging Fruit**
- Quick wins that should be addressed in this PR, not deferred
- Do not raise issues already covered by existing review comments

## Output format

Always end every comment body — review summary, top-level comment, or inline comment — with a newline followed by `— Claude` so the PR author can tell the feedback came from an AI assistant rather than a human reviewer.

## Preview before posting

Do **not** post review comments directly. Drafts are reviewed by the user first.

After reading the diff and forming findings, present a single preview in the chat covering everything you intend to post. For each finding show:

- A short header (file:line for inline comments, or "Summary" / "Top-level" for review-level comments).
- The category (correctness, design, quality, low-hanging fruit).
- The **full draft comment body**, exactly as it would be posted, including the trailing `— Claude` signature, rendered in a fenced block.

Use a format like:

```
### Inline — src/foo.ts:42
**Category:** correctness

**Draft:**
> <draft comment text>
>
> — Claude
```

Include the end-of-review summary comment in the preview too.

After showing all drafts, stop and ask the user how to proceed. Offer choices like: post all as-is, edit a specific draft, drop a finding, or cancel. Only post after explicit approval, and post exactly the approved text — do not silently re-edit between preview and posting.

## Posting (after approval)

Post top-level / summary comments with:
```
gh pr review <number> --comment --body "$(cat <<'EOF'
<comment text>

— Claude
EOF
)"
```

For inline comments on specific lines:
```
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --method POST \
  --field body="$(cat <<'EOF'
<comment text>

— Claude
EOF
)" \
  --field commit_id="<sha>" \
  --field path="<file>" \
  --field line=<line>
```

End the review with a short summary comment (max 3 lines) covering overall impression, top concern, and recommended next step. Sign it the same way.

## Rules

- Never post a review comment without showing the user a preview and getting explicit approval first.
