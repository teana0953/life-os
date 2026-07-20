# Food dictionary in a bottom sheet + remove the dictionary tab

## Why

Adding a food still crosses a tab: tapping a meal's add on Today switches to the
Dictionary tab (leaving Today), then the food is picked and the quantity sheet
opens. That mid-flow tab switch is a context break. And the diet module is pushed
from home yet has no visible way back — only the OS back gesture. UX confirmed via
mockup (c1081bc1).

## What Changes

- **The dictionary opens as a bottom sheet** over Today, not a tab: a meal's add
  (or add-snack) opens a tall sheet containing the logging bar (meal switch +
  Done) and the dictionary (search / favorites / list). Picking a food opens the
  existing quantity bottom sheet as a second layer over it; adding dismisses that
  layer back to the dictionary sheet so the user keeps picking. "Done" dismisses
  the dictionary sheet back to Today. Everything stays a floating layer over
  Today — no tab switch.
- **The dictionary tab is removed**: the bottom navigation drops to Today / Target
  (two tabs); the dictionary lives only as the add-food sheet.
- **Today gains a home button** in its header to return to the home "your spaces"
  screen (the module is pushed from home; today it can only be left via the OS
  back gesture).
- Manual entry keeps its current full-screen flow, reachable from the dictionary
  sheet (follow-up: possibly a sheet later).

## Impact

- Affected spec: `health-diet` — dictionary logging via a bottom sheet, two-tab
  nav, a home affordance.
- Affected code: `diet_shell_screen.dart` (nav 3→2, add-to-meal/add-snack open the
  dictionary sheet, the logging bar + dictionary move into a stateful sheet, Done
  pops it), `today_screen.dart` (home button), ARB. Frontend only.
