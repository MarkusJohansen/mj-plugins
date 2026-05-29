---
name: resolve-pr-comments
description: Work through unresolved review comments on a GitHub pull request via the gh CLI — fetch each thread, address it in code or with a reply, and mark it resolved. Use when the user says "resolve PR comments", "address review feedback", "work through the review on PR #N", or "respond to reviewer comments".
---

# resolve-pr-comments

You are working through reviewer feedback on a GitHub PR. Each unresolved thread either becomes a code change, a reply explaining why no change is needed, or a follow-up note — never silently ignored.

## Preparation

1. Identify the PR. If the user supplied a number or URL, use it. Otherwise run `gh pr view --json number,headRefName` from the current branch.
2. Confirm the local branch matches the PR head (`git branch --show-current`). If not, ask before checking it out.
3. Fetch the diff and PR metadata: `gh pr view <number>` and `gh pr diff <number>`.
4. List unresolved review threads — these carry both the comment text and a resolution state that `gh pr review --comment` does not expose. Use the GraphQL API:

   ```sh
   gh api graphql -F number=<number> -F owner=<owner> -F repo=<repo> -f query='
     query($owner:String!,$repo:String!,$number:Int!){
       repository(owner:$owner,name:$repo){
         pullRequest(number:$number){
           reviewThreads(first:100){
             nodes{
               id isResolved isOutdated
               comments(first:20){nodes{author{login} body path line diffHunk url}}
             }
           }
         }
       }
     }'
   ```

   Filter to `isResolved == false`. Outdated threads (`isOutdated == true`) usually mean the line moved or was rewritten — read them but flag separately.

## Working through threads

### Evaluate before acting

A review comment is an opinion that may be wrong. The default failure mode is to apply every suggestion reflexively — don't. Before deciding what to do with a thread, judge the comment on its merits.

For each thread, answer these in order:

1. **What is the reviewer actually claiming?** State it back in one sentence. If you can't, the comment is ambiguous — reply asking for clarification, don't guess.
2. **Is the claim correct?** Read the surrounding code, not just the line. Check the reviewer's reasoning against the actual behavior, the existing conventions in this repo, prior decisions visible in the PR description or commit history, and any tests that exercise the path. Pick one:
   - **Correct** — the reviewer is right; the code should change.
   - **Partially correct** — there's a real concern but the proposed fix is wrong or overreaches; address the underlying concern, not the literal suggestion.
   - **Incorrect** — the reviewer has misread the code, missed context, or is proposing something that conflicts with a deliberate choice. Push back.
   - **Subjective / matter of taste** — neither right nor wrong; a style preference. Default to keeping the existing approach unless the reviewer's preference matches a stronger convention in this repo. Be honest in the reply that it's a taste call.
3. **Is the proposed fix the right one?** Even when the claim is correct, the reviewer's suggested change may not be the best response. You're not obligated to apply their exact wording — apply the *right* fix for the real concern.

Common reasons to push back rather than apply:

- The reviewer missed context that's elsewhere in the diff, an existing file, or the PR description.
- The "fix" would break or conflict with something the reviewer can't see (other callers, a downstream constraint, a test that encodes the current behavior on purpose).
- The suggestion contradicts an established convention in this repo.
- The suggestion is a style preference where the existing code is also fine.
- The suggestion would expand scope beyond what this PR is doing.

If you can't articulate why a comment is correct, you probably haven't checked — go check before applying.

### Pick an action

Once you've evaluated, pick one:

- **Fix in code** — only when you've judged the claim correct (or partially correct) and decided on the right fix. Keep the edit scoped to what the reviewer raised; don't expand into unrelated cleanup. Stage and commit separately so the reviewer can see the response.
- **Push back with a reply** — when the reviewer is wrong, the suggestion conflicts with another constraint, the trade-off was deliberate, or it's a taste call where the existing code is fine. Be specific and cite the reason (existing convention, prior decision, perf measurement, the line they missed). Polite but firm; never dismiss without reasoning. Pushing back is a normal outcome, not a last resort.
- **Defer to a follow-up** — when the comment is valid but out of scope for this PR. Open or link a ticket, then reply with the link. Don't promise "later" without a tracked artifact.

## Preview before posting

Do **not** post replies directly. Drafts are reviewed by the user first.

After evaluating every unresolved thread, present a single preview in the chat covering all of them. For each thread show:

- A short header identifying the thread (file:line, reviewer login, and the first line or so of their comment so the user can locate it).
- The chosen action (`fix in code`, `reply`, `follow-up`, or `code + reply`).
- For threads with a reply: the **full draft reply body**, exactly as it would be posted, including the trailing `— Claude` signature, rendered in a fenced block.
- For threads with a code fix: a one-line summary of what you changed (or plan to change) and the file(s) touched.

Use a format like:

```
### Thread 1 — src/foo.ts:42 (@reviewer)
> reviewer's comment, first line…

**Action:** reply

**Draft:**
> <draft reply text>
>
> — Claude
```

After showing all drafts, stop and ask the user how to proceed. Offer choices like: post all as-is, edit a specific draft, skip a thread, or cancel. Only post replies after explicit approval, and post exactly the approved text — do not silently re-edit between preview and posting.

When the user approves, post each reply with:

```sh
gh api repos/<owner>/<repo>/pulls/<number>/comments \
  --method POST \
  --field body="$(cat <<'EOF'
<reply text>

— Claude
EOF
)" \
  --field in_reply_to=<comment_id>
```

Code fixes can be made before or after the preview, but if made before, mention in the preview that the edit is already on disk (and unstaged/uncommitted) so the user can review the diff alongside the reply drafts.

Do **not** resolve threads yourself. Resolution is the commenter's prerogative — they decide whether the response or fix addressed their concern. Your job ends at posting the approved reply (and pushing any code fix); leave the resolve button to them.

## Committing fixes

- One commit per logical fix, or a single grouped commit if all fixes are trivial. Match the repo's existing commit style.
- Reference the reviewer or thread sparingly in commit messages — the PR timeline already links them. Mention it only when the *why* is non-obvious from the diff.
- Push when the user gives the go-ahead. Don't force-push unless asked.

## Rules

- Every unresolved thread must get either a code change, a substantive reply, or a follow-up link — never silently skipped.
- Never post a reply without showing the user a preview and getting explicit approval first.
- Never resolve threads yourself. The commenter resolves them.
- Do not post a summary comment on the PR when finished. The per-thread replies are the record.
- Never rewrite or amend the reviewer's comments. Quote them in replies if needed, but don't paraphrase them as if they were your own.
- If a comment is ambiguous, reply asking for clarification rather than guessing.
- Outdated threads on lines that no longer exist: read them, decide if the concern still applies, and reply accordingly.
