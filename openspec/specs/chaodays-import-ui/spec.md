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

### Requirement: Import all four types and show per-type results

Starting an import SHALL run the four data-type imports (weight/body-fat, diet+glucose,
water, bowel) and show each type's progress and result (imported and skipped counts).

#### Scenario: Per-type results are shown after a successful import
- **WHEN** the user submits a valid form and the imports succeed
- **THEN** each of the four types shows its imported/skipped result

#### Scenario: Import shows progress while running
- **WHEN** an import is in progress
- **THEN** the import control shows a loading state and is not re-triggerable

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
against the entered credentials and date range. Its per-type row SHALL show the same
not-attempted / importing / success / failed states as the others, and on success
SHALL show the imported/skipped counts for the daily portion targets and the water
target. The row SHALL reuse the existing import flow, credentials handling, and
error display (auth failure / unavailable) without a new screen or dialog.

#### Scenario: The diet-target row is present and imports
- **WHEN** the user opens the chaodays import screen and runs an import with valid credentials and a date range
- **THEN** a "diet target" row is shown alongside the other types and, on success, displays its imported/skipped counts (portion targets, and the water target)

#### Scenario: Diet-target failure surfaces like the others
- **WHEN** the diet-target import fails with wrong credentials or an unavailable upstream
- **THEN** its row shows the same failure state/message as the other import types

