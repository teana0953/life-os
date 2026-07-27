## ADDED Requirements

### Requirement: The type selection precedes the action it drives

The import screen SHALL present the type selection before the control that starts the
import, under a heading that names the group, so that the effect of the selection on the
import action is on the same reading path.

#### Scenario: Selection comes before the submit control
- **WHEN** the user reads down the import screen
- **THEN** the type selection appears above the control that starts the import

#### Scenario: The selection group is named
- **WHEN** the user looks at the type selection
- **THEN** it carries a heading identifying what the group is for

### Requirement: A per-type result is cleared only when that type is disturbed

A type's result SHALL persist until that type is either re-selected/deselected or included in
a new run. Changing one type's selection SHALL NOT clear another type's result, and starting a
run SHALL NOT clear the results of types it will not import.

#### Scenario: Toggling a type clears that type's result only
- **WHEN** a run has finished and the user changes one type's selection
- **THEN** that type's result and status are cleared, and the other types keep theirs

#### Scenario: Re-running one type leaves the other results standing
- **WHEN** the user runs an import with only some types selected
- **THEN** only the selected types are reset for the new run, and the unselected types keep
  the results they already had

### Requirement: The status slot carries information or nothing

The per-type status indicator SHALL be shown only once it has something to report. Before any
import has run it SHALL be absent, without changing the row's layout when it later appears.

#### Scenario: No status is shown before the first run
- **WHEN** the user opens the import screen and has not started an import
- **THEN** no per-type status indicator is shown

#### Scenario: A skipped type still reports that it was skipped
- **WHEN** a run finishes without reaching some type
- **THEN** that type shows a not-attempted indicator, distinguishing it from a type that ran

#### Scenario: The row does not shift when the status appears
- **WHEN** the first import starts and status indicators appear
- **THEN** the type labels stay in place horizontally

### Requirement: Import status is available without sight

Each per-type status SHALL have a non-visual description, so that progress and outcome are
available to a screen reader rather than carried by the icon alone.

#### Scenario: A running type announces itself
- **WHEN** a type is being imported
- **THEN** its status is described in the row's accessibility information

#### Scenario: An outcome announces itself
- **WHEN** a type has finished successfully or failed
- **THEN** that outcome is described in the row's accessibility information
