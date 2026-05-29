---
name: add-agent
description: Interview the user, then author a new Claude Code subagent into their personal config repo (agents/<name>.md). Use when the user says "add an agent", "create a subagent", "build me an agent for X", "/add-agent", or describes a delegated persona that needs isolated context or parallelism. Asks targeted questions first so the agent's description, tools, and model are right.
---

# add-agent

Author a new subagent into the user's config repo (default `~/claude-config`).
Subagents are **personas you delegate to** — they run in isolated context, which
is the point: heavy multi-file reads or parallel fan-out that would otherwise
pollute the main session.

## Skill vs agent — check first

If the work is a workflow the main session could just run with its own tools,
it should be a **skill** (`/add-skill`), not an agent — cheaper, visible,
course-correctable. Only build an agent when **isolated context or parallelism**
is the actual reason. If in doubt, say so and recommend a skill.

## Locate the config repo

Resolve in order: `$CLAUDE_CONFIG_REPO`, then `~/claude-config`, then ask. If no
`agents/` dir exists, suggest `/scaffold-config` first.

## Interview (gather before writing)

Use **AskUserQuestion** for choices, plain questions for free text. Get:

1. **Role / purpose** — what this persona is for, in one sentence. Confirm
   isolation or parallelism is the reason (vs. a skill).
2. **Name** — a noun/role (`code-reviewer`, `solution-architect`,
   `code-archaeologist`). Matches `[a-z0-9-]+`, not already taken.
3. **When to delegate to it** — the situations that should invoke it. This is the
   `description` and is what triggers delegation — make it specific.
4. **Tools** — which tools it may use. Read-only researchers should get only
   read/search tools (`Read, Grep, Glob, WebSearch`); builders need `Edit, Write,
   Bash`. Default to least privilege.
5. **Model** (optional) — `haiku` for cheap/fast scans, `sonnet`/`opus` for
   heavier reasoning. Omit to inherit.

## Author

Write `agents/<name>.md`:

```markdown
---
name: <name>
description: <role>. Use when <situations to delegate>. <key qualifiers>.
tools: Read, Grep, Glob          # least privilege; omit to inherit all
model: sonnet                    # optional
---

# <name>

<system prompt: who this agent is, how it works, what it returns to the caller,
and what it must not do>
```

Keep the body focused: define the persona, its method, its output format, and
its boundaries.

## Finish

1. Validate: `bash <repo>/bootstrap.sh validate`.
2. Run `./bootstrap.sh` (agents symlink into `~/.claude/agents/`); a new session
   picks it up.
3. Offer to commit.

## Rules

- **Recommend a skill when an agent isn't warranted.** Don't build an agent just
  because the user asked for one if a skill fits better — explain the tradeoff.
- **Least privilege tools.** Don't grant `Bash`/`Write` to a read-only researcher.
- **Noun-named.** Agents are roles.
- **No invented scope.** Build what the user described; flag gaps.
