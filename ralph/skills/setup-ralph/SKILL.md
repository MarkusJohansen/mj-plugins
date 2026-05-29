---
name: init-ralph
description: Scaffold the file structure for a Ralph Wiggum loop — PROMPT.md, AGENT.md, fix_plan.md, specs/, and a supervised loop runner. Use when the user says "set up a ralph loop", "init ralph", "/init-ralph", or wants to bootstrap a project for unattended agent iteration. Greenfield-only — refuse to scaffold on top of a populated repo without explicit confirmation.
---

# init-ralph

Bootstrap the scaffolding a Ralph Wiggum loop needs to operate. Ralph is an unattended-agent workflow: the agent reads the same `PROMPT.md` each iteration, picks the single most important item from `fix_plan.md`, implements it, validates against tests, updates the plan, and commits. Memory lives in the repo — not in chat.

This skill **creates files only**. It does not run the loop.

## Preconditions

- The current directory is a git repo (or will be — offer `git init` if not).
- The directory is **greenfield or near-greenfield**. If `src/`, `package.json`, `pyproject.toml`, etc. already exist with substantial content, stop and confirm with the user before scaffolding — Ralph is not designed for established codebases.
- None of the target files (`PROMPT.md`, `AGENT.md`, `fix_plan.md`, `specs/`, `ralph.sh`) already exist. If any do, list them and ask whether to overwrite, skip, or abort.

## What gets created

```
PROMPT.md       # The loop prompt — read verbatim each iteration
AGENT.md        # How to build/test/run/debug this repo
fix_plan.md     # Prioritised checklist of next work
specs/          # One spec file per feature/module (starts with README)
  README.md
ralph.sh        # Supervised loop runner (pauses between iterations)
```

Use the templates in this skill's folder (`templates/`) as the starting content. Copy them into the project, then customise the placeholders with the user.

## Steps

1. **Confirm scope.** Ask the user, in one short message:
   - What is this project? (one sentence)
   - What's the success condition for the loop? (e.g. "all specs implemented and tests pass")
   - Which agent CLI runs the loop? (default: `claude`)
2. **Check the directory.** If non-empty in a way that suggests an existing codebase, surface that and pause.
3. **Copy templates** from this skill's `templates/` folder into the project root using `cp` (not Write — copying byte-for-byte avoids the transcription bugs that have happened before, e.g. shebangs and comment prefixes getting eaten):

   ```bash
   SKILL_DIR="$HOME/.claude/skills/init-ralph/templates"
   mkdir -p specs
   cp "$SKILL_DIR/PROMPT.md"        ./PROMPT.md
   cp "$SKILL_DIR/AGENT.md"         ./AGENT.md
   cp "$SKILL_DIR/fix_plan.md"      ./fix_plan.md
   cp "$SKILL_DIR/specs__README.md" ./specs/README.md
   cp "$SKILL_DIR/ralph.sh"         ./ralph.sh
   ```

   Then substitute placeholders with `sed -i ''` across all five files in one pass — do NOT hand-edit, and do NOT use Write to recreate any file:

   ```bash
   PROJECT_NAME="..."        # directory basename or user-provided
   SUCCESS_CONDITION="..."   # from step 1
   AGENT_CMD="claude"        # from step 1, default claude
   for f in PROMPT.md AGENT.md fix_plan.md specs/README.md ralph.sh; do
     sed -i '' \
       -e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
       -e "s|__SUCCESS_CONDITION__|$SUCCESS_CONDITION|g" \
       -e "s|__AGENT_CMD__|$AGENT_CMD|g" \
       "$f"
   done
   ```

   After substitution, verify no placeholder survived: `grep -l '__PROJECT_NAME__\|__SUCCESS_CONDITION__\|__AGENT_CMD__' PROMPT.md AGENT.md fix_plan.md specs/README.md ralph.sh` should print nothing.
4. **`chmod +x ralph.sh`** so it's runnable.
5. **Report what was created** with a one-line summary per file and the next steps:
   - "Have a long requirements conversation with the agent, then ask it to write `specs/` one file per feature."
   - "Once specs exist, populate `fix_plan.md`."
   - "Run `./ralph.sh` to start a supervised loop. Graduate to `while :; do cat PROMPT.md | __AGENT_CMD__ -p --permission-mode acceptEdits; done` only once the setup is trusted. The `-p` (print/headless) flag is what makes each iteration exit on its own — without it the CLI drops into an interactive REPL and the loop hangs."

## Rules

- **Don't write code or specs.** Specs come from a conversation between the user and the loop agent — not from this skill. Templates ship empty/skeletal on purpose.
- **Don't fill `fix_plan.md` with guesses.** Leave the structure and one example item; the user (or first loop) populates it.
- **Don't run the loop.** This skill scaffolds; the user starts the loop themselves.
- **Refuse on populated repos** unless the user explicitly overrides. Ralph on a brownfield codebase is a footgun.
- **No placeholder implementations.** The `PROMPT.md` template includes the standard anti-placeholder clause from the Ralph technique — don't soften it.

## After scaffolding

Suggest the user:
1. Open a fresh agent session in the project.
2. Have a requirements conversation — describe the project, constraints, non-goals.
3. Ask the agent to write `specs/<feature>.md` files, one per feature, each with Goal / Requirements / Non-goals / Acceptance tests.
4. Ask the agent to seed `fix_plan.md` from the specs.
5. Then start `./ralph.sh`.
