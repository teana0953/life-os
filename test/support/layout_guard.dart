import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [body] with `FlutterError.onError` redirected so that **every** error
/// reported while it runs is collected, and returns them.
///
/// Why not `tester.takeException()`: the test binding keeps only the *first*
/// exception of a test, so draining it hides every subsequent one — a screen
/// with a known overflow silently absorbs any new one. Overriding
/// `FlutterError.onError` is the only way to see them all.
///
/// Two traps this deliberately avoids (both hit for real while writing these
/// guards):
///
/// 1. The override is restored in a `finally`, **before** the caller asserts.
///    Asserting while `onError` is still redirected makes the binding's
///    "an error was reported while the test was running" assert
///    (`binding.dart`) fire on the *expect* failure and mask the real error.
/// 2. The collector never throws. An exception thrown inside an
///    `FlutterError.onError` callback makes the whole test run hang forever
///    with no red output.
///
/// The binding restores its own `onError` in `postTest`, so this does not leak
/// into other tests.
Future<List<FlutterErrorDetails>> collectLayoutErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

/// The global x of the right-most **painted glyph** of the `Text` [finder]
/// matches.
///
/// Deliberately not `tester.getRect(...).right`: once a trailing value is
/// wrapped in an `Expanded`, its box always spans to the row's edge, so a box
/// measurement would still pass if `TextAlign.end` were dropped. Measuring the
/// glyph run is what actually pins "the number reads flush right".
double paintedTextRight(WidgetTester tester, Finder finder) {
  final paragraph = finder.evaluate().single.renderObject! as RenderParagraph;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  // Same empty-run guard as [paintedTextLineRights], which skips them: a
  // `Text` that painted no glyph would otherwise die in `reduce` with
  // "Bad state: No element" instead of naming the widget.
  if (boxes.isEmpty) fail('$finder painted no glyphs to measure');
  final localRight = boxes.map((b) => b.right).reduce(math.max);
  return paragraph.localToGlobal(Offset(localRight, 0)).dx;
}

/// The global x of the right-most painted glyph **of each line** the `Text`
/// [finder] matches painted, top line first.
///
/// The per-line version of [paintedTextRight], for the case where the value
/// was forced to wrap: only a per-line measurement can tell "every line is
/// right-aligned" from "the text merely happens to reach the edge on its
/// longest line", which is what a single max-over-all-boxes reading gives.
///
/// Measured character by character, skipping whitespace, because a line broken
/// at a space keeps that space in the run and `TextAlign.end` hangs it *past*
/// the end edge — a run-level reading of a wrapped sentence comes back wider
/// than the box and defeats the comparison.
List<double> paintedTextLineRights(WidgetTester tester, Finder finder) {
  final paragraph = finder.evaluate().single.renderObject! as RenderParagraph;
  final plain = paragraph.text.toPlainText();
  final rightByLine = <double, double>{};
  for (var i = 0; i < plain.length; i++) {
    if (plain[i].trim().isEmpty) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final top = boxes.first.top.roundToDouble();
    final right = boxes.map((b) => b.right).reduce(math.max);
    final known = rightByLine[top];
    rightByLine[top] = known == null ? right : math.max(known, right);
  }
  final tops = rightByLine.keys.toList()..sort();
  return [
    for (final top in tops)
      paragraph.localToGlobal(Offset(rightByLine[top]!, 0)).dx,
  ];
}

/// How many lines the `Text` [finder] matches actually painted.
///
/// Counted from the laid-out glyph boxes (one distinct `top` per line), so it
/// reflects the width the row really handed the label — the thing a "does this
/// label wrap too early?" guard has to observe. A widget-level check
/// (`Text.maxLines`, the string itself) cannot see it. `RenderParagraph`
/// doesn't expose `computeLineMetrics`, hence the box grouping.
int paintedTextLineCount(WidgetTester tester, Finder finder) {
  final paragraph = finder.evaluate().single.renderObject! as RenderParagraph;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  return boxes.map((b) => b.top.roundToDouble()).toSet().length;
}

/// How many lines the substring [part] of the `Text` [finder] matches was
/// painted across.
///
/// The sub-string version of [paintedTextLineCount], for a `Text` that is
/// *allowed* to wrap but has places it must not wrap **inside** — a
/// before→after amount ("18,000 → 12,500") may break at the arrow and must
/// never break inside either figure, because half a thousands group reads as
/// a different number. A whole-paragraph line count cannot tell those two
/// apart: it is 2 either way.
int paintedLineCountOfPart(WidgetTester tester, Finder finder, String part) {
  final paragraph = finder.evaluate().single.renderObject! as RenderParagraph;
  final plain = paragraph.text.toPlainText();
  final start = plain.indexOf(part);
  if (start < 0) fail('"$part" is not part of the painted text "$plain"');
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + part.length),
  );
  if (boxes.isEmpty) fail('"$part" painted no glyphs to measure');
  return boxes.map((b) => b.top.roundToDouble()).toSet().length;
}

/// Runs [body] and asserts it reported no layout error at all.
///
/// Not limited to `RenderFlex` overflows on purpose: a `ListTile` whose
/// trailing content cannot be laid out raises a plain assertion instead, and a
/// RenderFlex-only filter would let it pass unfixed.
Future<void> expectNoLayoutErrors(
  Future<void> Function() body, {
  String? reason,
}) async {
  final errors = await collectLayoutErrors(body);
  if (errors.isEmpty) return;
  final summary = errors
      .map((e) => e.exception.toString().split('\n').first)
      .join('\n  - ');
  fail(
    '${reason ?? 'Expected no layout errors'}, but ${errors.length} were '
    'reported:\n  - $summary',
  );
}
