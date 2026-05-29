---
name: checklist
description: Walk a quality checklist over recent code changes and report findings. Use when the user says "run the checklist", "QA my changes", "check this before I commit/PR", or after Claude finishes a non-trivial edit and wants to self-verify. Pure verification — does not modify code unless the user explicitly asks for a follow-up fix pass.
---

# checklist

Run a structured quality pass over the current set of code changes. Walk each item, report findings, and surface anything that needs attention before commit/PR.

## Scope

Limit checks to:

1. Files modified on the current branch: `git diff --name-only main...HEAD`
2. Uncommitted work: `git status --short`

Do not audit unchanged code. If the diff is empty, say so and stop.

## How to use

For each item below, decide one of:

- ✅ **Pass** — verified, nothing to flag.
- ⚠ **Flag** — concrete concern. Include the file/line and a one-line suggestion.
- ⏭ **Skip** — not applicable to this change. Include a brief reason.

Items are independent; order doesn't matter. Don't fabricate a pass — if you didn't actually verify it, mark it ⏭ with "not verified" rather than ✅.

## Checklist

### Improvement check (refactors only)

If the diff is a refactor, restructure, rename, or cleanup (not a feature, fix, or addition), walk `improvement-check.md` in this skill folder. It enforces a comparative verdict (✅ Improvement / ⚖ Mixed / ❌ Not an improvement / ❓ Can't tell) so a refactor only survives if it's genuinely better than what it replaced. If the verdict isn't ✅, lead the final report with it.

### Correctness
- [ ] Change matches the stated intent (re-read the user's ask or the PR description)
- [ ] Edge cases handled: empty/null inputs, error paths, boundary values
- [ ] No obvious off-by-one, wrong operator, or inverted condition
- [ ] Manually or test-verified to actually work — not just "looks right"

### Tests
- [ ] New behavior is covered by a test (or there's a deliberate reason it isn't)
- [ ] Each test could plausibly fail on a future regression — not re-asserting framework behaviour (Pydantic field defaults, ORM CRUD, JSON round-trip) where no domain logic of ours is exercised. If the field/function has no validators, no computed properties, and no consumers, a test of "can I set it / does it round-trip" is testing the library, not the change
- [ ] Existing test suite still passes locally
- [ ] Tests are deterministic — no reliance on wall-clock time, network, ordering, or random seeds without control
- [ ] Test names describe the behavior under test, not the implementation (`returns 404 when user is missing`, not `test_user_func_1`)
- [ ] One behavior per test — failures point at a single cause
- [ ] Pure logic is separated from side effects so it can be tested without mocks of everything
- [ ] No `.skip`, `xit`, commented-out asserts, or `expect(true).toBe(true)` left behind

### Code hygiene
- [ ] Names explain themselves — variables, functions, classes, files read as intent, not abbreviations or `tmp2`
- [ ] No unused imports, variables, or functions introduced
- [ ] No `console.log`, `print`, `dbg!`, or other debug residue
- [ ] No commented-out code blocks
- [ ] No secrets, tokens, or credentials in the diff
- [ ] Existing file/module conventions followed (naming, structure, style) — formatting feels predictable to a reader

### Simplicity
- [ ] Smallest viable change — no speculative abstractions or "while I'm here" cleanup
- [ ] Boring code over clever code — prefer the obvious solution unless there's a real reason to be subtle
- [ ] Clarity over optimization — no micro-optimizations without a measured perf need
- [ ] No backwards-compat shims, feature flags, or rename-aliases for hypothetical callers
- [ ] Comments only where the WHY is non-obvious (not narrating the WHAT)
- [ ] No half-finished code paths or `TODO` without owner/ticket

### Error handling
- [ ] No silently swallowed errors (`catch {}`, `except: pass`, ignored `Result`/`Promise`)
- [ ] Errors include enough context to debug from the log alone
- [ ] Failure paths are deliberate — chosen, not accidental fall-through
- [ ] Side effects either succeed fully or roll back; no half-applied state on error

### Surface area
- [ ] Public API / exported signature changes are intentional
- [ ] Breaking changes called out (in commit message, PR body, or follow-up note)
- [ ] No accidental deletions, renames, or permission/mode changes in the diff
- [ ] No unintended changes to lockfiles, generated files, or config

### Build & static checks
Before walking these items, **route to the right workspace**. In a multi-package repo a single change may touch several workspaces, each with its own tooling. Don't run a check from the repo root if a per-workspace command exists.

1. From the diff (`git diff --name-only main...HEAD` + `git status --short`), bucket changed files by their nearest workspace root — the closest ancestor directory holding a `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or equivalent manifest.
2. For each affected workspace, pick the check command that workspace actually defines (e.g. a `check`/`verify`/`ci` script in `package.json`, a tool entry in `pyproject.toml`, `cargo test`, `go test ./...`). Prefer a single composite script if one exists; otherwise run type-check + lint + tests individually.
3. Run only the affected workspaces' checks — don't blanket-run the whole repo unless every workspace is touched.
4. If you can't determine the right command for a workspace, mark its checks ⏭ with "command not identified" rather than guessing.

Then verify:
- [ ] Type checker passes in every affected workspace
- [ ] Linter passes in every affected workspace
- [ ] Test suite passes in every affected workspace
- [ ] Build/compile succeeds where applicable

### Security & safety
- [ ] No string-concatenated SQL, shell commands, or HTML from user input
- [ ] External input validated at the boundary
- [ ] No new dependencies added without a clear reason

### Design principles
Apply these as guidelines, not laws. Flag a violation only when it's actually causing harm in the diff — don't refactor working code to satisfy a principle.

- [ ] **DRY** — no copy-pasted logic that should share a single source of truth. (But: two similar lines is fine; three is a smell; resist abstracting too early.)
- [ ] **YAGNI** — no code added for hypothetical future needs. If it isn't called now, delete it.
- [ ] **KISS** — simplest solution that solves the problem; no clever tricks where plain code would do
- [ ] **SRP (Single Responsibility)** — each function/class has one clear job; if you say "and" describing it, split it
- [ ] **OCP (Open/Closed)** — extending behavior shouldn't require editing unrelated callers
- [ ] **LSP (Liskov Substitution)** — subtypes honor their parent's contract; no surprise exceptions or weakened guarantees
- [ ] **ISP (Interface Segregation)** — callers don't depend on methods they don't use
- [ ] **DIP (Dependency Inversion)** — high-level modules depend on abstractions, not concrete details (e.g. inject the client, don't `new` it inside)
- [ ] **Law of Demeter** — avoid long `a.b.c.d` chains; talk to immediate collaborators only
- [ ] **Composition over inheritance** — prefer wrapping/delegation to deep class hierarchies
- [ ] **Fail fast** — invalid state raises at the boundary, not three layers deep

### Established patterns (GoF and friends)

If the change introduces non-trivial new structure (new classes, abstractions, control-flow shapes), walk `patterns.md` in this skill folder. It lists the Creational / Structural / Behavioral patterns worth naming, plus anti-patterns to flag (god objects, switch-on-type, shotgun surgery, primitive obsession). Only invoke a pattern when it earns its keep — don't shoehorn one in.

## Reporting format

After walking the list, output a concise report grouped by status:

```
✅ Passed
- Correctness: edge cases handled (null path verified at foo.ts:42)
- Tests: new test added at foo.test.ts:88

⚠ Flagged
- Hygiene: leftover console.log at bar.ts:17 — remove before commit
- Build: tsc reports 2 errors in baz.ts — see below

⏭ Skipped
- Security: no user input touched in this change
```

If anything is ⚠, do NOT declare the work done. Either fix the flagged items and re-run the affected sections, or hand them to the user for a decision.

## Extending the checklist

Add new items as bullets under an existing section, or add a new section header. Keep each item:

- A single yes/no check (multi-step concerns belong in their own skill)
- Specific enough to verify mechanically — avoid vague items like "code is good"
- Cheap to evaluate (no item should require >1 min of work)

If a project has its own conventions worth checking, add them to that repo's `CLAUDE.md` rather than this skill — keep this list general.
