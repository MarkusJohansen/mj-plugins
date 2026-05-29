---
name: stand-up
description: Generate a stand-up update from recent git activity and Jira ticket changes. Use when the user says "what did I do yesterday", "draft my stand-up", or "summarise my recent work". Combines local git history with Atlassian MCP data.
---

# stand-up

Produce a concise stand-up update for the user. Goal: 30 seconds to read aloud, no fluff, grounded in evidence (commits, PRs, Jira transitions).

## Default scope

- **Time window:** since the last working day (Mon → previous Fri's morning; otherwise yesterday morning to now). If today is Monday, span Friday + weekend.
- **Sources:** git activity across repos the user touched, plus Jira tickets assigned to or transitioned by the user.

Ask once if the scope or repo set is ambiguous; otherwise infer and proceed.

## Gathering

Run these in parallel:

**Git (current repo):**
- `git log --author="$(git config user.email)" --since="<window>" --pretty=format:"%h %s" --all`
- `git log --author="$(git config user.email)" --since="<window>" --pretty=format:"%h %s" --branches` for branches not yet merged
- `gh pr list --author "@me" --state all --search "updated:>=<date>"` for PR activity

**Jira (via Atlassian MCP):**
- `searchJiraIssuesUsingJql` with something like:
  ```
  assignee = currentUser() AND updated >= -1d
  ```
- For each ticket, note transitions and recent comments — that's where "what changed" lives.

If the user works across multiple repos, ask for the list once, then iterate.

## Format

```
**Yesterday**
- <ticket key> — short verb-led summary (PR #N merged / opened)
- <non-ticket work, if any>

**Today**
- <ticket key> — what you'll push on next
- <meetings or blocking items>

**Blockers**
- <one line, or "none">
```

Rules:
- One bullet per ticket. Group commits under their ticket if you can match them (commit message references, branch name).
- Don't list every commit — collapse them into the outcome ("Wired up validation in the pricing engine, opened PR #412").
- Skip the "Today" section if the user only asked for a recap.
- Skip "Blockers" if there genuinely aren't any — don't invent filler.

## Boundaries

- Don't speculate on "Today" if the user hasn't told you what's next. Ask, or pull it from in-progress Jira tickets and label clearly as "in flight".
- Don't include WIP commits on local-only branches unless the user specifically wants them — they're noise.
- Don't post the update anywhere (Slack, etc.) unless explicitly asked.
