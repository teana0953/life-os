import 'package:flutter/material.dart';

/// A one-line label that **scales down** to fit the width it is given — but
/// never below [minFontSize].
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
    final minScale = (minFontSize / fontSize).clamp(0.01, 1.0);
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
