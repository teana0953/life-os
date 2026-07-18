import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/category_progress_bar.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

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
  });
}
