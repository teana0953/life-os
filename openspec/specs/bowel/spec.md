# bowel Specification

## Purpose
TBD - created by archiving change bowel-ui. Update Purpose after archive.
## Requirements
### Requirement: Bowel tab in the daily-log shell

The daily-log shell SHALL offer a bowel tab in its bottom navigation alongside the Today, Target, and Water tabs, and selecting it SHALL show the bowel screen for the shell's currently viewed day. The bowel tab SHALL follow the shell's day navigation, so changing the viewed day updates the bowel screen too.

#### Scenario: The bowel tab is reachable from the daily-log shell
- **WHEN** the user opens the daily-log shell and taps the bowel destination in the bottom navigation
- **THEN** the bowel screen is shown for the shell's currently viewed day, and the Today, Target, and Water tabs remain reachable

### Requirement: Record the day's bowel movements

The bowel screen SHALL let the user record, for the viewed day, a count of bowel movements, whether the day was normal or abnormal, and a free-text note, then save them together. The count SHALL be adjustable and SHALL not go below zero. The normal/abnormal choice SHALL be optional — nothing SHALL be pre-selected until the user picks one (an unrecorded day is not treated as normal). Saving SHALL upsert the whole day's record; while saving the save control SHALL be disabled, and a save failure SHALL be surfaced to the user without losing the entered values.

#### Scenario: Entering and saving a day's record
- **WHEN** the user sets the count to 2, picks normal, types a note, and taps save
- **THEN** the day's record is saved with count 2, normal, and that note

#### Scenario: The count does not go below zero
- **WHEN** the count is 0 and the user taps the decrement control
- **THEN** the count stays 0

#### Scenario: Normal/abnormal starts unselected
- **WHEN** the user opens the bowel screen for a day with no recorded flag
- **THEN** neither normal nor abnormal is pre-selected

#### Scenario: A save failure is surfaced
- **WHEN** saving the day's record fails
- **THEN** the user is shown a failure message and the entered count, flag, and note are still present

