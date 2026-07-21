# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` before finishing. Widget tests inject fakes via `l10nTestApp`; set
the surface size with `tester.binding.setSurfaceSize(...)` +
`addTearDown(() => tester.binding.setSurfaceSize(null))` when overflow/scroll
matters. Derive all colors from `Theme.of(context)` — no hard-coded hex.

## 1. Controller: an "item just added" signal

- [x] 1.1 Test first — in `create_meal_controller` tests: calling `add(item)` (and
      `addManual(name, portions)`) increments a new `addTick` and sets `lastAdded`
      to the newly added `TrayEntry`; `remove(entry)` and `setAmount(entry, v)` /
      `toggleMeasure(...)` leave `addTick`/`lastAdded` unchanged.
- [x] 1.2 Implement in `create_meal_controller.dart`: add `int addTick` (starts 0)
      and `TrayEntry? lastAdded`; bump `addTick` + set `lastAdded` inside `add` and
      `addManual` (before `notifyListeners`); do NOT touch them in
      `remove`/`setAmount`/`toggleMeasure`. Keep existing behavior otherwise.

## 2. Tray auto-scrolls to the newly added item

- [x] 2.1 Test first — in `food_search_screen_test.dart`: add enough items to
      overflow the 260px tray, then add one more; after `pumpAndSettle`, assert the
      newest row is revealed — e.g. the tray `ScrollController` is at (≈)
      `maxScrollExtent`, or `find.byKey(Key('tray-item-<last>'))` is visible within
      the tray viewport. Also assert that a `remove` or an amount change does NOT
      scroll the tray to the end.
- [x] 2.2 Implement — convert `_TrayPanel` to a `StatefulWidget` owning a
      `ScrollController` attached to the `food-search-tray-list` `ListView.builder`.
      Listen to the controller (or compare `addTick` across builds); when `addTick`
      increases, `WidgetsBinding.instance.addPostFrameCallback` →
      `animateTo(position.maxScrollExtent, ...)` with a short duration/curve. Ensure
      the listener is removed in `dispose` and the `ScrollController` is disposed.

## 3. Newly added row briefly highlights

- [x] 3.1 Test first — after an add, the row for `lastAdded` shows a non-transparent
      highlight background immediately, and after the fade duration
      (`pump(<duration>)` / `pumpAndSettle`) the background is back to transparent.
      A row that was already present (not the just-added one) never shows the
      highlight.
- [x] 3.2 Implement — wrap the tray row content in a fade-out highlight (e.g. an
      `AnimatedContainer`/`TweenAnimationBuilder` from a low-opacity
      `theme.colorScheme.primary`/accent to transparent over ~0.9s), keyed so only
      the `lastAdded` entry animates on the add that produced it. Derive the color
      from the theme; no hard-coded color.

## 4. Regression + quality gate

- [x] 4.1 `flutter analyze` clean + `flutter test` green — existing tray tests
      (add-to-tray, preview pills, total pill, remove, AmountStepper stability/
      overflow) all still pass. Confirm removing an item and changing an amount
      neither scroll nor highlight.
