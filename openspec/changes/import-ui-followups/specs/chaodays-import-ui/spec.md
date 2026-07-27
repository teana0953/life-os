## MODIFIED Requirements

### Requirement: Choose which data types to import

The import screen SHALL let the user choose which data types to import, with every type
selected by default so that an unchanged form behaves exactly as it does today. The import
action SHALL be unavailable when no type is selected. Each type's selection control and each
type's import state SHALL be shown at the same time, in separate places on that type's row, so
neither has to give way to the other. The selection SHALL be presented before the control that
starts the import, under a heading naming the group.

#### Scenario: All types are selected by default
- **WHEN** the user opens the import screen
- **THEN** every data type is selected

#### Scenario: Only the selected types are imported
- **WHEN** the user clears every type except one and submits a valid form
- **THEN** only that type runs; the others are not attempted, and each either keeps the result
  it already had or, if the user just changed its selection, shows no state at all

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

#### Scenario: Selection comes before the submit control
- **WHEN** the user reads down the import screen
- **THEN** the type selection appears above the control that starts the import, under a
  heading identifying what the group is for

#### Scenario: Starting a run clears the results of the types it will import
- **WHEN** the user starts a new import
- **THEN** the results of the types this run includes are cleared, and the types it does not
  include keep the results they already had

#### Scenario: Toggling a type clears that type's result only
- **WHEN** a run has finished and the user changes one type's selection
- **THEN** that type's result and status are cleared, and the other types keep theirs

### Requirement: Import the selected types and show per-type results

Starting an import SHALL run the data-type imports the user has **selected** (weight/body-fat,
diet+glucose, water, bowel, diet target) and show each type's progress and result (imported and
skipped counts). Types the user did not select SHALL NOT run; a type that was not selected
SHALL either keep the result it already had or, if the user just changed its selection, show
no state at all — it SHALL NOT be reported as attempted or failed.

#### Scenario: Per-type results are shown after a successful import
- **WHEN** the user submits a valid form and the imports succeed
- **THEN** each selected type shows its imported/skipped result

#### Scenario: Import shows progress while running
- **WHEN** an import is in progress
- **THEN** the import control shows a loading state and is not re-triggerable

## ADDED Requirements

### Requirement: The status slot carries information or nothing

A type's status indicator SHALL be shown only when it has something to report — that is, once
that type has taken part in a run and has not since been disturbed. A type that has never run,
or whose result was just cleared, SHALL show no indicator, and its appearance or disappearance
SHALL NOT move the row's other content.

#### Scenario: No status is shown before the first run
- **WHEN** the user opens the import screen and has not started an import
- **THEN** no per-type status indicator is shown

#### Scenario: A type skipped by a run still reports that it was skipped
- **WHEN** a run stops early without reaching some selected type
- **THEN** that type shows a not-attempted indicator, distinguishing it from a type that has
  never run

#### Scenario: A cleared type shows no indicator again
- **WHEN** the user changes the selection of a type that had a result
- **THEN** that type shows no status indicator, as if it had never run

#### Scenario: The row does not shift when the status appears
- **WHEN** a status indicator appears on a row that had none
- **THEN** the type label stays in place horizontally

### Requirement: Import status is available without sight

Each per-type status SHALL have a non-visual description, so that progress and outcome are
available to a screen reader rather than being carried by the icon alone.

#### Scenario: A running type announces itself
- **WHEN** a type is being imported
- **THEN** its status is described in the row's accessibility information

#### Scenario: An outcome announces itself
- **WHEN** a type has finished successfully or failed
- **THEN** that outcome is described in the row's accessibility information
