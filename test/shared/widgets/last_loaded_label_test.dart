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
    final at = DateTime(2026, 7, 18, 9, 41);
    await _pump(tester, at);

    // The clock portion follows the system 12/24-hour setting via
    // TimeOfDay.format — assert against exactly what the widget builds so the
    // test doesn't hard-code a 12/24 assumption.
    final context = tester.element(find.byType(LastLoadedLabel));
    final time = TimeOfDay.fromDateTime(at).format(context);
    expect(find.text(_loc.lastUpdatedAt(time)), findsOneWidget);
  });
}
