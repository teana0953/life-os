## RENAMED Requirements

- FROM: `### Requirement: Import all four types and show per-type results`
- TO: `### Requirement: Import the selected types and show per-type results`

## MODIFIED Requirements

### Requirement: Import the selected types and show per-type results

Starting an import SHALL run the data-type imports the user has **selected** (weight/body-fat,
diet+glucose, water, bowel, diet target) and show each type's progress and result (imported and
skipped counts). Types the user did not select SHALL NOT run and SHALL stay in their
not-attempted state.

#### Scenario: Per-type results are shown after a successful import
- **WHEN** the user submits a valid form and the imports succeed
- **THEN** each selected type shows its imported/skipped result

#### Scenario: Import shows progress while running
- **WHEN** an import is in progress
- **THEN** the import control shows a loading state and is not re-triggerable

### Requirement: Chaodays import screen offers a diet-target import

The chaodays import screen SHALL present a "diet target" import type in addition to
weight, diet, water, and bowel, and importing SHALL include it in the same sequence
against the entered credentials and date range **when the user has selected it**. Its
per-type row SHALL show the same not-attempted / importing / success / failed states as the
others, and on success SHALL show the imported/skipped counts for the daily portion targets
and the water target. The row SHALL reuse the existing import flow, credentials handling,
and error display (auth failure / unavailable) without a new screen or dialog.

#### Scenario: The diet-target row is present and imports
- **WHEN** the user opens the chaodays import screen and runs an import with valid credentials and a date range
- **THEN** a "diet target" row is shown alongside the other types and, on success, displays its imported/skipped counts (portion targets, and the water target)

#### Scenario: Diet-target failure surfaces like the others
- **WHEN** the diet-target import fails with wrong credentials or an unavailable upstream
- **THEN** its row shows the same failure state/message as the other import types

## ADDED Requirements

### Requirement: Choose which data types to import

The import screen SHALL let the user choose which data types to import, with every type
selected by default so that an unchanged form behaves exactly as it does today. The import
action SHALL be unavailable when no type is selected. Each type's selection control and each
type's import state SHALL be shown at the same time, in separate places on that type's row, so
neither has to give way to the other.

#### Scenario: All types are selected by default
- **WHEN** the user opens the import screen
- **THEN** every data type is selected

#### Scenario: Only the selected types are imported
- **WHEN** the user clears every type except one and submits a valid form
- **THEN** only that type runs, and the others show neither a result nor a failure

#### Scenario: Importing nothing is not offered
- **WHEN** no data type is selected
- **THEN** the import action is disabled

#### Scenario: Selection cannot be changed mid-import
- **WHEN** an import is in progress
- **THEN** the selection controls are still shown, but disabled — neither the control nor its
  row responds to a tap — so the selection cannot change while the run it drives is under way

#### Scenario: Types left out of a running import are distinguishable
- **WHEN** an import is in progress and some types were not selected
- **THEN** the left-out rows read as unselected while the selected types that have not started
  yet read as selected, so "this one will not run" is not mistaken for "this one is still
  queued"

#### Scenario: Each type's import state stays visible after the run
- **WHEN** an import has finished — whether every type succeeded, or the run stopped early on a
  failure
- **THEN** each type's outcome (succeeded, failed, or never attempted) stays shown on its row
  alongside its selection control, rather than being replaced by it

#### Scenario: The selection can be changed after a run without leaving the screen
- **WHEN** an import has finished — whether every type succeeded, or the run stopped early
  on a failure — and the user wants to run a different selection
- **THEN** the type selection controls are editable again on the same screen, so the user can
  adjust the selection and re-run without navigating away

#### Scenario: The selection is remembered after a run
- **WHEN** an import has finished
- **THEN** the selection is still the one the user submitted, not reset back to every type

#### Scenario: Starting a run clears every type's previous result
- **WHEN** the user starts a new import
- **THEN** every type's result from the previous run is cleared, including the results of types
  this run does not include
