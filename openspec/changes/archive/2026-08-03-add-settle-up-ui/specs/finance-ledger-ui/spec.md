## MODIFIED Requirements

### Requirement: Month switching is race-safe

Month navigation (previous/next arrows) SHALL always render data belonging
to the displayed month: a slow response for a previously selected month
SHALL never overwrite the currently selected month's view. This applies to
every figure the month drives, including the split-spending line, which is
fetched separately from the month's transactions.

#### Scenario: Rapid month switching

- **WHEN** the user switches months twice quickly and the first month's
  response arrives after the second's
- **THEN** the view shows the second (current) month's data, not the stale
  first response

#### Scenario: The split-spending figure follows the same rule

- **WHEN** the month is switched while a split-spending request for the
  previous month is in flight
- **THEN** the late answer is discarded rather than shown against the new
  month

## ADDED Requirements

### Requirement: The overview shows split spending as its own line

The monthly overview SHALL show what the user personally owed on split
expenses that month, per currency, as a line of its own beside the recorded
expense totals. It SHALL NOT be added into the expense total and SHALL NOT
affect the budget card, because budgets deliberately exclude split spending —
folding it in would disagree with the server's own overspend decision. A
month with no split activity SHALL omit the line rather than show a zero.

#### Scenario: Split spending sits beside recorded expenses

- **WHEN** the user has recorded expenses and split shares in the month
- **THEN** the overview shows both figures separately, and the expense total
  is exactly what the recorded transactions produce

#### Scenario: Budgets are unaffected

- **WHEN** the user has TWD split shares in the month
- **THEN** the budget card's consumed amount and its warning state are
  exactly what they would be without them

#### Scenario: A month without splits omits the line

- **WHEN** the user has no split shares in the month
- **THEN** no split-spending line is shown, rather than a zero

#### Scenario: A month with splits but no transactions still shows the line

- **WHEN** the user has split shares but recorded no transactions that month
- **THEN** the split-spending line is still shown, rather than being replaced
  by the empty-month call to action

#### Scenario: The line says what it is not counted in

- **WHEN** the split-spending line is shown
- **THEN** it states, in the reader's own language, that it is counted
  neither in the expense totals nor against the budget — it is styled like a
  totals card and sits next to both, so nothing else on the screen rules out
  the double-count

#### Scenario: A second account never sees the first one's figure

- **WHEN** one account has loaded a month's split spending and a different
  account then loads the same calendar month
- **THEN** the first account's figure is never shown — neither while the
  second account's own request is still in flight, nor after signing out

#### Scenario: A failure in one figure does not take down the other

- **WHEN** loading split spending fails but the month's transactions load
- **THEN** the overview still shows the recorded totals, and the
  split-spending line reports its own failure

### Requirement: The overview lays out on small screens

The whole overview — the per-currency expense/income/net totals, the category
breakdown, the split-spending line and the recent-transaction rows — SHALL lay
out without layout errors at 320dp and 360dp wide, on a phone-height viewport,
in each supported locale, at text scales 1.0 and 2.0, with amounts and category
names wide enough to be realistic rather than token fixtures.

#### Scenario: A wide amount does not push a row off the edge

- **WHEN** the overview is rendered at 320dp or 360dp on a phone-height
  viewport in any supported locale at text scale 1.0 or 2.0, with recorded
  transactions in more than one currency, several expense categories and
  seven-figure amounts
- **THEN** no layout error is raised: in every label-plus-amount row the
  amount keeps its own width and the label is the half that wraps, rather
  than the amount overflowing to the right or consuming the row

#### Scenario: A long category name does not squeeze the amount out

- **WHEN** an expense category's name is long enough to fill the row on its
  own at those widths and text scales
- **THEN** the name wraps and the amount stays fully on screen — the amount
  is never the half that is squeezed

#### Scenario: A recent-transaction amount is not broken across lines

- **WHEN** the overview is rendered at 360dp or 375dp — the ordinary phone
  widths — at text scale 1.0, with a seven-figure transaction amount
- **THEN** that amount paints on a single line: a wrapped amount breaks
  mid-digit-group (`+1,234,5` / `67`), reads as two numbers, and raises no
  layout error at all, so "no layout error" is not a sufficient criterion here
