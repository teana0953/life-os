import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts the month label under [labelKey] is **fully readable** at the
/// current surface size.
///
/// Narrow-phone month headers can fail in two ways, and only one of them is
/// loud:
///
/// * **overflow** — the row is wider than the screen: the framework paints the
///   yellow/black stripes and throws, so `tester.takeException()` catches it;
/// * **truncation** — the label ellipsizes (`2026年7月` → `202…`): nothing is
///   thrown, so an exception-only assertion passes while the user can no
///   longer tell which month they are looking at. This is the worse of the
///   two, and it is what this helper exists to catch.
///
/// So it checks the paragraph laid out its *whole* text on one line
/// (`size.width` == its unconstrained intrinsic width, and no ellipsis was
/// applied) — which stays true when a `FittedBox` merely *scales* the glyphs
/// down, because the paragraph itself is still laid out unconstrained — and
/// that what is painted stays inside the surface horizontally.
void expectMonthLabelFullyVisible(WidgetTester tester, Key labelKey) {
  final finder = find.byKey(labelKey);
  expect(finder, findsOneWidget);

  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = tester.widget<Text>(finder).data;
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: 'the month label "$text" was ellipsized',
  );
  expect(
    paragraph.size.width,
    closeTo(paragraph.getMaxIntrinsicWidth(double.infinity), 0.5),
    reason:
        'the month label "$text" was truncated or wrapped instead of being '
        'laid out in full',
  );

  final rect = tester.getRect(finder);
  final surfaceWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  expect(rect.left, greaterThanOrEqualTo(-0.5), reason: 'label "$text" is cut off on the left');
  expect(
    rect.right,
    lessThanOrEqualTo(surfaceWidth + 0.5),
    reason: 'label "$text" is cut off on the right',
  );
}

/// How much a `FittedBox` shrank the label under [labelKey]: 1.0 when it is
/// painted at its natural size, < 1.0 when it had to scale down to fit.
double monthLabelScale(WidgetTester tester, Key labelKey) {
  final finder = find.byKey(labelKey);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return tester.getRect(finder).width / paragraph.size.width;
}

/// The size the month label is actually *painted* at: its own font size times
/// however much the enclosing `FittedBox` scaled it down.
double monthLabelEffectiveFontSize(WidgetTester tester, Key labelKey) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byKey(labelKey));
  final fontSize = paragraph.text.style?.fontSize;
  expect(fontSize, isNotNull, reason: 'the month label has no font size');
  return fontSize! * monthLabelScale(tester, labelKey);
}

/// The floor below which the month label counts as unreadable, in logical
/// pixels.
const monthLabelMinFontSize = 12.0;

/// Asserts the month label under [labelKey] is not scaled below
/// [monthLabelMinFontSize].
///
/// [expectMonthLabelFullyVisible] only proves no *characters* were lost; a
/// `FittedBox(fit: BoxFit.scaleDown)` has no lower bound, so a label can pass
/// that check while being painted at 9px. This is the other half: whatever is
/// shown has to stay legible.
void expectMonthLabelReadable(WidgetTester tester, Key labelKey) {
  final text = tester.widget<Text>(find.byKey(labelKey)).data;
  expect(
    monthLabelEffectiveFontSize(tester, labelKey),
    greaterThanOrEqualTo(monthLabelMinFontSize),
    reason:
        'the month label "$text" was scaled below '
        '${monthLabelMinFontSize}px and is no longer readable',
  );
}
