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

### Requirement: One shared way to open a modal sheet

Opening a modal bottom sheet SHALL go through a single shared entry point
that fixes the options every form sheet in this app needs, so that the
reasoning behind them lives in one place rather than being restated at each
call site, and so a new sheet is correct without its author having to know or
copy them.

That entry point SHALL make the sheet scroll-controlled (an uncontrolled
sheet is capped at 9/16 of the screen, which has clipped a submit button off
the bottom), apply the safe area, and show a drag handle (without one, a tall
sheet fills the viewport, the scrim disappears, and the drag is swallowed by
the content's own scrolling — leaving the browser back button as the only
exit, which on the PWA unwinds the router stack to the home screen).

A sheet that deliberately differs SHALL say so where it opens, so that
differing is distinguishable from forgetting.

#### Scenario: A shared sheet carries the drag affordance

- **WHEN** a sheet is opened through the shared entry point
- **THEN** it shows a drag handle, so it can be dismissed without relying on
  the scrim or a system gesture

#### Scenario: A tall sheet is not clipped

- **WHEN** a sheet's content is taller than 9/16 of the screen
- **THEN** its full height is available rather than being capped, so the
  content at the bottom stays reachable

#### Scenario: Differing is explicit

- **WHEN** a sheet opts out of the shared entry point
- **THEN** the reason is stated at that call site, so it reads as a decision
  rather than an omission

### Requirement: Shared async-state scaffold

The system SHALL provide a shared async-state scaffold that renders a
loading indicator while loading, a re-authentication state while
re-authentication is required, and the caller's content otherwise. Loading
SHALL take precedence over re-authentication.

The re-authentication state SHALL present both the caller-supplied message
and a control that starts re-authentication, so the user is never shown a
problem without a way to act on it. The control SHALL be a required
constructor parameter, so that a screen cannot silently render a
re-authentication state with no way out.

#### Scenario: The re-authentication state offers a way out

- **WHEN** the scaffold is in the re-authentication state
- **THEN** the caller's message and an enabled sign-in-again control are both
  visible, and tapping the control invokes the caller's callback

#### Scenario: Loading still wins over re-authentication

- **WHEN** both loading and re-authentication are signalled at once
- **THEN** the loading indicator is shown and no sign-in-again control appears

#### Scenario: The re-authentication state is reachable without an app bar

- **WHEN** the scaffold is in the re-authentication state and the caller
  supplied no app bar
- **THEN** the sign-in-again control is still present and hittable, so a
  screen with no back affordance is not a dead end

#### Scenario: The control's callback is the caller's, not the widget's

- **WHEN** the sign-in-again control is tapped
- **THEN** the scaffold invokes exactly the callback it was given and performs
  no navigation of its own — what happens to the route stack afterwards is
  the caller's obligation and is not specified here

### Requirement: Empty-state presentation

Where a screen or tab has nothing to show, or a card or section within a
populated screen has an empty region, the app SHALL present that emptiness in
one of two shapes, chosen by whether anything that is part of the content —
a card header, a section heading, a summary above it — still names that region
once it is empty. Chrome does not count: an app bar title, a tab label, a
navigation bar or a date switcher says which page the reader is on, not what
the empty region was.

- A **full guide** for a screen or tab that has nothing to show: an icon, a
  title, optionally a body, and optionally an action.
- An **inline note** for an empty region inside a card or section: one line of
  muted, centred text.

Both shapes SHALL take their colours and text styles from the theme, and each
SHALL accept an identifying key from the screen that uses it, so a screen that
had one keeps it.

A full guide SHALL remain usable at the narrowest supported width and the
largest supported text scale — its actions reachable and its text not clipped.

A full guide SHALL be able to offer any number of actions — the app's empty
states offer none, one, two and three — so its actions are a **list**, not a
primary/secondary pair. Where a guide offers more than one, exactly one SHALL
carry the primary emphasis and the rest secondary emphasis, so that a guide
never presents two equally-weighted first moves.

This requirement does not reach a control that is shown when a region is empty
but whose purpose is to be acted on rather than to explain the emptiness — a
tappable prompt is not an empty state.

#### Scenario: A screen with nothing to show guides the user

- **WHEN** a screen or tab has no content
- **THEN** it shows an icon, a title, and where one exists an action, rather
  than a bare line of text

#### Scenario: An empty region inside a card stays small

- **WHEN** a card or section within a populated screen has an empty region
- **THEN** it shows one line of muted text, not a full-page guide

#### Scenario: The guide survives a narrow screen at a large text scale

- **WHEN** a full guide is shown at the narrowest supported width and the
  largest supported text scale
- **THEN** its text is not clipped and its action is still reachable

#### Scenario: A guide with several actions still has one first move

- **WHEN** a full guide offers more than one action
- **THEN** exactly one of them carries the primary emphasis, and the action a
  user cannot yet complete is not the one that carries it

#### Scenario: A screen that had a key keeps it

- **WHEN** an empty state that carried an identifying key is replaced by a
  shared one
- **AND** the shared shape still has a node of its own to carry that key
- **THEN** that key still resolves to the same part of the tree

The exception, recorded because it happened: a key on a node the shared shape
does not have — `split_tab`'s `split-empty-needs-friends`, whose line became
the guide's `body`, a `String` with no node to hang a key on — is dropped
rather than preserved by widening the shared widget. Its copy stays asserted
by text, and the guide as a whole keeps its own key.

