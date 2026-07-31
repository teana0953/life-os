## MODIFIED Requirements

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


The month switcher within the 總覽 tab SHALL be rendered by the shared
`MonthNavHeader` widget (keyPrefix `finance-month`), preserving the existing
behavior and test keys.

#### Scenario: Month switcher uses the shared header

- **WHEN** the 總覽 tab renders its month switcher
- **THEN** it is the shared MonthNavHeader and its existing month-change
  behavior is unchanged
