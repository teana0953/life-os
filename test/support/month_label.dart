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
