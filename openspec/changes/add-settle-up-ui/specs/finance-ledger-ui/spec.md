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

#### Scenario: A failure in one figure does not take down the other

- **WHEN** loading split spending fails but the month's transactions load
- **THEN** the overview still shows the recorded totals, and the
  split-spending line reports its own failure
