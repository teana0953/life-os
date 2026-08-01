# shared-widgets Specification

## Purpose
TBD - created by archiving change extract-shared-widgets. Update Purpose after archive.
## Requirements
### Requirement: Month grid helper

The system SHALL provide a `monthWeeks(DateTime month)` helper returning the
month's day numbers laid out as whole weeks, Sunday first, padded with nulls
before the first day and after the last so every week has seven entries.

#### Scenario: Month starting on Sunday needs no leading padding

- **WHEN** the month's first day falls on a Sunday
- **THEN** the first week starts with day 1 and has no leading nulls

#### Scenario: February in a leap year

- **WHEN** the month is February of a leap year
- **THEN** the grid contains days 1 through 29, and every week has exactly
  seven entries with only nulls outside that range

### Requirement: Shared presentational widgets

The system SHALL provide reusable widgets whose identifying keys, copy, and
spacing are supplied by the caller, so that adopting them changes no
existing screen's behavior or test keys: a date field (label, formatted
value or placeholder, tap target that may be disabled), a card error state
with a retry action (optional header, configurable spacing), a card loading
state, and a tracker busy bar.

#### Scenario: Caller-supplied keys are used

- **WHEN** a widget is given its identifying keys
- **THEN** those exact keys appear in the widget tree, so screens keep the
  keys they had before adopting the shared widget

#### Scenario: Retry action fires

- **WHEN** the retry control of the card error state is tapped
- **THEN** the caller's retry callback runs

#### Scenario: Card error state with a header keeps its layout

- **WHEN** the card error state is given header widgets
- **THEN** the header widgets render above the message and stay interactive,
  the message and retry control remain centered, and the card is not made
  taller by wrapping the header in an extra full-height container

#### Scenario: Disabled date field

- **WHEN** a date field is given a null tap callback
- **THEN** its control is disabled

#### Scenario: Busy bar reflects state

- **WHEN** the tracker busy bar is told it is busy
- **THEN** a progress indicator carrying the caller's key is shown; when not
  busy, no indicator is shown

### Requirement: Month picker dialog

The system SHALL provide a month picker dialog that lets a user jump to any
year and month in one interaction: a year row that steps back and forward
**and whose label opens a list of selectable years**, and a grid of the
twelve months. Controls that open something SHALL carry a visible affordance
so the user can tell they are interactive. It SHALL return the first day of the chosen
month, or nothing when dismissed. When given a first and/or last selectable
month, months outside that range and the year steps that would leave it SHALL
be disabled rather than silently doing nothing. The currently viewed month
SHALL be marked as selected by more than color alone.

#### Scenario: Jumping to a month two years back

- **WHEN** the user opens the picker on 2026-07, steps the year back twice,
  and taps March
- **THEN** the picker closes returning 2024-03-01

#### Scenario: Dismissing changes nothing

- **WHEN** the user dismisses the picker without choosing
- **THEN** nothing is returned and the caller's month is unchanged

#### Scenario: Bounds disable out-of-range choices

- **WHEN** the picker is given a last selectable month of the current month
- **THEN** later months are shown disabled, and stepping the year forward past
  it is disabled

#### Scenario: Picking a year from the list

- **WHEN** the user taps the year label and chooses a year several years away
- **THEN** the month grid shows that year, without stepping through the
  years in between

#### Scenario: Expandable controls look expandable

- **WHEN** a month label that opens the picker, or the picker's year label,
  is shown
- **THEN** it carries a visible dropdown affordance rather than looking like
  plain text

### Requirement: Label-and-value row keeps both halves alive

The system SHALL provide a shared "label on the left, value flush right" row
in which **both halves have a width floor**. The value SHALL be laid out as a
non-flex child capped at 65% of the row's width, and the label SHALL be
`Expanded` into what is left — so the cap on the value is, as its complement,
the label's floor of 35%. Neither half SHALL be squeezed to zero width: when
the two together do not fit, both wrap rather than one shattering one glyph
per line.

#### Scenario: A long label yields but the value stays whole

- **WHEN** a 30-character label is paired with a value that fits in the
  remaining space
- **THEN** the value keeps its natural width on a single line and the label
  is the half that wraps

#### Scenario: Both halves too long for the row

- **WHEN** a 27-character label and an 8-digit amount are rendered at 320dp
  with a text scale of 2.0
- **THEN** the label's box keeps at least 30% of the row and the value's box
  keeps at least 30% of the row, both wrap to a bounded number of lines, and
  the row's height stays far below the ~960dp it reached when the value was
  allowed the whole row

#### Scenario: Value's box reaches the row's right edge

- **WHEN** the row is laid out at any width where the value fits on one line
- **THEN** the value's right edge coincides with the row's right edge, because
  the `Expanded` label is what pushes it there — no slack is parked after the
  value

### Requirement: Numeric values must declare end alignment

The row places the value's **box**, not its glyphs. While the value fits on
one line the box is its glyphs and the distinction is invisible — which is why
deleting every `TextAlign.end` in the app once left the whole suite green.
Once the value wraps, and under the 65% cap it now can while the row still has
room, `TextAlign.end` is the only thing holding the continuation lines against
the row's edge. The row cannot impose alignment on an arbitrary value widget,
so callers whose value is a number SHALL pass `textAlign: TextAlign.end`. This
is a measured requirement, not a style preference.

#### Scenario: A wrapped number without end alignment drifts

- **WHEN** a numeric value wraps to a second line and the caller did not pass
  `TextAlign.end`
- **THEN** the continuation lines sit left of the row's right edge, so the
  amount no longer reads as right-aligned — the row does not and cannot
  correct this

### Requirement: Label-and-value row's constraints on its host

The row reads `constraints.maxWidth` to cap the value and uses `Expanded` to
divide the remainder, so it SHALL be given a **bounded width** and SHALL NOT
be placed under an ancestor that asks for its intrinsic width. Under either
violation it throws rather than degrading.

#### Scenario: Horizontally unbounded parent

- **WHEN** the row is placed in a horizontally scrolling `ListView`, a `Row`
  without a bounding flex child, or an unconstrained trailing slot
- **THEN** layout throws rather than silently producing a broken row

#### Scenario: Ancestor asking for intrinsic width

- **WHEN** the row is wrapped in `IntrinsicWidth` or `IntrinsicHeight` — for
  instance to "make the columns line up"
- **THEN** layout asserts, because the `LayoutBuilder` inside cannot answer a
  size question posed outside layout; using the row as a `ListTile`'s `title`
  is fine, since `ListTile` lays its title out with real constraints

### Requirement: The floor equivalence holds only with exactly one flex child

"What the value is refused is what the label is guaranteed" is an arithmetic
consequence of the row having **exactly one flex child** — the label. It is
not a property the row enforces. Adding a third child, or nesting an
`Expanded`/`Flexible` inside the value widget, redistributes the row's free
space and breaks the equivalence **silently**: no exception, no test failure,
just a half that can collapse again. Callers SHALL keep the row to its two
halves and SHALL NOT pass a value widget containing its own flex child.

#### Scenario: A third child is added to the row

- **WHEN** a third child (an icon, a trailing chevron) is added alongside the
  label and the value
- **THEN** the 35% label floor no longer follows from the 65% value cap, and
  the collapse the cap exists to prevent can reappear with nothing to catch it

#### Scenario: The value widget hides its own flex child

- **WHEN** the value passed in is itself a `Row` containing an `Expanded`
- **THEN** the value no longer takes its natural width, the guarantee that its
  box ends at the row's right edge no longer follows, and the failure is
  silent

