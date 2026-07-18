# Proposal: refine-diet-visuals

## Why

The diet module is functionally complete but the shipped UI diverges from the
reviewed mockup in its presentation. This change brings the visuals in line —
no behavior or data-flow changes, only how things are rendered and adjusted.

## What Changes

- **Today per-category progress → horizontal bars**: replace the numeric
  category chips with per-category progress bars (rounded track + category-color
  fill = logged / effective, capped when over) with the "used / target" numbers
  alongside — mockup screen ①.
- **Meal groups → cards with time**: replace the plain meal-title text with meal
  cards in the Chiikawa card style (rounded + 2px outline + ledge shadow), each
  with an emoji for the standard meals (🌅/🍱/🌙, 🍎 for snacks) and the meal's
  earliest eaten-at time.
- **Daily target → +/− steppers**: replace the target text fields with
  increment/decrement steppers per category (decimals allowed), updating the same
  controller draft.
- **Dictionary search debounce**: debounce the search (~300 ms) so typing no
  longer fires one request per keystroke.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `health-diet`: Today shows per-category progress as bars and each meal group
  with its time; the daily target is adjusted via steppers; dictionary search is
  debounced. Behavior (progress numbers, eaten-order, target values, search
  results) is unchanged — presentation and interaction only.

## Impact

- **Modified**: `today_screen.dart` (progress bars + meal cards), `daily_target_screen.dart`
  (steppers), `dictionary_controller.dart` (debounce), new ARB keys if needed,
  tests. Reuses `DietCategoryColors` + `ledgeShadow`.
- **Backend**: none.
- **Out of scope**: no new data, no changed request/response, no new screens.
