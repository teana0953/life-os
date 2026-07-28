## ADDED Requirements

### Requirement: Chaodays import screen offers a menstrual import

The chaodays import screen SHALL present a menstrual-period import type alongside the
existing ones, and importing SHALL include it in the same sequence against the entered
credentials and date range **when the user has selected it**. Its per-type row SHALL show
the same not-attempted / importing / success / failed states as the others, and on success
SHALL show its imported/skipped counts. The row SHALL reuse the existing import flow,
credentials handling, and error display (auth failure / unavailable) without a new screen
or dialog.

#### Scenario: The menstrual row is present and imports
- **WHEN** the user opens the chaodays import screen and runs an import with valid
  credentials and a date range
- **THEN** a menstrual row is shown alongside the other types and, on success, displays its
  imported/skipped counts

#### Scenario: Menstrual failure surfaces like the others
- **WHEN** the menstrual import fails with wrong credentials or an unavailable upstream
- **THEN** its row shows the same failure state/message as the other import types

#### Scenario: An unselected menstrual row does not run
- **WHEN** the user clears the menstrual checkbox and imports
- **THEN** no menstrual request is made and the row keeps whatever it was already showing
