# finance-networth-ui Specification

## Purpose
TBD - created by archiving change add-finance-networth-ui. Update Purpose after archive.
## Requirements
### Requirement: Shared month navigator

A reusable `MonthNavHeader` widget SHALL render a `‹ YYYY-MM ›` row that
invokes a callback with the previous or next month when its arrows are
tapped, accepting a key prefix so multiple instances on different screens
carry distinct test keys. The existing ledger overview month switcher SHALL
use this widget without changing its behavior or its existing test keys.

The month label SHALL additionally open a month picker when the caller
supplies a jump handler, so a distant month is reachable in one step instead
of repeated arrow taps. When no handler is supplied the label stays
non-interactive, so existing callers keep their behavior. The label's
identifying key SHALL remain on its `Text`, so existing tests that read the
label's text keep working.

#### Scenario: Arrows move between months

- **WHEN** the header shows 2026-07 and the user taps the next arrow
- **THEN** the callback fires with 2026-08

#### Scenario: Ledger month switching still works after refactor

- **WHEN** the ledger overview is shown and its month arrows are tapped
- **THEN** the month changes exactly as before (existing keys resolve)

#### Scenario: Tapping the label jumps to a distant month

- **WHEN** the finance month label is tapped and a month two years back is
  chosen
- **THEN** the screen loads that month's data directly, through the same
  month-change path the arrows use (its stale-response guard still applies)

### Requirement: Net worth tab

The finance shell SHALL offer a 淨值 tab showing, for the selected month:
the net worth as a headline figure, the month-over-month growth rate shown
with both a direction indicator and a percentage (never color alone), and
asset/liability accounts grouped with their current-month values, plus a
net-worth trend line over recent months. When the growth rate is null
(first recorded month or non-positive prior), only the net worth is shown,
without a growth figure. The tab SHALL reuse the existing loading, error
with retry, and re-auth handling. A month with no snapshots SHALL show a
guide to record the first value rather than a blank tab, and a trend with
fewer than two points SHALL show an insufficient-data note instead of an
empty chart.

#### Scenario: Net worth and growth display

- **WHEN** the selected month has assets summing 520000, liabilities 41484,
  and a prior net worth of 460181
- **THEN** the tab shows net worth 478516 and a positive growth indicator
  with a percentage of about 4%

#### Scenario: First month shows no growth figure

- **WHEN** the selected month is the first with any snapshot
- **THEN** the net worth is shown and no growth rate is displayed

#### Scenario: Empty month guides the user

- **WHEN** the selected month has no snapshots
- **THEN** a record-first guide appears rather than a blank tab

### Requirement: Snapshot entry and account management

Tapping an account row SHALL open a bottom sheet (padded above the keyboard)
to enter that account's value for the selected month as a non-negative TWD
integer; invalid input SHALL show an error and disable save (never silently
clear or corrupt), and an empty value means the month is unrecorded. Saving
SHALL upsert and refresh the month. The tab SHALL provide account management
to add an account (asset or liability with a name), rename, reorder, and
archive; archived accounts SHALL disappear from the current entry list while
their past snapshots keep counting toward historical net worth.

#### Scenario: Entering a value updates net worth

- **WHEN** the user taps an asset row, enters a value, and saves
- **THEN** the sheet closes and the net worth reflects the new value

#### Scenario: Invalid value is rejected, not silently cleared

- **WHEN** the user types a non-numeric or negative value
- **THEN** an error is shown and save is disabled, and no existing value is
  overwritten

#### Scenario: Archived account leaves the entry list but keeps history

- **WHEN** the user archives an account that has past snapshots
- **THEN** it no longer appears in the current-month entry list, and a past
  month's net worth that included it is unchanged

### Requirement: Net worth month loading is race-safe

The net worth tab SHALL load accounts, the month's figures, and the trend
together under a stale-response guard; a slow response for a previously
selected month SHALL never render under the currently selected month.

#### Scenario: Stale month response is discarded

- **WHEN** the user switches months twice quickly and the first month's
  response arrives after the second's
- **THEN** the tab shows the second month's net worth only

