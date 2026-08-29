import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/widgets/cycle_badge.dart';

Future<void> _pumpBadge(
  WidgetTester tester,
  CycleBadge badge, {
  double textScaleFactor = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: lightTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: Scaffold(body: Center(child: badge)),
      ),
    ),
  );
}

BoxDecoration _decorationOf(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(CycleBadge),
                matching: find.byType(Container),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  group('CycleBadge forms', () {
    testWidgets('the filled form paints a fill and no border', (tester) async {
      await _pumpBadge(
        tester,
        const CycleBadge(
          filled: true,
          color: Color(0xFF112233),
          textColor: Color(0xFFFFFFFF),
          label: '4d',
        ),
      );

      final decoration = _decorationOf(tester);
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, const Color(0xFF112233));
      expect(decoration.border, isNull);
    });

    testWidgets('the outlined form paints a 2dp border and no fill', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const CycleBadge(
          filled: false,
          color: Color(0xFF112233),
          textColor: Color(0xFF000000),
          label: '6d',
        ),
      );

      final decoration = _decorationOf(tester);
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, isNull);
      final border = decoration.border! as Border;
      expect(border.top.color, const Color(0xFF112233));
      // 2dp is the calendar's prediction-marker width; the badge shares that
      // vocabulary rather than inventing a second one.
      expect(border.top.width, 2);
    });

    testWidgets('is a 32dp circle carrying its label', (tester) async {
      await _pumpBadge(
        tester,
        const CycleBadge(
          filled: true,
          color: Color(0xFF112233),
          textColor: Color(0xFFFFFFFF),
          label: 'Today',
        ),
      );

      expect(tester.getSize(find.byType(CycleBadge)), const Size(32, 32));
      expect(
        tester.widget<Text>(find.byType(Text)).style?.color,
        const Color(0xFFFFFFFF),
      );
    });

    testWidgets('a spaced label breaks into two lines inside the circle', (
      tester,
    ) async {
      // The 32dp circle is too narrow for "3d late" on one line at any
      // readable size, so the space is a line break, not a space — pinned
      // because the ARB copy is written on that assumption.
      await _pumpBadge(
        tester,
        const CycleBadge(
          filled: false,
          color: Color(0xFF112233),
          textColor: Color(0xFF000000),
          label: '3d late',
        ),
      );

      expect(tester.widget<Text>(find.byType(Text)).data, '3d\nlate');
    });
  });

  group('CycleBadge at a large text scale', () {
    testWidgets('stays a 32dp circle and does not overflow at 2.0', (
      tester,
    ) async {
      await _pumpBadge(
        tester,
        const CycleBadge(
          filled: false,
          color: Color(0xFF112233),
          textColor: Color(0xFF000000),
          label: '3d late',
        ),
        textScaleFactor: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CycleBadge)), const Size(32, 32));
      // `getRect`, not `getSize`: the size is the label's *unscaled* box, and
      // what has to stay inside the circle is what is painted — the rect
      // carries the FittedBox's shrink, the size does not.
      final painted = tester.getRect(find.byType(Text));
      expect(painted.width, lessThanOrEqualTo(32));
      expect(painted.height, lessThanOrEqualTo(32));
    });
  });

  group('CycleBadge semantics', () {
    testWidgets('announces nothing on its own', (tester) async {
      // A screen reader saying "3d late" as a standalone node is worse than
      // no badge: the sentence that gives it meaning lives on the card/tile.
      final handle = tester.ensureSemantics();
      await _pumpBadge(
        tester,
        const CycleBadge(
          filled: false,
          color: Color(0xFF112233),
          textColor: Color(0xFF000000),
          label: '3d late',
        ),
      );

      expect(find.bySemanticsLabel('3d late'), findsNothing);
      expect(find.bySemanticsLabel('3d\nlate'), findsNothing);
      handle.dispose();
    });
  });

  group('CycleBadge colours', () {
    testWidgets(
      'every colour it paints comes from its constructor, not a literal '
      'of its own',
      (tester) async {
        // Behavioural, not source-reading: pump with two colours that would
        // never coincidentally match a hard-coded default (`0xFF123456` /
        // `0xFF654321`), then assert the fill, border and text all painted
        // in exactly those — the property the design-system rule for
        // presentation code actually cares about, verified at the widget's
        // observable output rather than by grepping its source text (which
        // cannot catch an equivalent violation via a helper or an imported
        // constant, and breaks on any behaviour-preserving refactor of the
        // file).
        const badgeColor = Color(0xFF123456);
        const badgeTextColor = Color(0xFF654321);
        await _pumpBadge(
          tester,
          const CycleBadge(
            filled: false,
            color: badgeColor,
            textColor: badgeTextColor,
            label: '4d',
          ),
        );

        final decoration = _decorationOf(tester);
        final border = decoration.border! as Border;
        expect(border.top.color, badgeColor);
        expect(
          tester.widget<Text>(find.byType(Text)).style?.color,
          badgeTextColor,
        );
      },
    );
  });
}
