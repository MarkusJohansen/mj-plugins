# htmlify

Turn anything from the current conversation — a PR, a finding, a comparison, a
plan, a dataset, an explanation — into **one self-contained HTML file** (inline
CSS/JS, no build step, no external assets) you can open and share.

HTML earns its place over markdown when the content has density, structure,
visuals, or interactivity that prose can't carry — colour-coded diffs, sortable
tables, side-by-side comparisons, embedded SVG, sliders to tune a parameter.

## Skill

| Skill | What it does |
|-------|--------------|
| `/htmlify` | Captures the conversation's latest artifact as one offline `.html` file in the Swiss / International Typographic house style, then opens it. |

A ready-made `skills/htmlify/template.html` ships the style tokens, a 12-column
grid, and example hero / card / note / table / badge / code components — copy it
and fill the body.

## Install

```sh
claude plugin marketplace add MarkusJohansen/mj-plugins
claude plugin install htmlify@mj-plugins
```

## License

MIT
