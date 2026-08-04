import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/last_loaded_label.dart';

import '../../support/l10n_test_app.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(
  WidgetTester tester,
  DateTime? at, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: Scaffold(body: LastLoadedLabel(lastLoadedAt: at)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('null renders nothing (never loaded → no label)', (tester) async {
    await _pump(tester, null);

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.textContaining('Updated'), findsNothing);
  });

  testWidgets('a value shows the "Updated <clock time>" line', (tester) async {
    await _pump(tester, DateTime(2026, 7, 18, 9, 41));

    expect(find.text(_loc.lastUpdatedAt('09:41')), findsOneWidget);
  });

  testWidgets(
    'the clock is 24-hour even under a 12-hour ambient setting — an afternoon '
    'time reads "21:05", not "9:05 PM", so this label matches the '
    'always-24-hour reading/meal times it sits above',
    (tester) async {
      await _pump(tester, DateTime(2026, 7, 18, 21, 5));

      // Pin the premise: the ambient setting really is the 12-hour one, i.e.
      // exactly the English-locale phone this label used to follow. (Both
      // `MediaQuery` wrappers and
      // `platformDispatcher.alwaysUse24HourFormatTestValue` are inert here —
      // see pick_time_24h_test.dart — so assert the default instead of
      // pretending to override it.)
      final context = tester.element(find.byType(LastLoadedLabel));
      expect(MediaQuery.of(context).alwaysUse24HourFormat, isFalse);

      expect(find.text(_loc.lastUpdatedAt('21:05')), findsOneWidget);
      expect(find.textContaining('PM'), findsNothing);
    },
  );
}
