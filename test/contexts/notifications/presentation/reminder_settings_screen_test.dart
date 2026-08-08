import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<String?> idToken() async => 'token-123';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _FakePushRepository implements PushRepository {
  String vapidPublicKey = 'fake-vapid-key';
  Object? sendTestError;
  TestPushResult testResult = const TestPushResult(sent: 2, failed: 1);
  Completer<TestPushResult>? sendTestCompleter;

  @override
  Future<String> fetchVapidPublicKey(String idToken) async => vapidPublicKey;

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) async {}

  @override
  Future<TestPushResult> sendTest(String idToken) {
    if (sendTestCompleter != null) return sendTestCompleter!.future;
    if (sendTestError != null) throw sendTestError!;
    return Future.value(testResult);
  }
}

class _FakeWebPushGateway implements WebPushGateway {
  PushEnvironment environment = const PushEnvironment(
    supported: true,
    iosNeedsInstall: false,
  );
  PushSubscription? subscriptionToReturn = const PushSubscription(
    endpoint: 'https://push.example/abc',
    p256dh: 'p256dh-key',
    auth: 'auth-key',
  );
  Completer<PushSubscription?>? enableCompleter;
  PushPermissionStatus permission = PushPermissionStatus.prompt;

  @override
  PushEnvironment describeEnvironment() => environment;

  @override
  PushPermissionStatus permissionStatus() => permission;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) {
    if (enableCompleter != null) return enableCompleter!.future;
    return Future.value(subscriptionToReturn);
  }
}

ReminderSettingsController _controller({
  _FakePushRepository? repository,
  _FakeWebPushGateway? gateway,
}) {
  final repo = repository ?? _FakePushRepository();
  final gw = gateway ?? _FakeWebPushGateway();
  return ReminderSettingsController(
    gw,
    EnableReminders(repo, gw),
    SendTestPush(repo),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ReminderSettingsController controller,
) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: ReminderSettingsScreen(
        controller: controller,
        authRepository: _FakeAuthRepository(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ReminderSettingsScreen', () {
    testWidgets('idle state shows the enable button', (tester) async {
      final controller = _controller();
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('reminder-enable-button')), findsOneWidget);
      expect(find.byKey(const Key('reminder-test-button')), findsNothing);
    });

    testWidgets('unsupported state explains and hides the enable button', (
      tester,
    ) async {
      final gateway = _FakeWebPushGateway()
        ..environment = const PushEnvironment(
          supported: false,
          iosNeedsInstall: false,
        );
      final controller = _controller(gateway: gateway);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.reminderStatusUnsupported), findsOneWidget);
      expect(find.byKey(const Key('reminder-enable-button')), findsNothing);
    });

    testWidgets(
      'iosNeedsInstall state shows the add-to-home-screen hint and hides '
      'the enable button',
      (tester) async {
        final gateway = _FakeWebPushGateway()
          ..environment = const PushEnvironment(
            supported: false,
            iosNeedsInstall: true,
          );
        final controller = _controller(gateway: gateway);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.reminderStatusIosNeedsInstall), findsOneWidget);
        expect(find.byKey(const Key('reminder-enable-button')), findsNothing);
      },
    );

    testWidgets('tapping enable shows a loading state, then enabled with '
        'the test button', (tester) async {
      final gateway = _FakeWebPushGateway();
      final enableCompleter = Completer<PushSubscription?>();
      gateway.enableCompleter = enableCompleter;
      final controller = _controller(gateway: gateway);
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('reminder-enable-button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('reminder-enable-button')),
      );
      expect(button.onPressed, isNull);

      enableCompleter.complete(gateway.subscriptionToReturn);
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.reminderEnabledStatus), findsOneWidget);
      expect(find.byKey(const Key('reminder-test-button')), findsOneWidget);
      expect(find.byKey(const Key('reminder-enable-button')), findsNothing);
    });

    testWidgets('denying permission shows the permissionDenied guidance', (
      tester,
    ) async {
      final gateway = _FakeWebPushGateway()..subscriptionToReturn = null;
      final controller = _controller(gateway: gateway);
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('reminder-enable-button')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.reminderStatusPermissionDenied), findsOneWidget);
      expect(find.byKey(const Key('reminder-enable-button')), findsNothing);
    });

    testWidgets('permissionDenied shows a re-check button that re-resolves the '
        'environment via load()', (tester) async {
      final gateway = _FakeWebPushGateway()
        ..permission = PushPermissionStatus.denied;
      final controller = _controller(gateway: gateway);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.reminderStatusPermissionDenied), findsOneWidget);
      expect(find.byKey(const Key('reminder-recheck-button')), findsOneWidget);

      // Simulate the user having fixed their browser settings, then
      // tapping re-check.
      gateway.permission = PushPermissionStatus.prompt;
      await tester.tap(find.byKey(const Key('reminder-recheck-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminder-enable-button')), findsOneWidget);
      expect(find.byKey(const Key('reminder-recheck-button')), findsNothing);
      expect(
        find.byKey(const Key('reminder-recheck-blocked-snackbar')),
        findsNothing,
      );
    });

    testWidgets(
      'permissionDenied re-check still blocked shows a SnackBar so the user '
      'can tell the check ran',
      (tester) async {
        final gateway = _FakeWebPushGateway()
          ..permission = PushPermissionStatus.denied;
        final controller = _controller(gateway: gateway);
        await _pumpScreen(tester, controller);

        // Permission is still denied — re-check should surface feedback
        // rather than silently doing nothing.
        await tester.tap(find.byKey(const Key('reminder-recheck-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.byKey(const Key('reminder-recheck-blocked-snackbar')),
          findsOneWidget,
        );
        expect(find.text(loc.reminderStillBlocked), findsOneWidget);
        expect(
          find.byKey(const Key('reminder-recheck-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a generic enable failure shows an actionable error with a retry '
      'button that re-triggers enable',
      (tester) async {
        final repository = _FakePushRepository();
        final gateway = _FakeWebPushGateway();
        // First call fails; force it via a fetch that throws.
        final failingRepo = _FailingOnceRepository(repository);
        final controller = ReminderSettingsController(
          gateway,
          EnableReminders(failingRepo, gateway),
          SendTestPush(failingRepo),
        );
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('reminder-enable-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.reminderErrorGeneric), findsOneWidget);
        expect(find.byKey(const Key('reminder-enable-button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('reminder-enable-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.reminderEnabledStatus), findsOneWidget);
      },
    );

    testWidgets(
      'a reauth failure shows the shared please-sign-in-again message',
      (tester) async {
        final repository = _FakePushRepository();
        final gateway = _FakeWebPushGateway();
        final failingRepo = _ReauthOnceRepository(repository);
        final controller = ReminderSettingsController(
          gateway,
          EnableReminders(failingRepo, gateway),
          SendTestPush(failingRepo),
        );
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('reminder-enable-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      },
    );

    testWidgets('sending a test push that reaches a device shows the human '
        'success SnackBar', (tester) async {
      final repository = _FakePushRepository()
        ..testResult = const TestPushResult(sent: 3, failed: 1);
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);
      await tester.tap(find.byKey(const Key('reminder-enable-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reminder-test-button')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.reminderTestSent), findsOneWidget);
    });

    testWidgets(
      'a reauth failure on sendTest shows the full-screen reauth exit and '
      'not the test SnackBar',
      (tester) async {
        final repository = _FakePushRepository()
          ..sendTestError = const PushReauthRequired();
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);
        await tester.tap(find.byKey(const Key('reminder-enable-button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reminder-test-button')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
        expect(find.byKey(const Key('reminder-test-snackbar')), findsNothing);
      },
    );

    testWidgets(
      'a test push in flight shows a loading state and blocks re-entry',
      (tester) async {
        final repository = _FakePushRepository();
        final sendTestCompleter = Completer<TestPushResult>();
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);
        await tester.tap(find.byKey(const Key('reminder-enable-button')));
        await tester.pumpAndSettle();

        repository.sendTestCompleter = sendTestCompleter;
        await tester.tap(find.byKey(const Key('reminder-test-button')));
        await tester.pump();

        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('reminder-test-button')),
        );
        expect(button.onPressed, isNull);

        sendTestCompleter.complete(const TestPushResult(sent: 1, failed: 0));
        await tester.pumpAndSettle();
      },
    );
  });
}

/// A [PushRepository] wrapping [_delegate] whose `fetchVapidPublicKey` fails
/// once with [PushRequestFailed], then delegates normally.
class _FailingOnceRepository implements PushRepository {
  final PushRepository _delegate;
  bool _failed = false;

  _FailingOnceRepository(this._delegate);

  @override
  Future<String> fetchVapidPublicKey(String idToken) async {
    if (!_failed) {
      _failed = true;
      throw const PushRequestFailed();
    }
    return _delegate.fetchVapidPublicKey(idToken);
  }

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) => _delegate.saveSubscription(idToken, subscription);

  @override
  Future<TestPushResult> sendTest(String idToken) =>
      _delegate.sendTest(idToken);
}

/// A [PushRepository] wrapping [_delegate] whose `fetchVapidPublicKey` always
/// throws [PushReauthRequired].
class _ReauthOnceRepository implements PushRepository {
  final PushRepository _delegate;

  _ReauthOnceRepository(this._delegate);

  @override
  Future<String> fetchVapidPublicKey(String idToken) async {
    throw const PushReauthRequired();
  }

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) => _delegate.saveSubscription(idToken, subscription);

  @override
  Future<TestPushResult> sendTest(String idToken) =>
      _delegate.sendTest(idToken);
}
