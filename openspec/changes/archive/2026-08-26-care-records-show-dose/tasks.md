## 1. i18n

- [x] 1.1 Add `careDoseQuantityValue` (`×{quantity}`, `String` placeholder, with a
  `description`) to `lib/l10n/app_en.arb` and its Traditional Chinese value to
  `lib/l10n/app_zh_Hant.arb` — verify `flutter gen-l10n` succeeds and both locales define the key
- [x] 1.2 Regenerate and commit `lib/l10n/generated/` — verify `git status` shows the generated
  files updated and `flutter analyze` is clean
- [x] 1.3 (Added at ship-gate review, design D8) Add `careDoseSemanticLabel` (`Dose: {label}` /
  `劑量:{label}`, `String` placeholder) to `lib/l10n/app_en.arb` and `lib/l10n/app_zh_Hant.arb`,
  so a screen reader announces the `×N` glyph rather than reading it as a bare digit — verify
  `flutter gen-l10n` succeeds

## 2. Shared formatter

- [x] 2.1 Add `careDoseLabel(AppLocalizations loc, CareCategory category, double doseQuantity,
  String? dose)` in the new `lib/contexts/notifications/presentation/care_dose_label.dart`,
  returning `''` for any non-medication `category` (design D7, reversed from the original
  "always show" plan — see design.md), and otherwise `×N · <dose>` when `dose` is
  non-null/non-empty and `×N` alone, with a whole-number quantity rendered without its `.0`
  (design D1–D5) — verify `flutter analyze` is clean
- [x] 2.2 Add `test/contexts/notifications/presentation/care_dose_label_test.dart` covering
  quantity with dose, quantity without dose, empty-string dose, whole-number quantity
  (`×2`, not `×2.0`), fractional quantity (`×0.5`), and a non-medication category returning
  `''` regardless of quantity/dose, asserting against `lookupAppLocalizations(...)` rather than
  hard-coded strings — verify the file's tests pass

## 3. Care history screen

- [x] 3.1 Append the dose label (medication-only, via `careDoseLabel`'s `category` argument) to
  each slot row's subtitle in
  `lib/contexts/notifications/presentation/care_history_screen.dart`, wrapped in
  `Semantics(label: loc.careDoseSemanticLabel(...))` + `ExcludeSemantics` — verify the screen
  still builds and `flutter analyze` is clean
- [x] 3.2 Extend `test/contexts/notifications/presentation/care_history_screen_test.dart` with
  cases asserting the slot row shows the dose (with and without a free-text `dose`) for
  medication and shows no dose line for a non-medication slot, using `lookupAppLocalizations` —
  verify the file's tests pass

## 4. Care reminders (items) screen

- [x] 4.1 In `lib/contexts/notifications/presentation/care_items_screen.dart`, append each
  medication schedule's `×N` to its schedule summary line (via the new `_scheduleLine` widget
  wrapping `_scheduleSummary`, so a combined semantic label can cover the whole line) and render
  a medication item's free-text `dose` as its own row under the schedules, with `maxLines: 1` /
  ellipsis, matching `item.note`'s pattern (design D6, D7) — verify `flutter analyze` is clean
- [x] 4.2 Extend `test/contexts/notifications/presentation/care_items_screen_test.dart` with
  cases asserting the per-schedule quantity appears on each medication schedule line and not on
  a non-medication schedule line, and the item `dose` appears on its own line for a medication
  and not for a non-medication item — verify the file's tests pass

## 5. Today care screen and overview summary card

- [x] 5.1 Replace the `dose`-only line in
  `lib/contexts/notifications/presentation/care_today_screen.dart` with `careDoseLabel`,
  passing the slot's category so a non-medication slot keeps showing no dose line (design D7,
  reversed from the original "drop the hide-when-empty condition for everyone" plan) — verify
  `flutter analyze` is clean
- [x] 5.1a (Scope grew at implementation — see design.md "Deviations") Apply the same
  replacement to `_SlotRow` (the pending-queue row) and `_DoneGroup` (the completed row) in
  `care_today_screen.dart`, not only the focus card originally named — verify `flutter analyze`
  is clean
- [x] 5.2 Same replacement in
  `lib/contexts/notifications/presentation/care_today_summary_card.dart` — verify `flutter
  analyze` is clean
- [x] 5.3 Extend `test/contexts/notifications/presentation/care_today_screen_test.dart` and
  `test/contexts/notifications/presentation/care_today_summary_card_test.dart` with cases
  asserting the merged label for medication (including a slot with a quantity but no free-text
  dose still showing a dose line) and no dose line at all for non-medication, across the
  pending-queue row, focus card, and done group — verify both files' tests pass

## 6. Verification

- [x] 6.1 Run `flutter analyze` and `flutter test` on the whole repo — verify both are clean,
  including care tests not touched by this change
- [x] 6.2 Confirm no file under `lib/contexts/notifications/domain/`,
  `application/`, or `infrastructure/` was modified — verify with `git diff --name-only`
