## ADDED Requirements

### Requirement: More overflow in the daily-log shell

The daily-log shell's bottom navigation SHALL offer four destinations — Today, Target, Water, and More — instead of a dedicated tab per tracker. Selecting More SHALL show a menu listing the overflow trackers (Bowel, Vitals, Exercise). Selecting a tracker from that menu SHALL open its screen for the shell's currently viewed day. The overflow trackers SHALL follow the shell's day navigation, so changing the viewed day updates them too. The Today, Target, and Water tabs SHALL remain directly reachable from the bottom navigation.

#### Scenario: The bottom navigation shows four destinations
- **WHEN** the user opens the daily-log shell
- **THEN** the bottom navigation shows exactly the Today, Target, Water, and More destinations

#### Scenario: The overflow trackers are reachable via More
- **WHEN** the user taps the More destination
- **THEN** a menu is shown listing the Bowel, Vitals, and Exercise trackers, each of which opens for the shell's currently viewed day when selected

### Requirement: Exercise tracker reached via More

The daily-log shell SHALL offer an exercise tracker via the More overflow menu, and selecting it SHALL show the exercise screen for the shell's currently viewed day. The exercise screen SHALL show the viewed day's exercise entries and their total duration, let the user append a new entry, and let the user remove any entry. Appending and removing SHALL take effect immediately (each persisted to the backend and the day re-read), rather than being staged behind a save control.

#### Scenario: The exercise tracker is reachable from More
- **WHEN** the user opens the More menu and selects the exercise tracker
- **THEN** the exercise screen is shown for the shell's currently viewed day

#### Scenario: An unrecorded day shows no entries and a zero total
- **WHEN** the user opens the exercise screen for a day with no entries
- **THEN** the screen shows no entries and a total duration of zero

### Requirement: Log an exercise entry

The exercise screen SHALL let the user append an entry by choosing an activity from the activity library, entering a duration in whole minutes greater than zero, and optionally a note. On appending, the entry SHALL be shown in the day's list and the total duration SHALL increase by the entry's duration. The duration input SHALL follow the numeric empty-zero convention (an empty field, not a literal 0). A duration that is not a positive whole number SHALL be prevented from being submitted.

#### Scenario: Appending an entry updates the list and total
- **WHEN** the user picks an activity, enters 30 minutes, and appends
- **THEN** the entry appears in the day's list and the total duration increases by 30 minutes

#### Scenario: Appending a second entry accumulates the total
- **WHEN** the day already has a 30-minute entry and the user appends a 20-minute entry
- **THEN** both entries are listed and the total duration is 50 minutes

#### Scenario: A non-positive duration cannot be submitted
- **WHEN** the user leaves the duration empty or enters 0
- **THEN** the entry cannot be appended

### Requirement: Remove an exercise entry

The exercise screen SHALL let the user remove any listed entry. On removal, the entry SHALL disappear from the day's list and the total duration SHALL decrease by that entry's duration.

#### Scenario: Removing an entry updates the list and total
- **WHEN** the day has a 30-minute entry and a 20-minute entry and the user removes the 30-minute one
- **THEN** only the 20-minute entry remains and the total duration is 20 minutes

### Requirement: Exercise API errors are surfaced without crashing

The exercise screen SHALL surface a load or save failure as an error state rather than crashing, and an authentication failure (401) SHALL surface a re-authentication exit consistent with the other trackers.

#### Scenario: A load failure shows an error state
- **WHEN** loading the day's exercise fails
- **THEN** the screen shows an error state rather than crashing
