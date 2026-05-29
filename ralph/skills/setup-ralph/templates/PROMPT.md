# Ralph loop prompt — __PROJECT_NAME__

You are working in a Ralph Wiggum loop. You will be invoked repeatedly with this same prompt. Each invocation, do **one thing** and stop.

## Success condition

__SUCCESS_CONDITION__

## Your job each iteration

1. **Read `AGENT.md`** for build/test/run commands and rules.
2. **Read `fix_plan.md`** and pick the **single most important** unchecked item. Only one.
3. **Before changing code, search the codebase** for the relevant area using parallel subagents. Do not assume a feature is missing because one search came up empty. Think hard.
4. **Implement that one item fully.** No placeholders. No stubs. No `TODO: implement later`. If the specs require functionality, add it.
5. **Run the focused tests** for the unit you changed (see `AGENT.md`). If unrelated tests fail, fix them — they are part of this increment.
6. **Update `fix_plan.md`**: tick the item, add any follow-ups you discovered.
7. **Update `AGENT.md`** *only* if you learned a reusable command or rule. Never use it as a status log.
8. **Commit** the change with a clear message describing what shipped.

## Rules

- One item per loop. **Only one.**
- DO NOT IMPLEMENT PLACEHOLDER OR SIMPLE IMPLEMENTATIONS. WE WANT FULL IMPLEMENTATIONS.
- Use up to several parallel subagents for searching and reading. Use only **one** subagent for building and testing.
- Specs in `specs/` define the target. If a spec is ambiguous, surface the ambiguity in `fix_plan.md` rather than guessing.
- Keep planning and building separate. If `fix_plan.md` is stale, your one task this loop is to regenerate it by comparing source against specs — do not also code.
- If the success condition is met, write a single line to `fix_plan.md` saying so and stop.
