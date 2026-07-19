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

    testWidgets('tapping the value opens an edit dialog titled with the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 4,
              color: Colors.amber,
              onChanged: (_) {},
              valueKey: const Key('value'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('value')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('portion-edit-field')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Staple'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'opening the dialog on a 0 value shows an empty field with a 0 hint '
      '(no 0 to delete first)',
      (tester) async {
        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: PortionStepper(
                label: 'Staple',
                value: 0,
                color: Colors.amber,
                onChanged: (_) {},
                valueKey: const Key('value'),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('value')));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(
          find.byKey(const Key('portion-edit-field')),
        );
        expect(field.controller!.text, isEmpty);
        expect(field.decoration!.hintText, '0');
      },
    );

    testWidgets('confirming a valid typed value fires onChanged with it', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 4,
              color: Colors.amber,
              onChanged: (v) => reported = v,
              valueKey: const Key('value'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('value')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('portion-edit-field')),
        '2.5',
      );
      await tester.tap(find.byKey(const Key('portion-edit-confirm')));
      await tester.pumpAndSettle();

      expect(reported, 2.5);
    });

    testWidgets('confirming a negative typed value clamps to 0', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 4,
              color: Colors.amber,
              onChanged: (v) => reported = v,
              valueKey: const Key('value'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('value')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('portion-edit-field')), '-3');
      await tester.tap(find.byKey(const Key('portion-edit-confirm')));
      await tester.pumpAndSettle();

      expect(reported, 0);
    });

    testWidgets('confirming non-numeric input is ignored (no onChanged)', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 4,
              color: Colors.amber,
              onChanged: (v) => reported = v,
              valueKey: const Key('value'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('value')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('portion-edit-field')),
        'abc',
      );
      await tester.tap(find.byKey(const Key('portion-edit-confirm')));
      await tester.pumpAndSettle();

      expect(reported, isNull);
      expect(find.byKey(const Key('portion-edit-field')), findsNothing);
    });

    testWidgets('the edit dialog can be opened, cancelled, and reopened '
        'without leaking its text controller', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: PortionStepper(
              label: 'Staple',
              value: 4,
              color: Colors.amber,
              onChanged: (_) {},
              valueKey: const Key('value'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('value')));
      await tester.pumpAndSettle();
      // Dismiss via the barrier instead of confirming, mirroring a cancel.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('portion-edit-field')), findsNothing);

      await tester.tap(find.byKey(const Key('value')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('portion-edit-field')),
      );
      expect(field.controller?.text, '4');
    });
  });
}
