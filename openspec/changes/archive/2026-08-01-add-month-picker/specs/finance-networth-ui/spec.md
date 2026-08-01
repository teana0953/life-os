## MODIFIED Requirements

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
