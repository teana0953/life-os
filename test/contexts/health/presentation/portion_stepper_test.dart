import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/portion_stepper.dart';

import '../../../support/l10n_test_app.dart';

void main() {
  group('PortionStepper', () {
    testWidgets('tapping increment raises the value by 0.5 and fires onChanged', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 12,
              color: Colors.amber,
              onChanged: (v) => reported = v,
              decrementKey: const Key('decrement'),
              incrementKey: const Key('increment'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('increment')));
      await tester.pump();

      expect(reported, 12.5);
    });

    testWidgets('tapping decrement lowers the value by 0.5 and fires onChanged', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 12,
              color: Colors.amber,
              onChanged: (v) => reported = v,
              decrementKey: const Key('decrement'),
              incrementKey: const Key('increment'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('decrement')));
      await tester.pump();

      expect(reported, 11.5);
    });

    testWidgets('decrementing below 0 clamps at 0', (tester) async {
      double? reported;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 0,
              color: Colors.amber,
              onChanged: (v) => reported = v,
              decrementKey: const Key('decrement'),
              incrementKey: const Key('increment'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('decrement')));
      await tester.pump();

      expect(reported, 0);
    });

    testWidgets('preserves decimals in the displayed value', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 11.5,
              color: Colors.amber,
              onChanged: (_) {},
              decrementKey: const Key('decrement'),
              incrementKey: const Key('increment'),
            ),
          ),
        ),
      );

      expect(find.text('11.5'), findsOneWidget);
    });

    testWidgets('shows the default color dot when no leadingIcon is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 1,
              color: Colors.amber,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('renders an optional leadingIcon instead of the color dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 1,
              color: Colors.amber,
              onChanged: (_) {},
              leadingIcon: const Icon(Icons.eco, key: Key('leading-icon')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('leading-icon')), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });
}
