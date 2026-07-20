/// Pure computation for the on-screen keyboard's bottom inset (logical px),
/// shared by both the native and web implementations of the keyboard-inset
/// helper (see `keyboard_inset.dart` / design.md D1).
///
/// [layoutHeight] and [viewportHeight]/[offsetTop] must come from the same
/// coordinate source (on web: `window.innerHeight` and
/// `visualViewport.height`/`offsetTop`) so the subtraction is
/// apples-to-apples.
double computeKeyboardInset({
  required double layoutHeight,
  required double viewportHeight,
  required double offsetTop,
}) => (layoutHeight - viewportHeight - offsetTop).clamp(0.0, double.infinity);
