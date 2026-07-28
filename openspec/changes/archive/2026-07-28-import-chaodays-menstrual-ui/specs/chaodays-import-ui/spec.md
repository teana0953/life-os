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

## MODIFIED Requirements

### Requirement: Import the selected types and show per-type results

Starting an import SHALL run the data-type imports the user has **selected** (weight/body-fat,
diet+glucose, water, bowel, diet target, menstrual periods) and show each type's progress and
result (imported and skipped counts). Types the user did not select SHALL NOT run; a type that
was not selected SHALL either keep the result it already had or, if the user just changed its
selection, show no state at all — it SHALL NOT be reported as attempted or failed.

#### Scenario: Per-type results are shown after a successful import
- **WHEN** the user submits a valid form and the imports succeed
- **THEN** each selected type shows its imported/skipped result

#### Scenario: Import shows progress while running
- **WHEN** an import is in progress
- **THEN** the import control shows a loading state and is not re-triggerable
