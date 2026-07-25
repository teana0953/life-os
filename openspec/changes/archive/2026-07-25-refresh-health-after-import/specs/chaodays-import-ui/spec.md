## ADDED Requirements

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
