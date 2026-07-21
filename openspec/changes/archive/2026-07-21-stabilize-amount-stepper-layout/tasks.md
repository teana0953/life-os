# Tasks

TDD throughout: failing test first, then implementation. Run `flutter analyze` +
`flutter test` before finishing. Widget tests inject fakes via `l10nTestApp` and
set the surface size with `tester.binding.setSurfaceSize(...)` +
`addTearDown(() => tester.binding.setSurfaceSize(null))`.

## 1. Stability: mode toggle does not change the layout

Landed on **plan A'** (fixed two-row layout: trio + after-field label on row 1,
`SegmentedButton` on its own row 2). The 320dp × en no-overflow case passes
under A' with `Flexible`+ellipsis on a bounded row; the `IconButton` tightening
prescribed by the design is kept as a readability refinement (it maximizes the
after-field label's visible width before it must ellipsize) — the no-overflow
tests are green with or without it, so no fallback to plan A was needed.

- [x] 1.1 Test first — in `amount_stepper_test.dart`, for a household/gram
      `AmountStepper` (`allowMeasure: true`, a `measureLabel`), render it with
      `measureMode: false` and with `measureMode: true` and assert the
      `SegmentedButton` sits on its own line **below** the −/field/+ trio in both
      renders (i.e. the segment's line relationship to the trio does not change
      with the mode). Assert the after-field unit label still follows the mode
      (`unitLabel` in portion mode, `measureLabel` in measure mode).
- [x] 1.2 Implement — replace the `Wrap` in `build` with a fixed two-row layout:
      row 1 is a `Row` of the −/field/+ trio and the after-field unit label
      (label wrapped in `Flexible` with `overflow: TextOverflow.ellipsis`); row 2
      is the `SegmentedButton` when `allowMeasure`, always on its own line.
      Keep the after-field label expression (`measureMode ? (measureLabel ??
      unitLabel) : unitLabel`) and the 份量 segment label unchanged.

## 2. No overflow at narrow widths in both locales

- [x] 2.1 Test first — parametrize over {320dp, 360dp} × {en, zh-Hant}: render a
      gram `AmountStepper` (long en labels: unitLabel "portion(s)", measureLabel
      "Grams", segment "Quantity") and assert `tester.takeException()` is `null`
      in both portion and measure mode. Add the equivalent no-overflow assertion
      for the food-search tray gram row (`food_search_screen_test.dart`) and
      Today's expanded in-place editor if not already covered.
- [x] 2.2 Implement — make row 1 not overflow at 320dp/en: ensure the trio Row
      gets a bounded width constraint so `Flexible` on the label takes effect, and
      tighten the −/+ `IconButton`s (`visualDensity` / `constraints` / `padding`)
      as needed to leave room for the label, so the label ellipsizes instead of
      overflowing. If 320dp × en cannot be both stable and non-overflowing under
      plan A', fall back to plan A (move the unit label onto the second line
      alongside the `SegmentedButton`) — see `design.md`.

## 3. Regression: existing assertions still pass

- [x] 3.1 `flutter analyze` clean + `flutter test` green — the existing
      assertions (measure segment 公克/毫升/顆, 份量 segment, after-field unit
      label following the mode, existing narrow-screen tests) all still pass.
