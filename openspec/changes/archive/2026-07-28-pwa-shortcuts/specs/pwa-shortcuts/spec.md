## ADDED Requirements

### Requirement: Launcher shortcuts to the highest-traffic entries

The installed app SHALL declare launcher shortcuts for the entries the user reaches most
often — the food dictionary, logging a meal, logging blood glucose, and logging blood
pressure — so each is one press away instead of several screens deep.

#### Scenario: The shortcuts are declared
- **WHEN** the app's web manifest is served
- **THEN** it declares four shortcuts — food dictionary, log meal, log blood glucose, log blood pressure — each with a name, a short name suitable for a launcher label, and a URL

#### Scenario: A shortcut opens its destination directly
- **WHEN** the user activates a shortcut
- **THEN** the app opens at that shortcut's destination rather than at the home screen
- **NOTE** this one is backed by on-device verification, not an automated test — only a real install can show whether the launcher's URL survives a cold start

#### Scenario: The dictionary is reachable by URL alone
- **WHEN** the food-dictionary destination is opened from a URL, with none of the arguments an in-app navigation would carry
- **THEN** it opens the dictionary, supplying the viewed day and meal names itself, rather than redirecting back to the diet day

#### Scenario: The dictionary waits for the day's meal names
- **WHEN** the dictionary is opened from a URL before the day's record has loaded
- **THEN** it waits for that record before taking its snapshot of the meal names, so naming a new snack cannot collide with a snack the day already has

#### Scenario: A failed load leaves the dictionary recoverable
- **WHEN** the day's record fails to load while the dictionary is being opened from a URL
- **THEN** the screen shows that failure with a way forward, rather than spinning indefinitely

#### Scenario: The dictionary uses today's meal names even when the app was browsing another day
- **WHEN** the dictionary is opened from a URL while the app was showing an earlier day
- **THEN** it loads and uses today's meal names, since the shortcut records against today

#### Scenario: Returning from the dictionary shows what was just added
- **WHEN** the user adds a food from the URL-opened dictionary and goes back to the diet day
- **THEN** the diet day reflects that addition, rather than the record it held before

#### Scenario: Opening the dictionary by URL does not inherit an abandoned entry
- **WHEN** the dictionary is opened from a URL while an unfinished per-meal entry is still open in the app
- **THEN** the dictionary opens clean, as it does when reached from within the app

### Requirement: A vitals shortcut starts the reading it names

A vitals shortcut SHALL start a new reading of the kind it names and put the cursor in it, and
SHALL do so exactly once per arrival. (Blood glucose and blood pressure are recorded on the same
vitals screen, so a shortcut that merely opened that screen would be indistinguishable between
the two.)

#### Scenario: The glucose shortcut starts a glucose reading
- **WHEN** the user arrives from the blood-glucose shortcut
- **THEN** the vitals screen opens with a new, empty glucose reading already added and focused for typing

#### Scenario: The blood-pressure shortcut starts a blood-pressure reading
- **WHEN** the user arrives from the blood-pressure shortcut
- **THEN** the vitals screen opens with a new, empty blood-pressure reading already added and focused for typing

#### Scenario: Arriving without a shortcut adds nothing
- **WHEN** the user opens the vitals screen the ordinary way
- **THEN** no reading is added automatically — the screen behaves exactly as before

#### Scenario: Arriving when the day is already loaded still adds the reading
- **WHEN** the user activates a vitals shortcut while the app is already open and the day's record has long since loaded
- **THEN** the reading is still added — waiting for a change notification that will never come would leave the shortcut doing nothing in what is the common case for an already-running app

#### Scenario: The reading survives the screen's initial load
- **WHEN** the user arrives from a vitals shortcut while the day's record is still loading
- **THEN** the reading is added once loading completes and is still there afterwards — it is not added into a screen that is about to be overwritten by the arriving record

#### Scenario: The focused field is the one the user came to type in
- **WHEN** a vitals shortcut adds its reading
- **THEN** the cursor lands on the value the shortcut is named for — the systolic field for blood pressure, the glucose *value* rather than its free-text label

#### Scenario: Switching from one vitals shortcut to the other while the screen is open
- **WHEN** the user is on the vitals screen from one shortcut and activates the other one
- **THEN** a reading of the newly named kind is added, and the first kind's reading is not added again — the two shortcuts land on the same screen, so nothing else would distinguish them

#### Scenario: Activating the same shortcut again adds nothing
- **WHEN** the user activates the shortcut they already arrived from
- **THEN** no further reading is added, so repeated taps cannot pile up blank rows

#### Scenario: An unrecognised kind adds nothing
- **WHEN** the vitals screen is opened with a reading kind it does not recognise
- **THEN** nothing is added and nothing fails — the screen behaves as an ordinary visit

#### Scenario: Rebuilding the screen does not add more readings
- **WHEN** the screen rebuilds after arriving from a shortcut (typing, keyboard, rotation, or any other state change)
- **THEN** no further reading is added — the shortcut's intent is consumed once, so the user never finds a pile of blank rows
