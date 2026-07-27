# chaodays-import-ui Specification

## Purpose
TBD - created by archiving change import-chaodays-ui. Update Purpose after archive.
## Requirements
### Requirement: Reach the import screen from the health module

The health module's 更多 (More) tab SHALL present an import entry that navigates to
the chaodays import screen.

#### Scenario: The More tab opens the import screen
- **WHEN** the user taps the import entry in the 更多 tab
- **THEN** the chaodays import screen opens

### Requirement: Import form gates on completeness

The import screen SHALL provide a chaodays account field, an obscured password
field, and start/end date pickers, and SHALL enable the import action only when the
account, password, and both dates are provided (with the end date not before the
start).

#### Scenario: The import button is disabled until the form is complete
- **WHEN** the account, password, or a date is missing
- **THEN** the import button is disabled
- **WHEN** all are provided with a valid range
- **THEN** the import button is enabled

### Requirement: Credentials are transient and errors are clear and recoverable

The chaodays password SHALL NOT be stored, and the screen SHALL say the credentials
are used only for this import. Failures SHALL surface localized, distinguishable
messages: wrong chaodays credentials, chaodays unreachable, and lifeos re-auth
required — not a single generic error.

#### Scenario: Wrong chaodays credentials show a specific message
- **WHEN** chaodays rejects the credentials (backend 400 chaodays_auth_failed)
- **THEN** the screen shows a "wrong chaodays account or password" message, and the user can correct and retry

#### Scenario: chaodays unreachable shows a distinct message
- **WHEN** the backend returns 502 chaodays_unavailable
- **THEN** the screen shows a "temporarily unavailable, try later" message, distinct from wrong-credentials

#### Scenario: A wrong-credentials abort does not mark the other types as failed
- **WHEN** the first import returns chaodays_auth_failed (so all types would fail identically)
- **THEN** the import aborts, showing the wrong-credentials message once, and the not-yet-run types are shown as not-attempted rather than as failed

#### Scenario: A lifeos session expiry prompts re-auth
- **WHEN** an import call returns lifeos 401
- **THEN** the screen shows a re-authenticate prompt rather than a chaodays error

#### Scenario: Credentials have no storage dependency
- **WHEN** the import controller and screen are constructed
- **THEN** they take no persistent-storage dependency (the password lives only in the form's in-memory field), so the password cannot be persisted

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

### Requirement: Health screens refresh after a chaodays import

The health screens SHALL show data written by a chaodays import without requiring an app
restart. When an import run finishes having imported at least one data type — including a
run that fails partway after importing some types — the health shell SHALL reload its
data so the overview, today, trackers, trends, and calendar reflect what was imported. An
import run in which no data type completed successfully SHALL NOT trigger a reload. The reload SHALL happen once
per import run, not once per imported type.

#### Scenario: The overview reflects an import without restarting
- **WHEN** the user completes a chaodays import and returns to the overview
- **THEN** the overview shows the imported data, without the user restarting the app

#### Scenario: A partially successful import still refreshes
- **WHEN** an import imports some types and then fails before finishing
- **THEN** the health screens still reload, because lifeos data has changed

#### Scenario: An import in which nothing succeeded does not reload
- **WHEN** an import fails before any data type completes successfully (for example wrong chaodays credentials)
- **THEN** no reload is triggered

#### Scenario: Refreshing does not blank the overview
- **WHEN** the health screens reload after an import while already showing data
- **THEN** the overview keeps showing its current cards while the new data loads, rather than collapsing or hiding them

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
- **THEN** only that type runs, and the types the user cleared show no state at all — clearing
  a type is what takes it out of the run, so a type left out on screen has necessarily been
  cleared first

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
- **THEN** each type's outcome (succeeded, failed, or not attempted by that run) stays shown on
  its row alongside its selection control, rather than being replaced by it

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

