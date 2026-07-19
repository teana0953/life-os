# Continuous diet logging + snack auto-numbering

## Why

Logging several foods into the same meal is tedious today: picking a dictionary
item resets the meal to breakfast every time (`LogEntryController.start` hard-sets
`meal = 'breakfast'`), and after saving there's no feedback that it worked or hint
to keep going. Users also want repeated snacks to stay separate (an afternoon
snack vs a late-night one) without a fuzzy time rule. UX confirmed via mockup
(artifact cc127f9f).

## What Changes

- **Logging session with a current meal**: the dictionary screen gets a top bar
  "Logging to: <meal> | Done" with a meal switch (breakfast/lunch/dinner/snack).
  Picking a food defaults the quantity card to the current meal (not breakfast);
  saving keeps the current meal so the next pick stays in the same meal.
- **Save feedback**: saving shows a localized "Added to <meal>" snackbar and
  stays on the dictionary with the meal unchanged, so the user keeps picking.
  "Done" returns to Today.
- **Snack auto-numbering**: switching the current meal to snack defaults its name
  to the next snack in the day — first "點心", then "點心2", "點心3", … (based on
  the snack-series groups already in the day). A whole session's picks share that
  name (one group); the number only advances when you finish and start a new snack
  session. An edit affordance lets you rename it (e.g. "下午茶").
- No backend change — `meal` is free text; the frontend computes the name and
  uses the existing `POST /api/diet-entries`.

## Impact

- Affected spec: `health-diet` — new continuous-session + snack-numbering behavior.
- Affected code: `DietShellScreen` (current-meal state, done, snackbar, session
  wiring), a dictionary top-bar widget, `DictionaryScreen` (host the bar),
  `LogEntryController`/`ManualEntryController` `start` (accept the current meal),
  ARB copy. Frontend only.
