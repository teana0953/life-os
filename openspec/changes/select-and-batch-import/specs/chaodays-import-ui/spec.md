## ADDED Requirements

### Requirement: Choose which data types to import

The import screen SHALL let the user choose which of the data types to import, with all
types selected by default, and SHALL run only the selected ones. Unselected types SHALL be
left untouched and SHALL NOT be reported as failed. The import action SHALL be disabled when
no type is selected.

#### Scenario: All types are selected by default
- **WHEN** the user opens the import screen
- **THEN** every data type is selected

#### Scenario: Only the selected types are imported
- **WHEN** the user clears every type except one and submits a valid form
- **THEN** only that type runs, and the others stay in their not-attempted state rather than
  showing a result or a failure

#### Scenario: Importing nothing is not offered
- **WHEN** no data type is selected
- **THEN** the import action is disabled

#### Scenario: Selection cannot be changed mid-import
- **WHEN** an import is in progress
- **THEN** the type selection controls are disabled, like the other inputs on the screen

### Requirement: Long date ranges are imported in batches

A date range longer than the batch size SHALL be imported as several consecutive requests
covering the whole range, rather than as one request that the upstream server rejects. The
batches SHALL be contiguous and non-overlapping, together covering exactly the requested
range.

#### Scenario: A long range still imports
- **WHEN** the user imports a range longer than the batch size
- **THEN** the range is fetched in several consecutive batches and the type reports a single
  combined result

#### Scenario: A short range is a single batch
- **WHEN** the user imports a range within the batch size
- **THEN** it is fetched as one request, as before

#### Scenario: Batch progress is visible while a type runs
- **WHEN** a type with more than one batch is importing
- **THEN** that type shows which batch it is on out of how many

#### Scenario: A single-batch import does not show batch progress
- **WHEN** an importing type has only one batch
- **THEN** no batch counter is shown for it

### Requirement: A type's batches are reported as one result

Each data type SHALL report one combined result regardless of how many batches it took: the
imported and skipped counts SHALL be the totals across its batches, and a count that only
some batches carry SHALL reflect the batches that carried it rather than being lost.

#### Scenario: Counts are totalled across batches
- **WHEN** a type imports over several batches
- **THEN** it shows one result line whose imported and skipped counts cover the whole range

#### Scenario: A count present in only some batches survives
- **WHEN** a type imports over several batches and only some of them carry an
  additional count (for example glucose readings alongside meals)
- **THEN** that count is the total of the batches that carried it, not absent

### Requirement: A failed batch stops the import and keeps what was written

When a batch fails, the import SHALL stop rather than continue with the remaining batches and
types, and the data already written by earlier batches SHALL be kept.

#### Scenario: A mid-range failure stops the run
- **WHEN** a batch of some type fails
- **THEN** that type is reported as failed, the remaining batches and the not-yet-started
  types do not run, and the screen shows the corresponding error

#### Scenario: Re-running after a partial import is not destructive
- **WHEN** the user re-runs an import over a range whose earlier part already imported
  successfully
- **THEN** the already-imported days are reported as skipped rather than duplicated
