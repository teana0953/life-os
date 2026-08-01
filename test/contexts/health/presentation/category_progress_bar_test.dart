import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/category_progress_bar.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/fractional_progress_bar.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';

void main() {
  group('CategoryProgressBar', () {
    testWidgets('9 of 12 fills the bar to three-quarters', (tester) async {
      const barKey = Key('progress-bar');
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: CategoryProgressBar(
              key: barKey,
              label: 'Staple',
              logged: 9,
              effective: 12,
              color: Colors.amber,
            ),
          ),
        ),
      );

      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fill.widthFactor, closeTo(0.75, 0.0001));

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietProgressOfTarget(9, 12)), findsOneWidget);
    });

    testWidgets('over-target logging fills the bar fully, numbers show true values', (
      tester,
    ) async {
      const barKey = Key('progress-bar');
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: CategoryProgressBar(
              key: barKey,
              label: 'Staple',
              logged: 15,
              effective: 10,
              color: Colors.amber,
            ),
          ),
        ),
      );

      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fill.widthFactor, 1.0);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietProgressOfTarget(15, 10)), findsOneWidget);
    });

    testWidgets('an effective target of 0 renders an empty bar without dividing by zero', (
      tester,
    ) async {
      const barKey = Key('progress-bar');
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: CategoryProgressBar(
              key: barKey,
              label: 'Staple',
              logged: 0,
              effective: 0,
              color: Colors.amber,
            ),
          ),
        ),
      );

      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fill.widthFactor, 0.0);
    });

    testWidgets(
      'an optional trailingLabel replaces the used/target text but the fill still reflects logged/effective',
      (tester) async {
        const barKey = Key('progress-bar');
        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: CategoryProgressBar(
                key: barKey,
                label: 'Staple',
                logged: 9,
                effective: 12,
                color: Colors.amber,
                trailingLabel: '3 remaining',
              ),
            ),
          ),
        );

        final fill = tester.widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(barKey),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        expect(fill.widthFactor, closeTo(0.75, 0.0001));
        expect(find.text('3 remaining'), findsOneWidget);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.dietProgressOfTarget(9, 12)), findsNothing);
      },
    );

    // Right-alignment guard. Making both halves shrinkable is easy to get
    // wrong in a way no overflow test catches: a *loose* `Flexible` around
    // the number shrink-wraps the text and parks the slack after it, so the
    // number drifts left of the bar it annotates — and further the wider the
    // screen (75px at 390dp, 280px at 800dp when this regressed). The bar's
    // right edge is the reference because they are stacked in the same
    // stretched Column and read as one unit.
    for (final width in [390.0, 600.0, 800.0]) {
      testWidgets('the number stays flush with the bar\'s right edge at ${width.toInt()}dp', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: CategoryProgressBar(
                label: 'Staple',
                logged: 9,
                effective: 12,
                color: Colors.amber,
              ),
            ),
          ),
        );

        final loc = lookupAppLocalizations(const Locale('en'));
        final numberRight = paintedTextRight(
          tester,
          find.text(loc.dietProgressOfTarget(9, 12)),
        );
        final bar = tester.getRect(find.byType(FractionalProgressBar));

        expect(numberRight, closeTo(bar.right, 0.5));
      });
    }

    // The matching wrapping guard. A flex child is capped at its share of the
    // row, so making both halves flexible cut every label to 50% of the bar
    // and wrapped it while the other half sat empty (the same shape wrapped
    // `Total liabilities` onto 3 lines at 390dp in the net-worth tab). This is
    // a shared widget whose label comes from its host, so it is measured with
    // one longer than half the row but still fitting beside the number: at
    // 390dp this label wants 256.5dp of the 282.3dp left over, and the 50/50
    // shape would hand it 191dp.
    for (final width in [390.0, 430.0, 600.0, 800.0]) {
      testWidgets('a label that fits the row stays on one line at ${width.toInt()}dp', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const label = 'Staple food target';
        await tester.pumpWidget(
          l10nTestApp(
            home: const Scaffold(
              body: CategoryProgressBar(
                label: label,
                logged: 9,
                effective: 12,
                color: Colors.amber,
              ),
            ),
          ),
        );

        expect(paintedTextLineCount(tester, find.text(label)), 1);
      });
    }
  });
}
