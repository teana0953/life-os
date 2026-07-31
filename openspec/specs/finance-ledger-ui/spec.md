# finance-ledger-ui Specification

## Purpose
TBD - created by archiving change add-finance-ledger-ui. Update Purpose after archive.
## Requirements
### Requirement: Finance entry and shell

The home hub SHALL show a 財務 tile alongside the health tile that opens
`/finance`, a finance shell with its own two-destination bottom navigation
(總覽, 明細). The shell SHALL default to the current month and both tabs
SHALL reflect the same selected month.

#### Scenario: Entering finance from home

- **WHEN** an authenticated user taps the 財務 tile on the home hub
- **THEN** the finance shell opens on the 總覽 tab showing the current month

#### Scenario: Month selection is shared

- **WHEN** the user switches to the previous month on 總覽 and then opens 明細
- **THEN** 明細 lists that same previous month's transactions

### Requirement: Recording a transaction

Both tabs SHALL show a FAB that opens a record sheet as a modal bottom sheet
padded above the soft keyboard. The sheet SHALL offer: an amount field using
a numeric keyboard following the repo's empty-plus-hint zero convention, an
expense/income toggle that swaps the category grid accordingly, a category
grid from the user's categories, a date defaulting to today, a currency
selector from the supported whitelist defaulting to TWD, and an optional
note. The save button SHALL be disabled while the amount is empty or zero or
no category is chosen. On success the sheet closes and the visible month's
data refreshes; the new transaction appears without a manual reload. On
failure the sheet stays open with everything the user entered still present
and an actionable error message is shown.

#### Scenario: Fast default path

- **WHEN** the user opens the record sheet, types an amount, and picks a
  category without touching type, date, or currency
- **THEN** saving records a TWD expense dated today and the sheet closes
- **AND** the 總覽 totals and 明細 list include it immediately

#### Scenario: Save is gated on valid input

- **WHEN** the amount field is empty or 0, or no category is selected
- **THEN** the save button is disabled and no request is sent

#### Scenario: Failure keeps input

- **WHEN** saving fails (network or server error)
- **THEN** the sheet stays open, the entered amount/category/note remain, and
  an error message tells the user to retry

#### Scenario: Saving into another month jumps the view there

- **WHEN** the user is viewing July, opens the record sheet, sets the date to
  an August day, and saves
- **THEN** the view switches to August and the saved transaction is visible

#### Scenario: Expired session leads to re-auth, not a dead end

- **WHEN** any finance request returns 401
- **THEN** the finance screens show the sign-in-again exit (existing reauth
  convention), not a generic error page

### Requirement: Monthly overview

The 總覽 tab SHALL show, for the selected month: expense/income/net cards
listed per currency (one row per currency present, no conversion), a
category breakdown chart of expenses, and the five most recent
transactions. Amounts SHALL be formatted per currency minor-unit rules
(TWD/JPY/KRW no decimals; others two decimals). A month with no data SHALL
show an empty-state guide with a call-to-action that opens the record sheet
— never a blank page. While loading, a progress indicator is shown; on load
failure, an error state with a retry action.

#### Scenario: Overview reflects mixed currencies

- **WHEN** the selected month holds TWD and USD transactions
- **THEN** the totals show one TWD row and one USD row, each formatted with
  its own decimal rules, never summed together

#### Scenario: Empty month guides the user

- **WHEN** the selected month has no transactions
- **THEN** an empty-state message with a record call-to-action appears, and
  tapping it opens the record sheet

### Requirement: Transaction list and editing

The 明細 tab SHALL group the selected month's transactions by day, newest
day first, each row showing category, note (if any), and signed formatted
amount. Tapping a row SHALL open the same sheet pre-filled for editing,
including a delete action with confirmation. Edits and deletes SHALL refresh
the month's data on success.

#### Scenario: Editing an existing transaction

- **WHEN** the user taps a transaction, changes its amount, and saves
- **THEN** the list and 總覽 totals show the updated amount

#### Scenario: Deleting a transaction

- **WHEN** the user taps a transaction, chooses delete, and confirms
- **THEN** the transaction disappears from 明細 and the totals update

### Requirement: Month switching is race-safe

Month navigation (previous/next arrows) SHALL always render data belonging
to the displayed month: a slow response for a previously selected month
SHALL never overwrite the currently selected month's view.

#### Scenario: Rapid month switching

- **WHEN** the user switches months twice quickly and the first month's
  response arrives after the second's
- **THEN** the view shows the second (current) month's data, not the stale
  first response

