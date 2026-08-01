import 'package:flutter/material.dart';

/// A one-line label that **scales down** to fit the width it is given — but,
/// *when width is what constrains it*, never below [minFontSize].
///
/// A bare `FittedBox(fit: BoxFit.scaleDown)` has no lower bound: it keeps
/// shrinking as the available width falls, so a month header that merely
/// looked tight on a 360dp phone silently became unreadable (measured down to
/// an effective 9.2px) on a 320dp one, with nothing in the widget tree or the
/// tests to stop it.
///
/// The floor is expressed as a *width* rather than a font size so the
/// shrinking stays geometric (the `FittedBox` still scales the glyphs, which
/// is what the month-label tests measure): the child is capped at
/// `maxWidth / minScale`, so the `FittedBox`'s own scale — `maxWidth /
/// childWidth` — can never drop below `minScale`. While the text is narrower
/// than that cap the label behaves exactly as before; once it isn't, the label
/// holds [minFontSize] and ellipsizes instead of shrinking further.
///
/// `minScale` is measured against the **text-scaled** font size
/// (`MediaQuery.textScalerOf(context)`), not the authored one, because that is
/// what actually reaches the screen: the `FittedBox` shrinks by exactly as
/// much as the scaler grew the glyphs, so the painted size is the same at
/// every text scale. Comparing the authored size against the floor instead
/// made the cap bite `textScaler`× too early, and a user on a 3.0 text scale
/// got the month digits ellipsized away (`2026年7月` → `202…`) while the label
/// was still being painted comfortably above 12px.
///
/// ## What this does *not* guarantee
///
/// * **The floor is on the width axis only.** `BoxFit.scaleDown` picks
///   `min(maxWidth / childWidth, maxHeight / childHeight)` and the
///   `ConstrainedBox` caps only the width, so a *height*-limited box still
///   scales past the floor: measured, a 400x12 box paints `titleLarge` (22px,
///   28px tall) at 9.43px and a 400x8 one at 6.29px. No call site constrains
///   this widget's height today; one that does has to guard the height itself.
/// * **Single line only.** The child is `maxLines: 1, softWrap: false`, and
///   the width cap assumes one line — it does not bound a wrapped paragraph.
/// * **Past the floor the label ellipsizes.** It stops shrinking, it does not
///   stop losing characters: below the floor, losing the tail beats losing the
///   whole label to illegibility. Call sites that must stay whole have to give
///   the label enough width, not rely on this widget.
class ShrinkToFitText extends StatelessWidget {
  final String text;

  /// Goes on the inner `Text`, so call sites' tests keep reading the label
  /// through `tester.widget<Text>(find.byKey(...))`.
  final Key? textKey;

  final TextStyle? style;

  /// The smallest rendered size, in logical pixels. 12 is the readability
  /// floor used by the month headers.
  final double minFontSize;

  const ShrinkToFitText({
    super.key,
    required this.text,
    this.textKey,
    this.style,
    this.minFontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final fontSize =
        effectiveStyle.fontSize ?? DefaultTextStyle.of(context).style.fontSize;
    final label = Text(
      text,
      key: textKey,
      style: effectiveStyle,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    // A style with no font size at all (nothing to scale against) keeps the
    // old unbounded behaviour rather than guessing a floor.
    if (fontSize == null || fontSize <= 0) {
      return FittedBox(fit: BoxFit.scaleDown, child: label);
    }
    // The glyphs the `FittedBox` scales are already `textScaler`-sized, so the
    // floor has to be compared against that, not against `fontSize`.
    final scaledFontSize = MediaQuery.textScalerOf(context).scale(fontSize);
    final minScale = (minFontSize / scaledFontSize).clamp(0.01, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return FittedBox(fit: BoxFit.scaleDown, child: label);
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth / minScale,
            ),
            child: label,
          ),
        );
      },
    );
  }
}
