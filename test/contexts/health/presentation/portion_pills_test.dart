import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/portion_pills.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

void main() {
  group('PortionPills', () {
    testWidgets(
      '蛋 (0 staple, 1 meat) shows a single "meat 1" pill, no "0"',
      (tester) async {
        await tester.pumpWidget(
          l10nTestApp(
            home: const Scaffold(
              body: PortionPills(staple: 0, meat: 1, fruit: 0, veg: 0),
            ),
          ),
        );
        await tester.pump();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text('${loc.dietCategoryMeat} 1'), findsOneWidget);
        expect(find.text('${loc.dietCategoryStaple} 0'), findsNothing);
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets('shows one pill per non-zero group', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: const Scaffold(
            body: PortionPills(staple: 2, meat: 1, fruit: 0, veg: 1),
          ),
        ),
      );
      await tester.pump();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text('${loc.dietCategoryStaple} 2'), findsOneWidget);
      expect(find.text('${loc.dietCategoryMeat} 1'), findsOneWidget);
      expect(find.text('${loc.dietCategoryVeg} 1'), findsOneWidget);
      expect(find.textContaining(loc.dietCategoryFruit), findsNothing);
    });

    testWidgets('shows nothing when all portions are zero', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: const Scaffold(
            body: PortionPills(staple: 0, meat: 0, fruit: 0, veg: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PortionPills), findsOneWidget);
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children, isEmpty);
    });
  });
}
