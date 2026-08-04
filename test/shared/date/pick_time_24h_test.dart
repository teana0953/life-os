import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/date/pick_time_24h.dart';

/// Pumps a bare app with a button that calls [pickTime24h] when tapped — the
/// minimum scaffolding [pickTime24h] needs (a `BuildContext` with
/// `Navigator`/`MaterialLocalizations` above it).
///
/// The 12-hour side of this test is the **test environment's own default**
/// (`alwaysUse24HourFormat: false`), not something the test sets up, and the
/// test asserts that premise explicitly rather than assuming it. Two ways of
/// forcing it were tried and are both inert here, so don't reintroduce them:
///
/// - a `MediaQuery(data: MediaQueryData(alwaysUse24HourFormat: false))` wrapper
///   around the button never reaches the dialog — `showTimePicker` pushes on
///   the root navigator and `InheritedTheme.capture` does not carry
///   `MediaQuery`;
/// - `tester.platformDispatcher.alwaysUse24HourFormatTestValue` never reaches
///   it either — the setter fires no change notification, so the root
///   `MediaQuery` that was already built keeps its original value.
Future<void> _pumpPicker(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => pickTime24h(
              context,
              initialTime: const TimeOfDay(hour: 9, minute: 30),
            ),
            child: const Text('pick'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'pickTime24h forces alwaysUse24HourFormat true inside the dialog, '
    'starting from an ambient 12-hour setting',
    (tester) async {
      await _pumpPicker(tester);

      // Pin the premise: without this the test could pass simply because the
      // ambient setting was already 24-hour, proving nothing about the helper.
      final callSiteContext = tester.element(find.byType(ElevatedButton));
      expect(MediaQuery.of(callSiteContext).alwaysUse24HourFormat, isFalse);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      final dialogContext = tester.element(find.byType(TimePickerDialog));
      expect(MediaQuery.of(dialogContext).alwaysUse24HourFormat, isTrue);
    },
  );
}
