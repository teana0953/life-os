import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/contexts/notifications/presentation/push_off_banner.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Future<void> _pumpBanner(WidgetTester tester, PushHealth health) async {
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: Scaffold(body: PushOffBanner(health: health)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PushOffBanner', () {
    testWidgets(
      'permissionPrompt says notifications are not on yet and its action '
      'opens reminder settings',
      (tester) async {
        await _pumpBanner(tester, PushHealth.permissionPrompt);

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
        expect(find.text(_en.careRemindersPushOffBanner), findsOneWidget);
        expect(find.text(_en.careRemindersPushOffAction), findsOneWidget);

        await tester.tap(find.byKey(const Key('push-off-action')));
        await tester.pumpAndSettle();

        expect(find.text('/reminders'), findsOneWidget);
      },
    );

    testWidgets(
      'permissionDenied says notifications were turned off and its action '
      'opens reminder settings',
      (tester) async {
        await _pumpBanner(tester, PushHealth.permissionDenied);

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
        expect(find.text(_en.careRemindersPushDeniedBanner), findsOneWidget);
        expect(find.text(_en.careRemindersPushDeniedAction), findsOneWidget);
        // The two states must not share copy: "turned off" would be a lie for
        // a permission that was never requested.
        expect(
          _en.careRemindersPushDeniedBanner,
          isNot(_en.careRemindersPushOffBanner),
        );

        await tester.tap(find.byKey(const Key('push-off-action')));
        await tester.pumpAndSettle();

        expect(find.text('/reminders'), findsOneWidget);
      },
    );

    testWidgets('ok shows nothing', (tester) async {
      await _pumpBanner(tester, PushHealth.ok);

      expect(find.byKey(const Key('push-off-banner')), findsNothing);
    });

    testWidgets('unknown shows nothing', (tester) async {
      await _pumpBanner(tester, PushHealth.unknown);

      expect(find.byKey(const Key('push-off-banner')), findsNothing);
    });

    testWidgets(
      'unsupported shows nothing — "notifications are off" would be false on '
      'a device that never supported them',
      (tester) async {
        await _pumpBanner(tester, PushHealth.unsupported);

        expect(find.byKey(const Key('push-off-banner')), findsNothing);
      },
    );

    testWidgets(
      'syncFailed shows nothing — push still arrives, and being offline is '
      'the most common cause',
      (tester) async {
        await _pumpBanner(tester, PushHealth.syncFailed);

        expect(find.byKey(const Key('push-off-banner')), findsNothing);
        expect(find.byType(TextButton), findsNothing);
      },
    );
  });
}
