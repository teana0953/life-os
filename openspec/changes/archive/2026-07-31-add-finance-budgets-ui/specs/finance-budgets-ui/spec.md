## ADDED Requirements

### Requirement: Budget progress card on the overview

The 總覽 tab SHALL show a budget card for the selected month listing the
overall budget (if set) and each category budget (if set), each row showing
the budget's name, formatted `spent / amount` in TWD, a textual percent, and
a progress bar colored by progress: normal below 80%, a warning color at or
above 80%, and the error color with an over-budget label at or above 100%.
When no budget exists, the card SHALL show an empty-state guide with a
call-to-action that opens the budget sheet — the feature stays discoverable,
never hidden. The card SHALL reflect the selected month's progress and reuse
the controller's existing loading/error/reauth handling (no separate
request).

#### Scenario: Rows and colors follow progress

- **WHEN** the selected month has an overall budget at 50% and a 餐飲 budget
  at 85% and a 交通 budget at 120%
- **THEN** the card shows three rows with normal, warning, and error styling
  respectively, the 交通 row carrying an over-budget label, and each row a
  textual percent (not color alone)

#### Scenario: No budgets yet guides the user

- **WHEN** the user has set no budgets
- **THEN** the budget card shows guidance with a set-budget action, and
  tapping it opens the budget sheet

### Requirement: Budget sheet edits all budgets in one place

An edit action on the budget card SHALL open a modal bottom sheet (padded
above the soft keyboard) with one TWD integer amount field for the monthly
overall budget and one for every non-archived expense category, following
the empty-plus-hint zero convention where an empty field means "not set".
An archived category SHALL appear only while it still has a budget, marked
as archived and clearable but not editable to a new amount. The sheet SHALL
state that budgets are recurring monthly settings applying to every month.
Saving SHALL apply only the differences: changed amounts upsert, cleared
existing budgets delete, untouched fields send nothing, applied
sequentially. On success the sheet closes and the month's data reloads. On
failure the month's data reloads immediately (so partially applied changes
are reflected truthfully), the sheet stays open with everything entered
still present, the diff baseline resets to the reloaded state (a retry never
re-sends an already-applied change), and an actionable error message is
shown.

#### Scenario: Batch save sends only the diff

- **WHEN** the user changes the overall budget, clears one existing category
  budget, leaves the rest untouched, and saves
- **THEN** exactly one upsert and one delete are sent, the sheet closes, and
  the budget card reflects the new state

#### Scenario: Partial failure stays truthful and retry-safe

- **WHEN** a batch save of one delete then one upsert fails on the upsert
- **THEN** the month reloads showing the delete already applied, the sheet
  stays open with the entered values and an actionable error, and retrying
  sends only the upsert (the applied delete is not re-sent)

### Requirement: Budgets load with the month race-safely

Budgets SHALL load together with the month's summary and transactions under
the existing stale-response guard: a slow budgets response for a previously
selected month SHALL never render under the currently selected month.

#### Scenario: Stale budget response is discarded

- **WHEN** the user switches months twice quickly and the first month's
  budgets arrive after the second's
- **THEN** the budget card shows the second month's progress only
