# Add to each meal directly from Today

## Why

Adding a food is awkward: the Today meal cards are display-only, so to add
something the user taps a generic bottom FAB, is dropped onto the Dictionary tab,
and must re-pick the meal on the logging bar before choosing a food. The meal
cards are inert, it crosses tabs, and the meal must be re-selected. Users want to
add straight from the meal they're looking at. UX confirmed via mockup (963cb4c7).

## What Changes

- **Today shows breakfast/lunch/dinner as three fixed cards** (always visible, even
  when empty), each with a **"＋ add"** that starts logging into *that* meal — no
  tab hunt, no re-picking the meal. Empty meals show an empty state with the add
  affordance.
- **A snack area** collects the day's snack groups (the auto-numbered snacks and
  any renamed ones) with a **"＋ add snack"** that starts a new snack session.
- Tapping a meal's add takes the user to the dictionary with the current meal
  already set to that meal, reusing the existing logging bar + continuous logging
  + "added" snackbar; the generic bottom FAB is removed.
- **Unify the snack wording**: the meal-selection snack chip in the quantity card
  and manual-entry form uses "點心" (`dietSnackBaseName`) instead of "新增點心"
  (`dietAddSnack`) — a selection chip reads better as "Snack" than "Add snack".

## Impact

- Affected spec: `health-diet` — the Today log becomes fixed per-meal cards with a
  per-meal add and a snack area.
- Affected code: `today_screen.dart` (fixed cards + add affordances + snack area,
  remove FAB), `diet_shell_screen.dart` (wire add-to-meal / add-snack to the
  current-meal + tab switch), the snack chip label in `quantity_card.dart` /
  `portion_form_fields.dart`, ARB copy. Frontend only.
