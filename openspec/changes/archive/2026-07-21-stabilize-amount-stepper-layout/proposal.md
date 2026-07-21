## Why

In the food-search tray and Today's in-place item editor, toggling a food's
amount control between 份量 (portion) and its measure (顆/公克/毫升) makes the
`AmountStepper` visibly reflow: it can jump from two lines to one (or back) and
the elements shift, so the mode-toggle button lands under the cursor
inconsistently and is hard to tap. The cause is the widget's `Wrap` layout: its
line breaks are driven by total content width, and the after-field unit label
changes width with the mode (份 vs 顆/公克/毫升), so the `SegmentedButton`'s
wrap threshold shifts as you toggle — moving it between "same line as the trio"
and "next line". On top of that, at narrow widths (320dp/360dp) the English copy
is longer ("Quantity"/"Grams"/"portion(s)") and can overflow.

Frontend-only, layout-only. No DTO, API, or measure semantics change.

## What Changes

- **Stable rows on mode toggle**: the `AmountStepper` no longer reflows when the
  mode is switched. The `SegmentedButton` keeps a fixed position (its own line);
  toggling the mode only changes the after-field unit label, not the number of
  lines or the segment's line.
- **No overflow at 320dp/360dp in both locales**: the amount control does not
  overflow at narrow phone widths in either English or Traditional Chinese,
  including the longer English labels; the after-field unit label shrinks
  (ellipsizes) rather than overflowing.
- Scope is limited to `amount_stepper.dart`'s `build` layout plus its widget
  tests — the after-field label following the mode (`measureMode ? measureLabel
  : unitLabel`, the #39 fix), the 份量 segment label, `measureLabelFor`, both
  call sites' semantics, and the DTO/API are all unchanged.

## Capabilities

### Modified Capabilities

- `health-diet`: the amount control's layout is stable across a portion/measure
  mode toggle (the mode toggle keeps a fixed position and the line count does not
  change) and does not overflow at narrow phone widths (320dp/360dp) in either
  supported locale.
