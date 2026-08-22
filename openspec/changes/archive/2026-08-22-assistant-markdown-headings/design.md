## Context

See proposal.md — Why. The constraints that shape the approach, all read off
the current `assistant_markdown.dart`:

- The parser is line-oriented: `parseAssistantMarkdown` produces exactly one
  `MdBlock` per non-blank source line, and blank lines only set
  `blankBefore` on the next block. Nothing spans lines, so no multi-line
  construct (fenced code, setext heading) can be added without changing that
  shape.
- The widget lays every block out in one `Column` inside a `LayoutBuilder`,
  with three measured quantities shared across all blocks: `markerWidth`
  (widest list marker, laid out by a `TextPainter` at the ambient scale),
  `markerGap`, and `perLevelIndent` (clamped so a deep nest cannot push the
  row past the bubble). Anything new must not perturb those.
- Text scaling is split: `Text` applies `MediaQuery.textScalerOf` to font
  sizes by itself, while the widget scales gutter/indent/gap **manually** via
  `scaler.scale(...)`. Getting this backwards double-scales.
- The whole tree is inside `ExcludeSemantics`, wrapped by one `Semantics`
  whose `label` is built by joining per-block strings with `\n`.
- `assistant_screen.dart` passes a style that sets `color` only; the real
  paint style is `DefaultTextStyle.of(context).style.merge(style)`, already
  computed as `effectiveStyle`.

## Goals / Non-Goals

**Goals:**

- Two new block kinds that fit the existing one-block-per-line shape.
- Heading sizes derived from the caller's own font size, so the bubble stays
  consistent with whatever style the screen passes.
- Zero change to the measured gutter/indent path and to the single-label
  semantics contract.
- Guards that fail when the behaviour they name is broken, proven by mutation.

**Non-Goals:**

- No Markdown package. The deliberate-minimal-parser decision from issue #152
  stands; this change extends the list of known marks by two, it does not
  replace the approach.
- No multi-line constructs, so no setext headings and no fenced code blocks.
- No theme lookup for heading colour — headings inherit the bubble's text
  colour, as bold runs already do.

## Decisions

### D1. A separate `headingLevel` field, not a reuse of `MdBlock.level`

`MdBlock.level` is the list nesting depth and is multiplied by
`perLevelIndent` in the layout. Storing a heading's level there would indent
`### 標題` by three steps — a live bug, not a theoretical one. Add a distinct
nullable `int? headingLevel`, include it in `==` / `hashCode` / `toString`,
and leave `level` list-only.

*Alternative considered:* one `level` field plus a `kind != heading` guard at
the indent site. Rejected: it puts the correctness of the layout in a place
far from the field, and the next edit to the padding line loses it.

### D2. Line rules, and the order they are tried

Two new regexes, matched in `parseAssistantMarkdown` **before** the existing
bullet rule:

- thematic break: `^\s*-{3,}\s*$`
- ATX heading: `^\s*(#{1,4})[ \t]+(\S.*)$`

Order matters and is asserted, not assumed: the bullet rule
(`^(\s*)[*-]\s+(.*)$`) requires whitespace after the `-`, so `---` does not
match it today — but a later edit that relaxes the bullet rule would silently
turn every divider into a bullet. Trying the break first makes the precedence
explicit and testable.

`#{1,4}` cannot match `##### 太深`: it consumes four `#`, then the rule
demands whitespace and finds a fifth `#`, so the alternation falls through to
paragraph and the line stays literal — exactly the behaviour the spec asks
for, with no extra guard. `[ \t]+` (not `\s+`) is deliberate: `\s` includes
`\n`, which cannot occur here but invites a wrong reading. The `(\S.*)`
content group means `###` alone, or `###` with only trailing spaces (already
removed by the existing `trimRight`), is not a heading and stays literal — a
heading with no words is not structure.

*Alternative considered:* stripping a closing `#` run (`### 標題 ###`, legal
CommonMark). Rejected: the model does not emit it, and under the parser's own
rule an unhandled mark is shown as typed rather than half-eaten.

### D3. Heading sizes are multiples of the effective body size, and `Text` does the scaling

Heading style = `effectiveStyle.copyWith(fontWeight: FontWeight.w700,
fontSize: (effectiveStyle.fontSize ?? 14) * factor)` with factors
`{1: 1.5, 2: 1.3, 3: 1.15, 4: 1.05}`.

Four properties fall out of this and each is a spec scenario: strictly
decreasing across levels, all `> 1.0` so every heading is at least body size,
and — because `Text` applies the ambient `TextScaler` to `fontSize` itself —
the sizes scale with accessibility settings **without** a `scaler.scale(...)`
call. Calling `scaler.scale` on the font size here would double-scale and is
the single most likely mistake in this change; the ratios between adjacent
levels (1.15x and up) stay above the ~1.05 nudge a reader can miss.

*Alternative considered:* absolute point sizes (20/18/16/15). Rejected: the
caller's style is not fixed, and hard-coding sizes breaks the moment the
bubble's body size changes.

### D4. The rule is a 1-logical-pixel line in the text colour at reduced alpha

`SizedBox(height: thickness, width: <see below>)` containing a
`ColoredBox(color: (effectiveStyle.color ?? <fallback>).withValues(alpha:
0.6))`, `thickness = scaler.scale(1)` — a divider is a graphic, so unlike
font size it *is* on the manual-scaling side of D3. Colour comes from the
text colour rather than `Theme.of(context).dividerColor` so the rule is
legible on the assistant bubble's own background, which is not the scaffold
background the theme's divider colour was picked against. Alpha is 0.6, not a
lighter value: measured against the app's `surfaceLight`/`surfaceDark` tokens,
the ink-on-surface blend only clears the WCAG 3:1 non-text-contrast floor at
0.6 (~3.0:1 light, ~5.4:1 dark) — the originally-chosen 0.24 measures ~1.5:1,
an effectively invisible 1px hairline.

Width: `constraints.maxWidth` when the `LayoutBuilder`'s constraints are
bounded. The widget already branches on `constraints.hasBoundedWidth` for the
indent clamp, and the unbounded case is a shrink-wrap/test-harness one; there
the rule falls back to `scaler.scale(160)`, because a `double.infinity` width
throws in an unbounded parent and a zero-width rule would be invisible with no
test able to see it. This fallback is documented in a comment at the site.

### D5. Vertical space needs the *previous* block, so `_gapAbove` takes it

A heading needs room above it and a little room below; the `Column` only has a
top padding per child. Change `_gapAbove(block, scaler)` to
`_gapAbove(block, previous, scaler)`:

- heading: `scaler.scale(14)` above (more than the existing 10 for a
  paragraph break — a section boundary is a bigger break than a paragraph one)
- thematic break: `scaler.scale(12)` above
- any block whose previous block is a heading: `scaler.scale(6)`
- any block whose previous block is a thematic break: `scaler.scale(12)`
- everything else: today's rule, unchanged (`blankBefore` → 10, paragraph → 4,
  list item → 2)

The first block still gets 0, as today.

*Alternative considered:* wrapping heading/rule children in their own
`Padding` with `bottom`. Rejected: two sources of vertical space between the
same pair of blocks, and the totals stop being readable from one function.

### D6. Headings and rules bypass the marker/indent path entirely

In `_blockRow`, both new kinds return before the `Row`: `block.marker` is
`null` for them, so they already take the marker-less branch, and the padding
`left: blocks[i].level * perLevelIndent` is 0 because D1 keeps `level` at 0
for them. `_markerWidth` skips them for the same reason (`marker == null`
continues). Nothing about the gutter measurement changes — which is what the
"a heading between two bullets leaves the gutter alone" scenario pins.

### D7. Semantics: a heading contributes its text, a rule contributes nothing — and is dropped, not blanked

The label is a `\n`-join over blocks. A thematic break must be **filtered out**
of the list before the join; emitting `''` for it would put a blank line into
the announcement, which some screen readers pause on. A heading contributes
its plain text with no marker prefix and no level prefix — the `－` prefix is
the list-nesting device from `level`, and D1 keeps them separate.

Heading semantics stay inside the single label rather than becoming
`Semantics(header: true)` nodes: the whole widget is under `ExcludeSemantics`
and the existing contract (one announcement, reading order, one swipe) was a
deliberate accessibility decision, not an accident. Per-heading header nodes
would be a different change with its own on-device verification.

### D8. Guard strategy: every new behaviour gets a mutation

Per the repo's history of always-green guards, each guard below names the
mutation that must turn it red, and the mutation must be *run*:

| Guard | Mutation that must fail it |
| --- | --- |
| `### x` parses as heading level 3 | `#{1,4}` → `#{1,2}` |
| `##### x` stays literal | `#{1,4}` → `#{1,5}` |
| `#tag` stays literal | `[ \t]+` → `[ \t]*` |
| `---` is a break, not a bullet | move the break rule after the bullet rule |
| `- 醫療` is still a bullet | `-{3,}` → `-{1,}` |
| level sizes strictly decrease | make h2's factor equal h1's |
| every heading ≥ body size | h4 factor → `0.9` |
| heading is bold with no `**` | drop `fontWeight: w700` from the heading style |
| heading sizes track text scale | wrap the heading font size in `scaler.scale` (double-scaling must be visible as a *different* failure than not scaling at all) |
| gutter unchanged around a heading | make `_markerWidth` count heading blocks |
| heading not indented after a nested item | set `headingLevel` into `level` (D1's rejected alternative) |
| rule speaks nothing / heading speaks | emit `''` for the break instead of dropping it |

Assertions compare against hard-coded literals (`'本月支出'`, a numeric size
ordering), never against a value re-derived from the code under test.

## Risks / Trade-offs

- **`## 標題` was pinned as literal by an existing test** → That test
  (`leaves syntax it does not know as literal text`) is re-pointed at marks
  that remain genuinely unsupported (`| a | b |`, `` `code` ``, `#####`). The
  change to that test is the visible record that the behaviour changed on
  purpose; deleting the test instead would erase it.
- **Font-size guards are measured with the test placeholder font** → sizes are
  asserted from the `TextStyle` the widget builds, and ordering is asserted
  rather than pixel widths, so the guards say nothing about a real font's
  metrics. This is the same limitation the existing width guards have; the
  real-font check stays a visual one.
- **Double-scaling headings at large text scale** → guarded by D8's row, and
  by a scenario that renders the same text at 1.0 and 2.0 and compares painted
  heights rather than trusting the style.
- **A model emitting `---` as a table separator or a YAML fence** would now
  draw a rule instead of showing dashes → accepted: the reply is prose, tables
  are already unsupported, and a stray rule is a smaller misread than a line
  of literal dashes.
- **Unbounded-width fallback for the rule (D4)** is arbitrary → it is reachable
  only from a shrink-wrapping parent, which the assistant bubble is not; the
  comment at the site says so.

## Migration Plan

None needed: one widget, one call site (the assistant reply bubble), no
persisted data and no API surface. Rollback is reverting the single file.

## Open Questions

None. The two size/spacing tables (D3, D5) are chosen values, not open
questions — if they look wrong on device, they are tuned in place without
touching the specs or the task breakdown.
