import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/care_items.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_screen.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
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

class _FakeCareItemRepository implements CareItemRepository {
  List<CareItem> items;
  Object? listError;
  Object? mutateError;

  _FakeCareItemRepository({this.items = const []});

  @override
  Future<List<CareItem>> list(String idToken) async {
    if (listError != null) throw listError!;
    return items;
  }

  @override
  Future<CareItem> create(String idToken, CareItemDraft draft) async {
    if (mutateError != null) throw mutateError!;
    final created = CareItem(
      id: 'care-new',
      category: draft.category,
      title: draft.title,
      note: draft.note,
      dose: draft.dose,
      stock: draft.stock,
      stockAlert: draft.stockAlert,
      schedules: draft.schedules,
    );
    items = [...items, created];
    return created;
  }

  @override
  Future<CareItem> update(
    String idToken,
    String id,
    CareItemUpdate update,
  ) async {
    if (mutateError != null) throw mutateError!;
    final updated = CareItem(
      id: id,
      category: update.category,
      title: update.title,
      note: update.note,
      dose: update.dose,
      stock: update.stock,
      stockAlert: update.stockAlert,
      schedules: update.schedules,
    );
    items = [for (final i in items) if (i.id == id) updated else i];
    return updated;
  }

  @override
  Future<void> delete(String idToken, String id) async {
    if (mutateError != null) throw mutateError!;
    items = items.where((i) => i.id != id).toList();
  }
}

final _medicationItem = CareItem(
  id: 'care-1',
  category: CareCategory.medication,
  title: 'Metformin',
  note: 'take with food',
  stock: 30,
  schedules: [
    CareSchedule(
      id: 'sch-1',
      timeOfDay: '08:00',
      repeatDays: const [1, 3, 5],
      weekInterval: 1,
      startDate: DateTime(2026, 7, 20),
      doseQuantity: 1,
      nagIntervalMinutes: 0,
      enabled: true,
    ),
  ],
);

final _biweeklyItem = CareItem(
  id: 'care-3',
  category: CareCategory.medication,
  title: 'Biweekly shot',
  schedules: [
    CareSchedule(
      id: 'sch-3',
      timeOfDay: '09:00',
      repeatDays: const [1],
      weekInterval: 2,
      startDate: DateTime(2026, 7, 6),
      doseQuantity: 1,
      nagIntervalMinutes: 0,
      enabled: true,
    ),
  ],
);

final _rehabItem = CareItem(
  id: 'care-2',
  category: CareCategory.rehab,
  title: 'Stretching',
  schedules: [
    CareSchedule(
      id: 'sch-2',
      timeOfDay: '18:00',
      repeatDays: const [],
      weekInterval: 1,
      startDate: DateTime(2026, 7, 20),
      doseQuantity: 1,
      nagIntervalMinutes: 0,
      enabled: true,
    ),
  ],
);

CareItemsController _controller({CareItemRepository? repository}) {
  final repo = repository ?? _FakeCareItemRepository();
  return CareItemsController(
    ListCareItems(repo),
    CreateCareItem(repo),
    UpdateCareItem(repo),
    DeleteCareItem(repo),
  );
}

class _FakePushRepository implements PushRepository {
  @override
  Future<String> fetchVapidPublicKey(String idToken) async => 'fake-vapid-key';

  @override
  Future<void> saveSubscription(String idToken, PushSubscription subscription) async {}

  @override
  Future<TestPushResult> sendTest(String idToken) async =>
      const TestPushResult(sent: 0, failed: 0);
}

class _FakeWebPushGateway implements WebPushGateway {
  PushEnvironment environment = const PushEnvironment(
    supported: true,
    iosNeedsInstall: false,
  );
  PushPermissionStatus permission = PushPermissionStatus.prompt;

  @override
  PushEnvironment describeEnvironment() => environment;

  @override
  PushPermissionStatus permissionStatus() => permission;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) async => null;
}

/// A [ReminderSettingsController] whose [ReminderSettingsController.pushOn]
/// resolves to [pushOn] once [ReminderSettingsController.load] runs (driven
/// by the fake gateway's permission status — [ReminderSettingsController]
/// itself has no settable `pushOn`, only the derived getter under test).
ReminderSettingsController _reminderSettingsController({required bool pushOn}) {
  final gateway = _FakeWebPushGateway()
    ..permission = pushOn ? PushPermissionStatus.granted : PushPermissionStatus.prompt;
  final repository = _FakePushRepository();
  return ReminderSettingsController(
    gateway,
    EnableReminders(repository, gateway),
    SendTestPush(repository),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CareItemsController controller, {
  ReminderSettingsController? reminderSettingsController,
}) async {
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: CareItemsScreen(
        controller: controller,
        authRepository: _FakeAuthRepository(),
        reminderSettingsController:
            reminderSettingsController ?? _reminderSettingsController(pushOn: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CareItemsScreen', () {
    testWidgets('shows the empty-state guide when there are no reminders', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-items-empty-state')), findsOneWidget);
    });

    testWidgets('lists reminders grouped by category with a schedule summary', (
      tester,
    ) async {
      final repository = _FakeCareItemRepository(
        items: [_medicationItem, _rehabItem],
      );
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careCategoryMedication), findsOneWidget);
      expect(find.text(loc.careCategoryRehab), findsOneWidget);
      expect(find.byKey(const Key('care-item-row-care-1')), findsOneWidget);
      expect(find.byKey(const Key('care-item-row-care-2')), findsOneWidget);
      expect(find.textContaining('08:00'), findsOneWidget);
      // Empty repeatDays renders as "every day".
      expect(find.textContaining(loc.careEveryDay), findsOneWidget);
      expect(
        find.byKey(const Key('care-items-empty-state')),
        findsNothing,
      );
    });

    testWidgets(
      "includes the schedule's start date in the summary once weekInterval "
      'is above 1',
      (tester) async {
        final repository = _FakeCareItemRepository(items: [_biweeklyItem]);
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final context = tester.element(find.byType(Scaffold).first);
        final expectedFrom = loc.careScheduleFrom(
          mediumDateLabel(context, DateTime(2026, 7, 6)),
        );
        expect(find.textContaining(expectedFrom), findsOneWidget);
      },
    );

    testWidgets('shows stock for a medication reminder', (tester) async {
      final repository = _FakeCareItemRepository(items: [_medicationItem]);
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careStockLabel('30')), findsOneWidget);
    });

    testWidgets('the FAB opens the add form', (tester) async {
      final controller = _controller();
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('care-items-add-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-item-title-field')), findsOneWidget);
    });

    testWidgets('tapping a row opens the edit form pre-filled', (tester) async {
      final repository = _FakeCareItemRepository(items: [_medicationItem]);
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('care-item-row-care-1')));
      await tester.pumpAndSettle();

      expect(find.text('Metformin'), findsOneWidget);
    });

    testWidgets('deleting a reminder requires confirmation', (tester) async {
      final repository = _FakeCareItemRepository(items: [_medicationItem]);
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('care-item-delete-care-1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('care-item-delete-confirm')),
        findsOneWidget,
      );

      // Cancel leaves the reminder in place.
      await tester.tap(find.byKey(const Key('care-item-delete-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('care-item-row-care-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-item-delete-care-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-item-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-item-row-care-1')), findsNothing);
      expect(find.byKey(const Key('care-items-empty-state')), findsOneWidget);
    });

    testWidgets('a load reauth failure shows the full-screen reauth exit', (
      tester,
    ) async {
      final repository = _FakeCareItemRepository()
        ..listError = const CareReauthRequired();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      expect(find.byKey(const Key('care-items-add-fab')), findsNothing);
    });

    testWidgets(
      'reopening the add form after a failed create does not show a stale '
      'error banner',
      (tester) async {
        // The form's content can exceed the default 800x600 test surface —
        // a taller surface keeps the add-schedule button reachable.
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FakeCareItemRepository()
          ..mutateError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-items-add-fab')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('care-item-title-field')),
          'Metformin',
        );
        await tester.ensureVisible(
          find.byKey(const Key('care-item-add-schedule')),
        );
        await tester.tap(find.byKey(const Key('care-item-add-schedule')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('care-item-form-submit')),
        );
        await tester.tap(find.byKey(const Key('care-item-form-submit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-item-form-error')), findsOneWidget);
        expect(controller.mutationError, isNotNull);

        // Back to the list, then reopen the (still-erroring) add form fresh.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-items-add-fab')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-item-form-error')), findsNothing);
      },
    );

    testWidgets(
      'pushOn=false: shows the push-off banner and tapping its action '
      'pushes /reminders',
      (tester) async {
        final controller = _controller();
        await _pumpScreen(
          tester,
          controller,
          reminderSettingsController: _reminderSettingsController(pushOn: false),
        );

        expect(
          find.byKey(const Key('care-items-push-off-banner')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('care-items-push-off-action')));
        await tester.pumpAndSettle();

        expect(find.text('/reminders'), findsOneWidget);
      },
    );

    testWidgets('pushOn=true: no push-off banner is shown', (tester) async {
      final controller = _controller();
      await _pumpScreen(
        tester,
        controller,
        reminderSettingsController: _reminderSettingsController(pushOn: true),
      );

      expect(
        find.byKey(const Key('care-items-push-off-banner')),
        findsNothing,
      );
    });

    testWidgets(
      'a load failure shows a retry button that reloads the list',
      (tester) async {
        final repository = _FakeCareItemRepository()
          ..listError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('care-items-load-error')),
          findsOneWidget,
        );

        repository.listError = null;
        repository.items = [_medicationItem];
        await tester.tap(find.byKey(const Key('care-items-retry-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-item-row-care-1')), findsOneWidget);
      },
    );
  });
}
