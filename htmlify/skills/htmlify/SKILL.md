---
name: htmlify
description: Turn anything from the current conversation — a PR, a finding, a comparison, a plan, a dataset, an explanation — into one self-contained HTML page, published as a private claude.ai Artifact with a shareable link. Use when the user says "htmlify", "/htmlify", "make this an HTML page", "turn this into a webpage/report", "render this as HTML", "htmlify this in dark mode / dark", or wants a visual, shareable writeup of something discovered or built. Publishes via the Artifact tool (local .html only when asked); Swiss light palette that follows the system into dark.
---

# htmlify

Capture whatever the conversation just produced — a PR's changes, a thing you
discovered, two approaches compared, a plan, query results — as **one
self-contained HTML page** (inline CSS/JS, no build step) and publish it as a
**private Artifact**, handing back the link. HTML earns its place over markdown when the content has **density,
structure, visuals, or interactivity** that prose can't carry.

## Steps

1. **Name the artifact.** What is this page *for* and who reads it? That fixes
   the shape: a PR → diff report; a comparison → side-by-side; a finding →
   annotated explanation; tabular data → sortable table; a design → live
   prototype.
2. **Gather grounding.** Pull the real material from the conversation and the
   tools at hand — `git diff`, file contents, query output, the spec/ticket.
   Don't summarise from memory when the source is reachable.
3. **Load `artifact-design`** (the Skill) before writing: it holds the page
   contract. Write to `<scratchpad>/<slug>.html`, never the repo. Start from
   `skills/htmlify/template.html` (copy it, fill the body). The `<title>` is a
   2–4 word name, not "X: explainer".
4. **Look at it before publishing.** Render a screenshot and read it:
   `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new
   --window-size=1200,2400 --screenshot=<file>.png file://<abs path>`; check a
   390 px wide one too (phone, no sideways scroll). A splice that lands in the
   wrong place drops the stylesheet silently; only the render shows it.
5. **Publish** with the Artifact tool (`file_path`, an `icon` word, a one-line
   `description`); it is private until the user shares it. Give the link. To
   update, republish the same file path (same URL).
   - **For a PR:** put the link in the PR description; never attach or commit HTML.
   - **Only when the user asks for a file** ("give me the .html"): write it where
     they say and `open` it instead of publishing.

## What makes HTML worth it (from the "effectiveness of HTML" idea)

Reach for this skill only when at least one applies — otherwise offer markdown:

- **Density** — tables, colour-coded diffs, severity markers, BOM-style breakdowns.
- **Visuals** — embed the *real* artifact: an SVG symbol/icon/diagram, a colour
  swatch, a flowchart, a layout sketch. Label it live, not a mockup, so the page
  doubles as a visual check.
- **Spatial layout** — side-by-side before/after, comparison columns, tabs.
- **Interactivity** — sliders/knobs to tune a parameter, a toggle to filter rows,
  collapsible sections. Keep it vanilla JS, inline.
- **Shareability** — one link that opens on any device, phone included.

## Patterns worth keeping (only when they fit)

- **"Copy as" / export buttons.** When the page lets the user edit or pick
  something (reorder, tune, select), add a button that copies the result as text
  or a prompt — bridges the visual artifact back to a text workflow.
- **Reusable reference.** The artifact persists at its URL; republishing the same
  file updates it in place. Use a stable slug, not a timestamped throwaway.

## Swiss house style (default skin)

Unless the user asks for something else, theme the page in the **Swiss /
International Typographic Style**: white canvas, black text, one accent (green by
default), a strict grid, and whitespace as the primary device. The discipline is
*subtractive* — "perfection is achieved not when there is nothing more to add,
but when there is nothing left to take away." Every element must answer: does
this help the reader understand, or does it just prove a designer was here?

```
--bg:     #ffffff   /* white canvas */
--ink:    #111111   /* headings + strong rules */
--text:   #1a1a1a   /* body — never light grey on white */
--text-dim:#555555  /* secondary, still legible */
--text-mute:#767676 /* captions, metadata */
--line:   #e3e3e3   /* hairline rules */
--rule:   #111111   /* strong structural rules */
--accent: #28a745   /* ONE accent — used only to carry meaning */
font-family: "Helvetica Neue", Helvetica, Inter, Arial, sans-serif;  /* neutral sans, offline fallback */
```

The rules that make it Swiss:

- **Hierarchy through structure, not decoration.** Size, weight, and space —
  never gradients, shadows, glows, or ornament. Big flush-left headline at 700
  with tight leading (~1.05) and negative tracking (`-0.02em`); body at 400;
  small uppercase labels tracked out (`0.1em`).
- **One accent, doing work.** A single block of colour in a field of grey
  communicates; six competing colours communicate nothing. Use the accent only to carry meaning —
  a link, a key number, an active state — not to fill space.
- **Mathematical type scale** (ratio ~1.333: 13 / 17 / 23 / 30 / 40 / 64px) as
  CSS variables, so steps feel intentional and the eye knows where to go.
- **A real 12-column grid** (`repeat(12,1fr)`), applied consistently — it settles
  the boring decisions in advance and frees you to break it deliberately for
  emphasis. Cap the reading measure at ~65–75ch.
- **Strict spacing scale** (4 / 8 / 16 / 24 / 32 / 48 / 64) — only these values.
  Treat whitespace as material: generous padding, section gaps much larger than
  paragraph gaps, headlines in a column of air.
- **Sharp corners, hairline rules.** No `border-radius`, no fills where a rule
  will do (tables get hairline rules, not zebra). Legibility over effect — never
  light-grey body text, never decoration that serves the designer not the message.

One mental test: strip the accent entirely — if the page still reads as ordered
and hierarchical from type, grid, and spacing alone, it's built right. Colour is
there to carry meaning, not to be the scaffolding.

### Dark mode

The template's tokens already switch to a near-black palette under
`prefers-color-scheme: dark` (guarded by `:root:not([data-theme="light"])`, and
again under `:root[data-theme="dark"]`). For "htmlify this in dark", add
`data-theme="dark"` to `<html>`; don't recolour by hand. New colours go in as
tokens in all three blocks, never as literals in rules.

`skills/htmlify/template.html` is a ready-made starting point: the tokens above
already inlined, plus a 12-column grid and example hero / card / note / table /
badge / code components. **Copy that file, then replace the body** between the
`<!--CONTENT START-->` / `<!--CONTENT END-->` markers and delete the components
you don't use — cheaper and more consistent than hand-rolling the scaffold each
time. (Recolour by editing the `:root` tokens; keep it to one accent.)

## Rules

- **One page, inline.** Inline CSS/JS. A library only when it earns it, from
  cdnjs.cloudflare.com (or the other CDNs `artifact-design` allows) at an exact,
  pinned version; no web fonts beyond Google Fonts.
- **Ground every claim.** Trace to the diff, a file, a spec, or query output. If
  the "why" isn't evidenced, leave it out rather than invent it.
- **Excerpt, don't dump.** Show the line/row that matters, not whole files.
- **Earn the format.** Pure linear prose with nothing visual or interactive isn't
  an HTML candidate — say so and offer a markdown summary instead.
- **Private, never committed.** Publish privately; never commit the HTML or post
  the link anywhere unless asked.
- **Restrained styling.** Readable beats flashy; the content is the point.
