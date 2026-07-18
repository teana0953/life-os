# Tasks: refine-diet-visuals

## 1. Category progress bars (widget tests)

- [x] 1.1 A `CategoryProgressBar` widget: label + rounded track + category-color fill (`clamp(logged/effective, 0, 1)`; effective 0 → empty; over-target → full) + "used / target" numbers; colors from `DietCategoryColors`. Widget test: 9 of 12 → bar ~3/4 filled; over-target → full; effective 0 → empty, no divide-by-zero
- [x] 1.2 Replace `_CategoryProgress`/`_CategoryProgressRow` in `today_screen.dart` with `CategoryProgressBar` (one per category); update Today widget tests (progress still reads "9 of 12")

## 2. Meal cards with emoji + time

- [x] 2.1 A meal-emoji helper (breakfast 🌅, lunch 🍱, dinner 🌙, snack 🍎) and a localized `HH:mm` formatter for the group's earliest eaten-at time — computed as `min` of the group's `eatenAt` (not `entries.first`) and `.toLocal()` before formatting (eatenAt is UTC) — via `intl`
- [x] 2.2 Render each meal group in `today_screen.dart` as a themed card (rounded + 2px outline + `ledgeShadow`) titled with emoji + localized meal label + earliest eaten-at time; update Today widget tests (a known UTC eatenAt renders the correct LOCAL HH:mm; meals still in eaten order)

## 3. Target steppers

- [x] 3.1 A `PortionStepper` widget (− value +) that steps a value by 0.5 (clamped ≥ 0, decimals preserved) and reports changes; category-colored via `DietCategoryColors`. Widget test: increment/decrement move the value by 0.5 and fire the callback
- [x] 3.2 Replace `_TargetField` in `daily_target_screen.dart` with `PortionStepper` wired to the same `controller.setDraftBase*`; update target widget tests (tapping + raises the draft; remaining still computes)

## 4. Search debounce

- [x] 4.1 Add a `Timer`-based debounce (~300 ms, injectable duration for tests) to `DictionaryController.search`: a keystroke resets the timer; the request fires once when it settles; cancel the timer in `dispose`. Tests: rapid keystrokes issue one request; dispose leaves no pending timer

## 5. i18n

- [x] 5.1 Add any new ARB keys (en + zh-Hant) the visuals need (e.g. progress "used / target" phrasing if changed); run `flutter gen-l10n` and commit generated output. No hard-coded UI strings; no hard-coded `Color`

## 6. Verify

- [x] 6.1 Run `flutter analyze` and `flutter test`; both green
