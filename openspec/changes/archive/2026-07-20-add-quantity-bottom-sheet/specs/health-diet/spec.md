## MODIFIED Requirements

### Requirement: Log a food from the dictionary

The app SHALL let the user search the food dictionary, choose an item, enter an
amount as a decimal quantity of the item's unit, and save the entry into the
current logging session's meal. The item's amount SHALL be entered in a **bottom
sheet** that opens over the dictionary (the dictionary stays visible), rather than a
full-screen page; the meal SHALL be taken from the current session (set by the
logging bar or the per-meal add), so the amount sheet does not itself offer a meal
selection. Adding SHALL dismiss the sheet and leave the dictionary in place so the
user can pick another food into the same meal. When the chosen item has a base gram
weight, the user MAY instead enter the amount in grams; the app SHALL send the gram
amount to the backend for the item and SHALL NOT allow both a quantity and a gram
amount at once. Each dictionary row SHALL show the food's portions (as
category-colored pills) and a favorite toggle. The amount SHALL be adjusted with a
−/+ stepper for unit quantity (grams remains a numeric field), and the resulting
portions SHALL be previewed as pills.

#### Scenario: Search and log by quantity into the session meal
- **WHEN** the current meal is lunch and the user searches "飯", selects `飯/1碗`, enters quantity 1.5, and adds
- **THEN** the app creates the entry via the backend and it appears under lunch in the day's log

#### Scenario: Amount entered in a bottom sheet over the dictionary
- **WHEN** the user taps a dictionary item to log it
- **THEN** the quantity entry opens as a bottom sheet with the dictionary still visible, and adding dismisses the sheet without leaving the dictionary

#### Scenario: The amount sheet has no meal selection
- **WHEN** the quantity bottom sheet is open
- **THEN** it shows the amount, preview, time, and add controls but no meal chooser (the meal is the session's)

#### Scenario: Gram entry only for items with base grams
- **WHEN** the user selects an item that has no base gram weight
- **THEN** the amount input offers unit quantity only (no gram option)

#### Scenario: Dictionary row shows portions
- **WHEN** the dictionary lists `飯/1碗` (4 staple portions)
- **THEN** that row shows a "staple 4" portion pill
