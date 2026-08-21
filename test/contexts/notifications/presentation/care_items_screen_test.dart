import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/care_items.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_screen.dart';
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/push_health.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  /// What the next [idToken] call resolves to. Mutable so a test can simulate
  /// Firebase renewing the token while the screen stays open.
  String token;

  _FakeAuthRepository({this.token = 'token-123'});

  @override
  Future<String?> idToken() async => token;

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

  /// Every id token [list] / [delete] were called with, in order — the *value
  /// that was sent*, which is what the token-freshness test asserts on.
  final List<String> listTokens = [];
  final List<String> deleteTokens = [];

  _FakeCareItemRepository({this.items = const []});

  @override
  Future<List<CareItem>> list(String idToken) async {
    listTokens.add(idToken);
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
    deleteTokens.add(idToken);
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

Future<void> _pumpScreen(
  WidgetTester tester,
  CareItemsController controller, {
  PushHealthController? pushHealthController,
  _FakeAuthRepository? authRepository,
}) async {
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: CareItemsScreen(
        controller: controller,
        authRepository: authRepository ?? _FakeAuthRepository(),
        pushHealthController:
            pushHealthController ?? testPushHealthController(PushHealth.ok),
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

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('care-items-empty-state')),
          matching: find.byType(EmptyStateGuide),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byIcon(Icons.health_and_safety_outlined),
        ),
        findsOneWidget,
      );
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

    // Deliberate pair with the interval-1 case below. The start date gates
    // every schedule (the backend's `isActiveOn` rejects any date before it
    // regardless of `weekInterval`), and the form lets it be set on every
    // schedule, so the summary has to show it on every schedule too.
    testWidgets(
      "includes the schedule's start date in the summary when weekInterval "
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

    testWidgets(
      "includes the schedule's start date in the summary at weekInterval == 1",
      (tester) async {
        final repository = _FakeCareItemRepository(items: [_medicationItem]);
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final context = tester.element(find.byType(Scaffold).first);
        final expectedFrom = loc.careScheduleFrom(
          mediumDateLabel(context, DateTime(2026, 7, 20)),
        );
        expect(find.textContaining(expectedFrom), findsOneWidget);
        // The every-N-weeks suffix stays interval-gated: unwrapping the start
        // date must not drag it out of its condition.
        expect(
          find.textContaining(loc.careWeekIntervalSuffix(1)),
          findsNothing,
        );
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

    // This screen used to fetch one token in `_load` and cache it in a field,
    // reusing it for every delete and for the form it pushes. Asserts on the
    // token the repository RECEIVED.
    testWidgets(
      'deleting after a token renewal carries the new token',
      (tester) async {
        final repository = _FakeCareItemRepository(items: [_medicationItem]);
        final auth = _FakeAuthRepository(token: 'token-1');
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          authRepository: auth,
        );

        expect(repository.listTokens, ['token-1']);

        // Firebase renewed the token while the list stayed open.
        auth.token = 'token-2';

        await tester.tap(find.byKey(const Key('care-item-delete-care-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-item-delete-confirm')));
        await tester.pumpAndSettle();

        expect(repository.deleteTokens, ['token-2']);
      },
    );

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
      'permissionPrompt: shows the push-off banner and tapping its action '
      'pushes /reminders',
      (tester) async {
        final controller = _controller();
        await _pumpScreen(
          tester,
          controller,
          pushHealthController: testPushHealthController(
            PushHealth.permissionPrompt,
          ),
        );

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('push-off-action')));
        await tester.pumpAndSettle();

        expect(find.text('/reminders'), findsOneWidget);
      },
    );

    testWidgets(
      'permissionDenied: shows the push-off banner even with no reminders '
      'yet — reaching this screen already expresses intent to use them',
      (tester) async {
        final controller = _controller();
        await _pumpScreen(
          tester,
          controller,
          pushHealthController: testPushHealthController(
            PushHealth.permissionDenied,
          ),
        );

        expect(find.byKey(const Key('care-items-empty-state')), findsOneWidget);
        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
      },
    );

    for (final health in [
      PushHealth.ok,
      PushHealth.unknown,
      PushHealth.unsupported,
      PushHealth.syncFailed,
    ]) {
      testWidgets('${health.name}: no push-off banner is shown', (
        tester,
      ) async {
        final controller = _controller();
        await _pumpScreen(
          tester,
          controller,
          pushHealthController: testPushHealthController(health),
        );

        expect(find.byKey(const Key('push-off-banner')), findsNothing);
      });
    }

    testWidgets(
      'a push-health change while the screen is open shows the banner '
      'without reopening it',
      (tester) async {
        final controller = _controller();
        final pushHealth = testPushHealthController(PushHealth.ok);
        await _pumpScreen(
          tester,
          controller,
          pushHealthController: pushHealth,
        );
        expect(find.byKey(const Key('push-off-banner')), findsNothing);

        pushHealth.health = PushHealth.permissionDenied;
        pushHealth.notifyListeners();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
      },
    );

    testWidgets('the AppBar history icon pushes /care-history', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('care-items-history-button')));
      await tester.pumpAndSettle();

      expect(find.text('/care-history'), findsOneWidget);
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
