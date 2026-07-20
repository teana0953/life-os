## ADDED Requirements

### Requirement: Add food via a dictionary bottom sheet

Adding food into a meal SHALL happen in a bottom sheet over the Today view rather
than a separate tab. Tapping a meal's add (or the add-snack control) SHALL open a
sheet containing the logging bar (the current meal with a meal switch and a Done
control) and the food dictionary (search, favorites, list), with the current meal
set to that meal (or the next snack). Picking a food SHALL open the quantity entry
as a second sheet over the dictionary sheet; adding SHALL dismiss that quantity
sheet back to the dictionary sheet so the user can pick another food, and SHALL
show the localized "added" confirmation. The Done control SHALL dismiss the
dictionary sheet back to Today. The bottom navigation SHALL NOT include a
dictionary tab — the dictionary is reachable only as this add-food sheet.

#### Scenario: A meal's add opens the dictionary sheet
- **WHEN** the user taps the add control on the lunch card
- **THEN** a bottom sheet opens over Today showing the logging bar (set to lunch) and the dictionary, without switching to a separate tab

#### Scenario: Pick and add, then keep picking
- **WHEN** the user picks a food in the dictionary sheet, sets an amount, and adds
- **THEN** the quantity sheet dismisses back to the dictionary sheet with an "added" confirmation, and the user can pick another food into the same meal

#### Scenario: Done returns to Today
- **WHEN** the user taps Done on the dictionary sheet's logging bar
- **THEN** the dictionary sheet dismisses and the Today view is shown

#### Scenario: No dictionary tab
- **WHEN** the user looks at the bottom navigation
- **THEN** it shows only Today and Target, with no dictionary tab

### Requirement: Return to home from the diet module

The diet module SHALL offer a visible control to return to the home "your spaces"
screen, since the module is opened from home. Activating it SHALL return to home.

#### Scenario: Home button returns to home
- **WHEN** the user taps the home control in the Today header
- **THEN** the app returns to the home "your spaces" screen
