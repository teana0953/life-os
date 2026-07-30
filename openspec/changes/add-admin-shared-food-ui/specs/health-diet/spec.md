## ADDED Requirements

### Requirement: Administrator entry points in the food dictionary

The app SHALL show dictionary-editing entry points only to a user the backend
reports as an administrator. On the food search surface, an administrator SHALL see
a per-row secondary action on **shared** items (items with no owner) that opens an
edit form, and a screen-level action that opens an empty create form. A
non-administrator SHALL see neither, and an administrator SHALL see no per-row
action on another user's custom item. The row's primary action — adding the food to
the meal tray — SHALL be unchanged for everyone.

While the profile has not loaded yet, the entry points SHALL be absent rather than
shown in a disabled or placeholder state.

#### Scenario: Administrator sees the edit action on a shared item
- **WHEN** an administrator searches the dictionary and a shared item appears in the results
- **THEN** that row offers an edit action alongside the favorite control, and tapping the row still adds the food to the tray

#### Scenario: Non-administrator sees the row unchanged
- **WHEN** a non-administrator searches the dictionary
- **THEN** no row offers an edit action and no create action is available on the screen

#### Scenario: A custom item offers no edit action
- **WHEN** an administrator's search results include their own custom item
- **THEN** that row offers no edit action

#### Scenario: Entry points are absent until the profile is known
- **WHEN** the dictionary is opened directly (for example from a launcher shortcut) before the profile has loaded
- **THEN** no administrator entry point is shown, and it appears once the profile reports administrator status

### Requirement: Create and edit a shared dictionary item

An administrator SHALL be able to create a shared dictionary item and to correct an
existing one through the same form, which SHALL carry the item's name, its four
food-group portions, its six atomic nutrients, and its measure basis. When editing,
the form SHALL open prefilled with the item's current values and SHALL submit only
the fields the administrator changed. On success the form SHALL close, the user
SHALL be told it succeeded, and the visible list SHALL reflect the change without a
manual refresh.

#### Scenario: Editing changes only what was touched
- **WHEN** an administrator opens the edit form for a shared item, changes its name and one nutrient, and submits
- **THEN** the item's name and that nutrient change, its other values are untouched, and the updated item is visible in the list

#### Scenario: Creating a shared item
- **WHEN** an administrator submits the create form with a name and values
- **THEN** the item is created as a shared item and a subsequent search finds it

#### Scenario: Submission in progress
- **WHEN** the administrator submits the form
- **THEN** the submit control is busy and cannot be triggered again, and the entered values remain visible

### Requirement: The dictionary form validates before submitting and keeps input on failure

The form SHALL reject a measure basis that is half-filled (an amount without a unit,
or a unit without an amount) and an amount that is not greater than zero, SHALL
explain next to the offending field what to change, and SHALL NOT submit. When a
submission fails for any reason, the form SHALL stay open with everything the
administrator entered still present.

#### Scenario: Half-filled measure basis is refused locally
- **WHEN** an administrator fills in a measure amount but leaves the unit empty and submits
- **THEN** the form stays open, an error next to the measure fields says the amount and unit must be given together or both left empty, and nothing is sent

#### Scenario: Non-positive measure amount is refused locally
- **WHEN** an administrator enters a measure amount of zero or less and submits
- **THEN** the form stays open with an error explaining the amount must be greater than zero, and nothing is sent

#### Scenario: Failed submission preserves the entered values
- **WHEN** a submission fails because the request could not be completed
- **THEN** the form stays open, shows a retryable error, and every entered value is still there

#### Scenario: Permission refused is reported as a permission problem
- **WHEN** the backend refuses the request because the user is not an administrator
- **THEN** the message says the user does not have permission, distinct from a generic try-again error
