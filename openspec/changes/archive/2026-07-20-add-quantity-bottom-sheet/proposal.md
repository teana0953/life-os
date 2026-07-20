# Quantity card as a bottom sheet

## Why

Adding several foods into a meal is still tedious: picking a dictionary item pushes
a **full-screen** quantity card (with its own app bar) that covers the dictionary,
so each food is a full-screen round trip — fill, save, pop back, pick again. The
dictionary keeps getting covered and restored. UX confirmed via mockup (b14ffccf):
open the quantity card as a bottom sheet instead, so the dictionary stays put and
adding several foods flows.

## What Changes

- **Quantity card opens as a bottom sheet** (`showModalBottomSheet`,
  `isScrollControlled`, keyboard-aware) instead of a pushed full-screen route,
  mirroring the existing edit-entry sheet. The dictionary stays visible above it.
- **The sheet drops the meal selection**: the meal is already set by the logging
  session (the logging bar / the per-meal add on Today), so the quantity card no
  longer shows meal chips or a snack-label field. The card is now: food name +
  basis + unit (bowl/gram) toggle + quantity stepper (tap-to-type kept) + portion
  preview + eaten-at time + an "add to <meal>" button.
- **Adding dismisses the sheet and keeps the dictionary**, firing the existing
  reload + "added to <meal>" snackbar, so the user picks the next food right away.
  The logging bar's "Done" still returns to Today.
- Manual entry stays full-screen for now (follow-up); the edit sheet is not merged
  with this one (each keeps its own).

## Impact

- Affected spec: `health-diet` — dictionary logging via a bottom-sheet quantity
  card whose meal comes from the session.
- Affected code: `diet_shell_screen.dart` (`_openLogEntry` → `showModalBottomSheet`),
  `quantity_card.dart` (remove meal chips + snack-label), `log_entry_screen.dart`
  (thin sheet body or removed). Frontend only.
