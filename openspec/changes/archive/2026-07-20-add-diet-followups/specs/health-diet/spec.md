## ADDED Requirements

### Requirement: Manual entry in a bottom sheet

Manual food entry SHALL be presented in a bottom sheet (matching the other
add-food sheets) opened from the dictionary sheet, rather than a full-screen page.
Saving SHALL dismiss the sheet and show the localized "added" confirmation. The
entry's meal SHALL come from the current logging session, as with dictionary
logging.

#### Scenario: Manual entry opens as a sheet
- **WHEN** the user taps the manual-entry affordance in the dictionary sheet
- **THEN** the manual-entry form opens as a bottom sheet over the dictionary, and saving dismisses it with the "added" confirmation

### Requirement: Add to an existing snack group

Each snack group shown on the day SHALL offer a way to add another food into
**that** snack group (continuing it), distinct from starting a new snack. Using it
SHALL open the add-food flow with the meal set to that snack group's name, so
foods logged there join the same group without incrementing the snack number.

#### Scenario: Continue an existing snack
- **WHEN** the day has a snack group "點心2" and the user taps its "add to this snack" control
- **THEN** the add-food flow opens with the current meal set to "點心2" (not the next number), so the food joins that group

#### Scenario: New snack still increments
- **WHEN** the user instead uses the snack area's "add snack" control
- **THEN** the current meal is seeded to the next snack name (a new group)

### Requirement: Browse the dictionary from Today

Today SHALL offer a control to browse the food dictionary without logging: it opens
the dictionary in a browse-only bottom sheet with no logging bar and no meal
session — search, the food list, and favorite management only. In this mode
tapping a food SHALL NOT log it; the favorite toggle SHALL still work.

#### Scenario: Browse without logging
- **WHEN** the user opens the food dictionary from Today's header and taps a food row
- **THEN** the food is not logged (no quantity sheet opens), while its favorite toggle still works

#### Scenario: Browse mode has no logging bar
- **WHEN** the dictionary is opened in browse mode
- **THEN** it shows search, the list, and favorites but no meal/logging bar
