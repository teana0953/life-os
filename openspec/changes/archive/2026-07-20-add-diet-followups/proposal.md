# Diet UX follow-ups: manual-entry sheet, snack-group continue, browse dictionary

## Why

Three diet follow-ups carried from PR #22/#24/#25, all touching
`diet_shell_screen.dart` (so batched into one change):

- Manual entry is still a pushed full-screen page while every other add-food
  surface (quantity, edit, dictionary) is a bottom sheet — inconsistent.
- A snack group on Today can only be *added to* by starting a whole new snack
  (點心 → 點心2); there's no "add to this snack" to keep filling the current one.
- Removing the dictionary tab left no neutral way to just browse the dictionary /
  manage favorites (only reachable inside an add-food session).

## What Changes

- **Manual entry as a bottom sheet**: `_openManualEntry` opens
  `ManualEntryScreen` in a `showModalBottomSheet` (matching the shared diet-sheet
  style: drag handle + rounded corners + clip), as a second layer over the
  dictionary sheet, instead of a pushed full-screen route. The meal comes from the
  dictionary sheet's current meal (as `_openLogEntry` already does).
- **Add to an existing snack group**: each snack group card on Today gains an
  "add to this snack" control that opens the dictionary sheet seeded to that snack
  name (continue filling it), alongside the existing "＋ add snack" (new one).
- **Browse the dictionary from Today**: a "food dictionary" control in Today's
  header opens the dictionary sheet in a **browse-only** mode — no logging bar / no
  session; search + list + favorites only (and the manual-entry affordance is
  suppressed too, so there's no logging path). Tapping a food row does not log; the
  favorite toggle still works — logging stays via the per-meal add.

## Impact

- Affected spec: `health-diet` — manual entry via sheet, add-to-snack, browse-only
  dictionary.
- Affected code: `diet_shell_screen.dart` (manual-entry sheet, snack-group wiring,
  browse-only dictionary sheet + header entry), `today_screen.dart` (snack-group
  add control), `manual_entry_screen.dart` (sheet body), `dictionary_screen.dart`
  (browseOnly), ARB. Frontend only.
