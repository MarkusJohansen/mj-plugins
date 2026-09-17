# Document skeletons

The section order for each document, with what each section is for. Drop a section when
the repository genuinely has nothing to put in it — an empty section is worse than a
missing one — but drop it deliberately, not by forgetting.

---

## Literal shapes

Copy these. The prose above says which sections exist; this says what they look like, and
the difference is what makes three documents read as one set.

**Top-level sections are separated by a horizontal rule** — `---` on its own line, with a
blank line either side. Not decoration: it is what stops a long README reading as one
undifferentiated scroll.

### The Contents table

Headerless, two columns, a gloss on every row:

```markdown
## Contents

| | |
| --- | --- |
| [Where the project is right now](#where-the-project-is-right-now) | what is built, what is measured, what is not |
| [Quickstart](#quickstart) | requirements, and five commands to a working result |
| [Every command](#every-command) | the full entry-point table |
```

The empty header row is deliberate. Column titles would make the gloss look like data in a
table *about* sections; with no header it reads as an annotation on the link, which is what
it is. Glosses are lower-case fragments, not sentences — they are labels, not prose.

In ARCHITECTURE the rows are numbered to match the headings (`[1. The shape of the
system](#1-the-shape-of-the-system)`), because numbered sections are what get cited in a
review.

### The README header block

HTML, because markdown cannot centre. Keep it to this:

```html
<h1 align="center">Name</h1>

<p align="center">
  <strong>The single strongest true sentence about what this does,<br>
  broken where it reads best.</strong>
</p>

<!-- Text, not shields.io. Six badge images would be six remote fetches at the top of the
     file, and they rot silently when a service changes. Keep these local. -->
<p align="center">
  <code>go&nbsp;1.23+</code> &nbsp;
  <code>zero&nbsp;deps</code> &nbsp;
  <code>p99&nbsp;240ms</code> &nbsp;
  <code>pre-release</code>
</p>
```

`&nbsp;` inside each `<code>` keeps a fact from wrapping mid-phrase; the bare `&nbsp;`
between them is the gap. The comment stays in the file — it is the reason the next person
does not "improve" the strip into badges.

A screenshot, if there is one, follows the same pattern: `<p align="center">` with an
`<img width="900">` whose `alt` describes what is *in* the image for someone who cannot see
it, then a separate `<p align="center"><em>` caption saying what the reader should notice.
Alt text and caption do different jobs — never the same sentence twice.

### Diagrams

A plain fenced block (no language tag — no highlighter should touch it), box-drawing
characters, and flow top-to-bottom:

```
question
   │
   ▼
parse ──── malformed? ──► reject, with the offending line
   │
   ▼
   ├─► fast path ─────► cached result  ─┐
   │                                    ├─► merge ─► ranked list
   └─► slow path ─────► full scan      ─┘                │
                                                         ▼
                                                      output
```

Use `│ ─ ▼ ├ └ ┌ ┐ ┘ ►` and, for a box, `┌───┐ │ │ └───┘`. Not `-->`, not `|`, not ASCII
art with slashes: the box-drawing set aligns in a monospace column at any width and
survives a diff. Label the *edges* with the condition, not just the boxes with nouns — an
unlabelled arrow is the part a reader has to guess.

One diagram per document section at most, and only where the shape is the point. A diagram
that restates a three-item list is worse than the list.

### Tables

Every table that enumerates parts carries a **why it exists** column, and that column is
the widest one. A table of names and types is a type signature the reader can already get
from the code.

```markdown
| Role | Port | Why it exists |
| --- | --- | --- |
| writer | 7001 | The only process that opens the store for write. One writer is what makes the lock a constant. |
```

### Prose conventions

- **Bold the load-bearing clause**, never a whole sentence and never a heading's worth.
- *Italics for a quoted failure mode* — `*"a cache reused across schema versions returns
  stale rows"*` — so the example is visibly an example.
- Backticks on every filename, command, flag and config key, including in table cells.
- A `file.py:line` pointer is bare, not a link: links to line numbers rot on the next edit,
  and the pointer's job is to be greppable.

---

## README.md — the door

Written for someone who has not run it yet and does not know whether they want to.

| # | Section | What goes in it |
| --- | --- | --- |
| 1 | **Title + one-sentence claim** | Centred `<h1>`, then the single strongest true sentence about what this does. Concrete, not categorical: "Point it at a monorepo and it tells you which packages a commit can possibly have broken, in under a second, with no build" — not "a dependency analysis tool". |
| 2 | **Status strip** | Four to six `<code>` facts, as text: runtime version, dependency count, the headline measurement, the maturity. Text rather than badge images — six shields.io badges are six remote fetches at the top of the file, and they rot. |
| 3 | **A screenshot or a sample run** | With a real alt text (what is *in* the image, for someone who cannot see it) and a caption saying what the reader should notice. Skip it entirely for a library; never use a mockup. |
| 4 | **Why this exists** | The constraint that made the project necessary, and what that constraint costs. This is the section that cannot be generated — it is the one worth asking the author about. End it with the consequence the whole design follows from. |
| 5 | **How it works** (`## How a <thing> is <done>`) | One ASCII diagram of the primary flow, then two or three paragraphs on the non-obvious ordering decisions in it. Close with a link to ARCHITECTURE.md for the full path. |
| 6 | **Contents** | A two-column table: link, and one line on what the reader gets there. |
| 7 | **Where the project is right now** | What is built, what is measured, what is not. A table of workstreams with an explicit status and the number that backs it. Unfinished work is named, not omitted. |
| 8 | **Quickstart** | `### What you need first` (versions, disk, hardware), then the shortest numbered path to a working result, then `### Before you trust anything downstream` — the check that proves the install is real. |
| 9 | **Every command** | The full entry-point table: command, what it does, what it needs running first. |
| 10 | **Using it** | Subsections per real task, in the order a user meets them. Each shows the actual output or the actual screen, not a description of it. |
| 11 | **Repository layout** | A monospace tree where every line's comment says *why that file exists*, not what it contains. |
| 12 | **Configuration** | Where values live, what a "variant"/profile/override is, and what is enforced about them. |
| 13 | **Measuring it** | The test/eval/benchmark setup, what it can establish, and what it structurally cannot. Then `### Results so far` with the numbers and their noise floor. |
| 14 | **The <hard problem>** | The one thing that makes this repo awkward to work with — licensed data, a credential, a multi-gigabyte download, a proprietary dependency — and what a fresh clone has to do about it. |
| 15 | **Working on this repository** | The pre-commit commands, then the handful of rules whose violation is silent, each with its consequence. A compressed view of CLAUDE.md, linking to it. |
| 16 | **Vocabulary** | Only if the domain has jargon a competent engineer from outside would not know. Table: term, what it means *here*. |
| 17 | **Where to go next** | Every other document worth reading, each with a one-line reason. Nothing gitignored. |

---

## ARCHITECTURE.md — how it fits together, and why

Written for someone who has run it and is about to change it. Numbered sections, because
they get cited in reviews.

Open with two short paragraphs: what this document is, that it assumes the README, and
where the evidence for its claims lives — plus the promise that a judgement call will say
it is one.

| # | Section | What goes in it |
| --- | --- | --- |
| — | **Contents** | Numbered links with a gloss each. |
| 1 | **The shape of the system** | Process/service count, what is on disk, and one ASCII diagram. Then a table of components: role, port/path, what it holds, **why it exists**. Follow with the flags or settings that are load-bearing and easy to get wrong. |
| 2 | **Configuration** | The single source, the only module that reads it, how overrides work, and a guards table: guard, where it lives, what it prevents. |
| 3.. | **One section per path through the system** | The write path, the data model, the read path, the API surface, the interface, the test harness — whatever this system has. Each gets: the mechanism, a diagram or table if it has parallel parts, then `### Why <the non-obvious choice>` subsections carrying the evidence. `file.py:line` throughout. |
| n−3 | **Invariants** | A numbered list of the properties that must hold, opening with the note that breaking one is usually silent. Each says what enforces it — a test, an assert, a type, a constant. |
| n−2 | **Known constraints** | Where the system is currently binding. Open by saying these are stated because they are real, not because they are about to be fixed. Include the statistical honesty paragraph: how many samples, what one sample is worth, what difference is not a result. |
| n−1 | **What is deliberately absent** | Two-column table: what is not here, and why. Include things that were built, measured and deleted — with the number that killed them. This is the section that stops the same idea being re-proposed every quarter. |
| n | **Where the next change attaches** | For each piece of open work: the seam it attaches to, what is already shared, and what actually has to move. Written for the person picking it up cold. |

---

## CLAUDE.md — the working conventions

Written for whoever touches the repo next, agent or human. Say that in the opening line:
these apply to people too, nothing here is agent-specific except the tone.

| # | Section | What goes in it |
| --- | --- | --- |
| 1 | **Orientation** | One paragraph on what the project is, in the terms the code uses. Then what exists and what is still open. |
| 2 | **This is not the `<parent>` repo** | Only when a parent directory has its own `CLAUDE.md`. Name what does not apply here and what does carry over. Without this, inherited instructions get followed silently. |
| 3 | **Commands** | One fenced block, every command with an end-of-line comment. Mark which need no services and which need something running first. Name the one command to run before every commit. |
| 4 | **Hard rules** | The invariants, numbered, as prose with their reasons — not a bullet list of imperatives. Each says what fails, how it fails silently, and what asserts it. Exceptions are enumerated *here and nowhere else*, and adding one requires the same treatment: a gate, a safe default, and a line in the list. |
| 5 | **Spec-first / process** | How behaviour gets defined before it is built, where the record of findings lives, and when skipping the process is legitimate (say so in one line and why it is safe). |
| 6 | **Style, as this codebase writes it** | Not a style guide — the specific habits this repo has. Module docstrings say why. Comments cite evidence. `_prefix` means private. User-facing failures raise with an actionable message. Return named structures, not bare tuples. Formatter, line length, type checker. |
| 7 | **Testing** | What the test entry point actually is (it may not be a framework), which modules carry their own self-check and why, and the rule that a bug's fix is preceded by the assertion that would have caught it. If there is a regression corpus, state that a case is never deleted for starting to pass. |
| 8 | **Changing a measured value** | The procedure: add an overlay, run the harness, compare on the non-held-out split, respect the noise floor, record the outcome — including a negative one — then promote. |
| 9 | **Before you say it is done** | A checklist of mechanically checkable items. Every line must be something a reader can confirm in one command or one grep. No "code is clean". |

---

## Verification

Run these before reporting the documents finished. Each one has caught a real defect.

```sh
# The relative link targets each document names, once
links() {
  grep -ohE '\]\([^)]+\)' README.md ARCHITECTURE.md CLAUDE.md \
    | sed 's/.*](//; s/)$//; s/#.*//' \
    | grep -v '^$' | grep -vE '^(https?|mailto):' | sort -u
}

# Every relative link resolves to a file that exists
links | while read -r p; do [ -e "$p" ] || echo "dead link: $p"; done

# No document links into anything gitignored — a fresh clone has none of it
links | while read -r p; do git check-ignore -q "$p" && echo "gitignored: $p"; done

# Anchors in the Contents tables point at headings that exist
grep -ohE '\]\(#[a-z0-9-]+\)' README.md ARCHITECTURE.md | sed 's/.*](#//; s/)$//' | sort -u
# Headings, skipping fenced blocks — a ```markdown example containing "## Contents"
# is not a heading, and a check that matches its own examples reports a false violation
awk '/^```/{f=!f; next} !f && /^#{2,4} /' README.md ARCHITECTURE.md   # slugify these and diff

# Unfalsifiable adjectives
grep -niE 'robust|seamless|blazing|powerful|production-grade|comprehensive|cutting-edge|state-of-the-art' \
  README.md ARCHITECTURE.md CLAUDE.md

# Every file:line pointer still resolves to that file
grep -ohE '[a-z_/]+\.(py|ts|js|go|rs|sql):[0-9]+' ARCHITECTURE.md | sort -u \
  | while IFS=: read -r f n; do
      [ -e "$f" ] || { echo "missing file: $f"; continue; }
      [ "$(wc -l < "$f")" -ge "$n" ] || echo "past end of file: $f:$n"
    done
```

Then by hand:

- Every command in the Commands block and the Quickstart was **actually run**, or is
  explicitly marked as unrun.
- Every number names where it was measured, on what input, and what difference is noise.
- Every hard rule names the failure it prevents and what asserts it.
- The "deliberately absent" table has at least one entry that was built and removed —
  if it has none, the git history was not read.
- `AGENTS.md`, if present, is a symlink to `CLAUDE.md` (`ls -l AGENTS.md`) or the handover
  says the two must be edited together.
