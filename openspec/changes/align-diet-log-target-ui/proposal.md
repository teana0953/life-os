# Proposal: align-diet-log-target-ui

## Why

The Today screen was aligned to the design mockup, but the two other diet
screens — logging (dictionary + quantity card) and the daily target — still
diverge from it in presentation. This brings them in line: dictionary rows show
portions, the quantity card uses a unit toggle + stepper + preview with the
math, and the target screen is a carded layout with category icons, a bonus
note, and remaining bars. Presentation only — behavior and data flow unchanged.

## What Changes

- **Dictionary rows (`dictionary_screen.dart`)**: each row shows the food's
  portion pills (reusing `PortionPills`) and a heart favorite toggle; an explicit
  segmented "All / Favorites" tab replaces the implicit search-vs-favorites switch.
- **Quantity card (`quantity_card.dart`)**: show the dictionary basis (e.g.
  "1 碗 ＝ 主食 4"); replace the unit `Switch` with a segmented "碗 | 克" toggle
  (grams shown only when the item has base grams); replace the quantity text
  field with a −/+ stepper (0.5 step; grams stays a numeric field); the portion
  preview shows pills plus the "4 × 1.5" math.
- **Daily target (`daily_target_screen.dart`)**: a carded layout (a target card
  with the four category steppers + a "today / remaining" card); each stepper
  gets a category-color icon; a non-editable bonus note ("✳️ 運動後可加成份數");
  remaining shown as per-category bars (reusing `CategoryProgressBar`).

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `health-diet`: dictionary rows show portions + a favorites tab; the quantity
  card shows the basis, a unit toggle, a stepper, and a preview with the math;
  the daily target is a carded layout with category icons, a bonus note, and
  remaining bars. Behavior (search results, favorites, quantity math, preview
  numbers, target values, remaining) is unchanged.

## Impact

- **Modified**: `dictionary_screen.dart`, `quantity_card.dart`,
  `daily_target_screen.dart`; small reuse of `PortionPills`, `PortionStepper`,
  `CategoryProgressBar`; possible extra ARB keys (basis / bonus text); tests.
- **Backend**: none. **No behavior/data change.**
- **Out of scope**: no new data, request/response, or screens.
