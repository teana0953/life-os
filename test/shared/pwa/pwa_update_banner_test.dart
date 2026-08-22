import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/pwa/pwa_update.dart';
import 'package:life_os/shared/pwa/pwa_update_banner.dart';
import 'package:life_os/shared/pwa/pwa_update_controller.dart';

import '../../support/l10n_test_app.dart';

/// A fake [PwaUpdate] whose availability is driven directly by the test.
class _FakePwaUpdate implements PwaUpdate {
  bool available = false;
  bool applyCalled = false;

  @override
  bool get updateAvailable => available;

  @override
  Future<void> applyUpdate() async {
    applyCalled = true;
  }
}

/// Pumps [PwaUpdateBanner] over the shared [controller]. Not started (no
/// timer): tests flip availability via `checkForUpdate`.
Future<void> _pumpBanner(
  WidgetTester tester,
  PwaUpdateController controller,
) async {
  await tester.pumpWidget(
    l10nTestApp(home: PwaUpdateBanner(controller: controller)),
  );
}

void main() {
  final loc = _en;

  group('PwaUpdateBanner', () {
    testWidgets('shows nothing when no update is available', (tester) async {
      final controller = PwaUpdateController(_FakePwaUpdate());
      addTearDown(controller.dispose);
      await _pumpBanner(tester, controller);

      expect(find.text(loc.updateAvailableTitle), findsNothing);
      expect(find.byKey(const Key('pwa-update-button')), findsNothing);
    });

    testWidgets('shows the title + Update button when available', (
      tester,
    ) async {
      final fake = _FakePwaUpdate();
      final controller = PwaUpdateController(fake);
      addTearDown(controller.dispose);
      await _pumpBanner(tester, controller);

      fake.available = true;
      controller.checkForUpdate();
      await tester.pump();

      expect(find.text(loc.updateAvailableTitle), findsOneWidget);
      expect(find.byKey(const Key('pwa-update-button')), findsOneWidget);
      expect(find.text(loc.updateButton), findsOneWidget);
    });

    testWidgets('tapping Update calls applyUpdate', (tester) async {
      final fake = _FakePwaUpdate();
      final controller = PwaUpdateController(fake);
      addTearDown(controller.dispose);
      await _pumpBanner(tester, controller);

      fake.available = true;
      controller.checkForUpdate();
      await tester.pump();

      await tester.tap(find.byKey(const Key('pwa-update-button')));
      await tester.pump();

      expect(fake.applyCalled, isTrue);
    });

    testWidgets(
      'nothing but that button ever applies an update — showing the banner, '
      'polling, resuming and dismissing never reload the app (issue #226 H4: '
      'a page mid-`applyUpdate` is painted but dead, so the elimination has '
      'to be a committed assertion, not prose)',
      (tester) async {
        final fake = _FakePwaUpdate();
        final controller = PwaUpdateController(
          fake,
          pollInterval: const Duration(milliseconds: 10),
        );
        await _pumpBanner(tester, controller);

        fake.available = true;
        controller.start();
        // Several poll intervals plus a foreground transition: every
        // automatic path this controller has, exercised with an update
        // sitting ready.
        await tester.pump(const Duration(milliseconds: 50));
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(const Key('pwa-update-button')), findsOneWidget);
        expect(fake.applyCalled, isFalse);

        await tester.tap(find.byKey(const Key('pwa-update-dismiss')));
        await tester.pump(const Duration(milliseconds: 50));
        expect(fake.applyCalled, isFalse);

        fake.available = false;
        controller.checkForUpdate();
        fake.available = true;
        controller.checkForUpdate();
        await tester.pump();
        await tester.tap(find.byKey(const Key('pwa-update-button')));
        await tester.pump();

        expect(fake.applyCalled, isTrue);

        // Not `addTearDown`: `start()`'s periodic timer has to be cancelled
        // inside the test body, before the binding checks for pending timers.
        controller.dispose();
      },
    );

    testWidgets('tapping dismiss hides the banner for this session', (
      tester,
    ) async {
      final fake = _FakePwaUpdate();
      final controller = PwaUpdateController(fake);
      addTearDown(controller.dispose);
      await _pumpBanner(tester, controller);

      fake.available = true;
      controller.checkForUpdate();
      await tester.pump();
      expect(find.text(loc.updateAvailableTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('pwa-update-dismiss')));
      await tester.pump();

      expect(find.text(loc.updateAvailableTitle), findsNothing);
    });
  });
}

/// English lookups, matching the repo convention of asserting against
/// [lookupAppLocalizations] rather than hard-coded literals.
final _en = lookupAppLocalizations(const Locale('en'));
