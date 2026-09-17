---
name: write-docs
description: Write or rewrite a repository's top-level documentation set — README.md, ARCHITECTURE.md and CLAUDE.md (optionally an AGENTS.md alias) — in the evidence-bearing, why-first house style. Use when the user says "write the docs", "generate documentation for this repo", "write a README/ARCHITECTURE.md/CLAUDE.md", "document this project", "the docs are stale", or "/write-docs". Investigates the repo first and refuses to write a claim it has not verified.
---

# write-docs

Produce the three documents a repository is read through: **README.md** (the door),
**ARCHITECTURE.md** (how it fits together and why), **CLAUDE.md** (the working
conventions, for people as much as for agents). Optionally an **AGENTS.md** that is the
same content under the other name.

The quality bar is not length or coverage. It is that **every sentence is either checkable
or labelled as a judgement call** — every command was run, every number traces to a
measurement, every rule names the failure it prevents, and everything deliberately absent
says why. Documentation written from imagination is worse than none: it makes a working
repository look broken and a broken one look fine.

Read [structure.md](structure.md) before writing: [Literal
shapes](structure.md#literal-shapes) is the markup to copy — the headerless Contents
table, the centred header block, the box-drawing diagram set, the why-column table —
and the three sections after it are the per-document section skeletons.

## Steps

1. **Establish the facts before writing a word.** Nothing in these documents may be
   inferred from a filename. Gather:
   - **Entry points that actually run** — from `pyproject.toml` `[project.scripts]`,
     `package.json` scripts, `Makefile`, `justfile`, shell scripts at the root. Run the
     cheap ones (`--help`, the type check, the test command) and report what happened.
   - **The shape** — processes, services, data stores, what is one file on disk and what
     is a daemon. Draw it only once you can name each box.
   - **The flow** — trace the primary request/job from entry to output, collecting
     `file.py:line` pointers as you go.
   - **Configuration** — where tuneable values live, and whether that is enforced.
   - **Invariants** — the properties that must hold. Hunt specifically for the ones whose
     violation *fails silently*; those are the rules worth writing down. Tests, asserts
     and self-checks are the evidence: name which one guards each.
   - **Measurements** — benchmark output, eval results, findings files, commit messages
     with numbers. Note where each number came from and on what input.
   - **Absences** — what a reader would expect to find and will not, and why. Git history
     and deleted-code commits are the source here.
2. **Confirm scope.** Ask (AskUserQuestion) which of the three to write, whether an
   `AGENTS.md` alias is wanted, and — if a parent directory already has a `CLAUDE.md` —
   whether this repo's should override or extend it. Default: all three, `AGENTS.md` as a
   symlink, and a **"This is not the `<parent>` repo"** subsection when a parent
   `CLAUDE.md` exists.
3. **Write ARCHITECTURE.md first**, even if the user only asked for a README. It is the
   document that forces the investigation to be complete; the other two are summaries of
   what it establishes. If gaps appear here, go back to step 1 rather than writing around
   them.
4. **Then README.md.** It answers, in this order: what this is, why it exists at all
   (the constraint that made it necessary), how the primary flow works, where the project
   actually stands, how to run it, and how to check it.
5. **Then CLAUDE.md**, derived from the invariants found in step 1 — not from generic
   good practice. A rule that would apply to any repository does not belong in this one's
   CLAUDE.md. Close it with a mechanically checkable "Before you say it is done" list.
6. **Alias if asked.** `ln -s CLAUDE.md AGENTS.md` — a symlink cannot drift. Use a real
   copy only if the user names a tool that will not follow one, and then say that the two
   files now have to be edited together.
7. **Verify, then report.** Run the checks in [structure.md](structure.md#verification).
   Report what you could not verify as an explicit list — the unverified claims are the
   most useful part of the handover.

## Voice

These are the rules that separate this house style from generated documentation.

- **Why, not what.** A section that lists contents is noise; a section that explains why
  the thing exists earns its place. "`store.py` — the one writer; the lock is a module
  constant, not a setting" beats "`store.py` — storage helpers".
- **Name the silent failure.** Most rules exist because breaking them produces no error.
  Say so: *"A cache reused across schema versions returns stale rows — which surfaces
  as an inexplicable test failure three files away, not as an error."* A rule without its
  failure mode reads as taste and gets edited away.
- **Every number carries its provenance.** Where it was measured, on what input, and how
  much of a difference is noise. If a number is not measured, write that it is unmeasured
  rather than estimating one. `"p99 of 240 ms over 4 000 requests on the fixture
  corpus; run-to-run spread is 30 ms, so smaller differences are not results"` is a claim.
  `"fast"` is not.
- **Record the negatives.** What was tried and failed, and what was measured and deleted,
  is the most valuable content in the set. Give constraints their own section and open it
  by saying they are stated because they are real, not because they are about to be fixed.
- **No unfalsifiable adjectives.** Strike *robust, powerful, seamless, blazing-fast,
  production-grade, comprehensive, elegant*. If a property is real it has a measurement or
  a mechanism; write that instead.
- **Tables for parallel items, one ASCII diagram for the flow.** Three or more things
  with the same shape are a table with a "why it exists" column. The primary flow is one
  monospace diagram — it survives a diff, a dark theme and a terminal, which is more
  than a rendered image or a remote badge service manages.
- **A Contents table glosses each row.** `| [Section](#anchor) | what the reader gets |` —
  a bare list of links is a table of contents the reader skips.
- **Pointers, not paraphrase.** ARCHITECTURE cites `module.py:line`. README links to
  ARCHITECTURE rather than restating it. Requirements live in one place and are pointed
  at; recopying invites drift.
- **Plain, present, short.** Second person for instructions. State the constraint, then
  the consequence. Bold the load-bearing clause, not the whole sentence.

## Rules

- **Never write a claim you have not verified.** No invented commands, no guessed ports,
  no numbers from nowhere. Where a fact is unavailable, write the gap explicitly
  (`<!-- TODO: unmeasured -->`) and list it in the handover rather than filling it in.
- **Never link or quote anything gitignored.** Read `.gitignore` first. A fresh clone has
  none of it, and a document that cites generated output has no record behind it. Cite the
  tracked file that holds the number instead.
- **Match the repository, not this skill's examples.** Every example here is a stand-in.
  Carry over the *form* — why-first, evidence-bearing, failure-naming — never the subject
  matter, and never a number.
- **Don't inflate a small repo.** A twelve-file project with no invariants gets a README
  and a short CLAUDE.md; say that ARCHITECTURE.md would be three paragraphs of
  restatement and skip it rather than padding one.
- **Rewriting, not replacing.** When a document already exists, preserve the facts in it
  that you cannot re-derive (history, rationale, attributions) and say which ones you
  carried over unverified.
- **Ask, don't invent, for intent.** Why the project exists, what is deliberately absent,
  and what the constraints are, are things only the author knows. Ask one round of
  questions rather than writing a plausible answer.
