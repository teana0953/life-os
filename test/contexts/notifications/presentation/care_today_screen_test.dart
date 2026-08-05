import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_screen.dart';
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/push_health.dart';

class _FakeAuthRepository implements AuthRepository {
  /// What the next [idToken] call resolves to. Mutable so a test can simulate
  /// Firebase renewing the token while the screen stays open.
  String token;

  /// When set, [idToken] throws — the shape `getIdToken()` takes when a
  /// renewal has to reach the network and that fails.
  bool throws = false;

  _FakeAuthRepository({this.token = 'token-123'});

  @override
  Future<String?> idToken() async {
    if (throws) throw Exception('token renewal failed');
    return token;
  }

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

CareTodaySlot _withStatus(
  CareTodaySlot slot,
  CareTodayStatus status, {
  String? doneTime,
}) => CareTodaySlot(
  careItemId: slot.careItemId,
  careScheduleId: slot.careScheduleId,
  category: slot.category,
  title: slot.title,
  note: slot.note,
  dose: slot.dose,
  timeOfDay: slot.timeOfDay,
  localDate: slot.localDate,
  status: status,
  doneTime: doneTime,
  doseQuantity: slot.doseQuantity,
);

class _FakeCareTodayRepository implements CareTodayRepository {
  CareToday today;
  Object? getError;

  /// Number of leading [getToday] calls that still succeed before [getError]
  /// starts being thrown — lets a test fail only the *reload* that follows a
  /// successful edit, leaving the screen's initial load intact.
  int getErrorAfterCalls = 0;
  int getCalls = 0;

  /// Every id token [getToday] / [logSlot] were called with, in order — the
  /// *value that was sent*, which is what the token-freshness test asserts on.
  final List<String> getTokens = [];
  final List<String> logTokens = [];

  Object? logError;
  Completer<void>? logCompleter;

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async {
    getTokens.add(idToken);
    getCalls++;
    if (getError != null && getCalls > getErrorAfterCalls) throw getError!;
    return today;
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    logTokens.add(idToken);
    if (logCompleter != null) await logCompleter!.future;
    if (logError != null) throw logError!;
    today = CareToday(
      date: today.date,
      slots: [
        for (final s in today.slots)
          if (s.careScheduleId == careScheduleId)
            _withStatus(
              s,
              status == CareLogStatus.done
                  ? CareTodayStatus.done
                  : CareTodayStatus.skipped,
              // A real UTC instant (not the pre-fix '08:05' — a non-ISO
              // string `tryParse` would silently fail on, masking a missing
              // `.toLocal()` conversion). Tests that care about the
              // displayed time inject a fixed-offset `toLocalTime` and
              // assert against that conversion, not the raw UTC value.
              doneTime: status == CareLogStatus.done
                  ? '2026-07-22T00:05:00.000Z'
                  : null,
            )
          else
            s,
      ],
    );
  }
}

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  String title = 'Metformin',
  CareTodayStatus status = CareTodayStatus.pending,
  String timeOfDay = '08:00',
  String? doneTime,
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: title,
  note: 'take with food',
  dose: '500mg',
  timeOfDay: timeOfDay,
  localDate: '2026-07-22',
  status: status,
  doneTime: doneTime,
  doseQuantity: 1,
);

class _FakeCareHistoryRepository implements CareHistoryRepository {
  Object? editError;
  Completer<void>? editCompleter;
  int editCalls = 0;
  CareLogStatus? lastStatus;
  DateTime? lastDoneTime;
  String? lastCareScheduleId;
  String? lastLocalDate;
  String? lastTimeOfDay;

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async => const [];

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  }) async {
    editCalls++;
    lastStatus = status;
    lastDoneTime = doneTime;
    lastCareScheduleId = careScheduleId;
    lastLocalDate = localDate;
    lastTimeOfDay = timeOfDay;
    if (editCompleter != null) await editCompleter!.future;
    if (editError != null) throw editError!;
  }
}

CareTodayController _controller({
  CareTodayRepository? repository,
  CareHistoryRepository? historyRepository,
}) {
  final repo =
      repository ??
      _FakeCareTodayRepository(today: const CareToday(date: '2026-07-22', slots: []));
  return CareTodayController(
    GetCareToday(repo),
    MarkCareDone(repo),
    MarkCareSkipped(repo),
    EditCareSlot(historyRepository ?? _FakeCareHistoryRepository()),
  );
}

/// Matches [CareTodayScreen]'s own default — the tests that don't care about
/// the local-time conversion don't need a non-identity one.
DateTime _testDefaultToLocal(DateTime dt) => dt.toLocal();

/// The default [CareTodayScreen.pickDoneTime] for tests that never open the
/// Done-group edit sheet — throws if actually invoked (rather than driving
/// the real, un-drivable `showTimePicker`), so a test that forgets to inject
/// one fails loudly instead of hanging.
Future<DateTime?> _unusedPickDoneTime(
  BuildContext context,
  CareTodaySlot slot,
  DateTime? current,
  DateTime Function(DateTime) toLocalTime,
) => throw UnimplementedError('pickDoneTime was not injected for this test');

/// Pumps the screen. Pass `pickDoneTime: null` to leave the screen's *own*
/// default in place — the only way to exercise the real
/// `showTimePicker`-backed picker (slot date + picked time → UTC); every
/// other test injects a fake so it never has to drive the picker UI.
Future<void> _pumpScreen(
  WidgetTester tester,
  CareTodayController controller, {
  VoidCallback? onOpenCareItems,
  DateTime Function(DateTime) toLocalTime = _testDefaultToLocal,
  Future<DateTime?> Function(
    BuildContext,
    CareTodaySlot,
    DateTime?,
    DateTime Function(DateTime),
  )?
  pickDoneTime = _unusedPickDoneTime,
  Size surfaceSize = const Size(800, 1600),
  PushHealthController? pushHealthController,
  _FakeAuthRepository? authRepository,
}) async {
  final resolvedAuthRepository = authRepository ?? _FakeAuthRepository();
  // The focus card + Overdue/Later/Done sections can exceed the default
  // 800x600 test surface — a taller surface keeps every section built (a
  // ListView only builds children within its viewport/cache extent).
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: pickDoneTime == null
          ? CareTodayScreen(
              controller: controller,
              authRepository: resolvedAuthRepository,
              onOpenCareItems: onOpenCareItems ?? () {},
              pushHealthController:
                  pushHealthController ?? testPushHealthController(PushHealth.ok),
              toLocalTime: toLocalTime,
            )
          : CareTodayScreen(
              controller: controller,
              authRepository: resolvedAuthRepository,
              onOpenCareItems: onOpenCareItems ?? () {},
              pushHealthController:
                  pushHealthController ?? testPushHealthController(PushHealth.ok),
              toLocalTime: toLocalTime,
              pickDoneTime: pickDoneTime,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CareTodayScreen', () {
    testWidgets('the focus card shows the most-urgent slot with Done/Skip, '
        'and it is not duplicated in its group (FIX 1)', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-22',
          slots: [
            _slot(careScheduleId: 'sch-pending', status: CareTodayStatus.pending, timeOfDay: '07:00'),
            _slot(
              careScheduleId: 'sch-overdue',
              title: 'Overdue dose',
              status: CareTodayStatus.overdue,
              timeOfDay: '09:00',
            ),
          ],
        ),
      );
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-today-focus-card')), findsOneWidget);
      expect(find.byKey(const Key('care-today-focus-done')), findsOneWidget);
      expect(find.byKey(const Key('care-today-focus-skip')), findsOneWidget);
      // The sole overdue slot is the focus — it must render once (in the
      // focus card), not again as the first row of the Overdue group.
      expect(find.text('Overdue dose'), findsOneWidget);
      expect(find.byKey(const Key('care-today-row-sch-overdue')), findsNothing);
    });

    testWidgets('slots are grouped into Overdue / Later / Done sections', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-22',
          slots: [
            // Earliest overdue — becomes the focus (FIX 1), excluded from
            // the Overdue group below.
            _slot(careScheduleId: 'sch-overdue-focus', status: CareTodayStatus.overdue, timeOfDay: '07:00'),
            _slot(careScheduleId: 'sch-overdue', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
            _slot(careScheduleId: 'sch-later', title: 'Later dose', status: CareTodayStatus.pending, timeOfDay: '18:00'),
            _slot(careScheduleId: 'sch-done', title: 'Done dose', status: CareTodayStatus.done, timeOfDay: '06:00'),
          ],
        ),
      );
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careTodayOverdueSection), findsOneWidget);
      expect(find.byKey(const Key('care-today-row-sch-overdue')), findsOneWidget);
      expect(
        find.byKey(const Key('care-today-row-sch-overdue-focus')),
        findsNothing,
      );
      expect(find.text(loc.careTodayLaterSection), findsOneWidget);
      expect(find.text(loc.careTodayDoneSection(1)), findsOneWidget);
      expect(find.byKey(const Key('care-today-row-sch-later')), findsOneWidget);
      // The Done section starts collapsed.
      expect(
        find.byKey(const Key('care-today-row-sch-done-2026-07-22-06:00')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('care-today-done-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('care-today-row-sch-done-2026-07-22-06:00')),
        findsOneWidget,
      );
    });

    // This screen used to fetch one token in `_load` and cache it in a field,
    // reusing it for every mark/edit — the same bug as the shells, on a
    // shorter clock. Asserts on the token the repository RECEIVED.
    testWidgets(
      'marking a slot after a token renewal carries the new token',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
            ],
          ),
        );
        final auth = _FakeAuthRepository(token: 'token-1');
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          authRepository: auth,
        );

        expect(repository.getTokens, ['token-1']);

        // Firebase renewed the token while the checklist stayed open.
        auth.token = 'token-2';

        await tester.tap(find.byKey(const Key('care-today-focus-done')));
        await tester.pumpAndSettle();

        expect(repository.logTokens, ['token-2']);
      },
    );

    testWidgets(
      'an inline Done reloads quietly: the list stays visible during the '
      'reload, then the row moves to Done (design D2 — no full-screen '
      'loading flash)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
              _slot(careScheduleId: 'sch-2', title: 'Later dose', status: CareTodayStatus.pending, timeOfDay: '18:00'),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        // A fixed +8h offset, not `.toLocal()` — the CI runner is UTC, where
        // `.toLocal()` is identity and this test would pass even if the
        // screen forgot the conversion entirely (design §C).
        await _pumpScreen(
          tester,
          controller,
          toLocalTime: (dt) => dt.add(const Duration(hours: 8)),
        );

        expect(find.byKey(const Key('care-today-focus-card')), findsOneWidget);

        final completer = Completer<void>();
        repository.logCompleter = completer;
        await tester.tap(find.byKey(const Key('care-today-focus-done')));
        await tester.pump();

        // Mid-reload: the list is still rendered — no full-screen spinner
        // replaced it.
        expect(find.byKey(const Key('care-today-focus-card')), findsOneWidget);
        expect(controller.marking, isTrue);

        completer.complete();
        await tester.pumpAndSettle();

        // sch-1 moved to Done; sch-2 (the only remaining pending slot) is
        // now the focus.
        expect(controller.marking, isFalse);
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text('Later dose'), findsWidgets);
        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
          findsOneWidget,
        );
        // The recorded doneTime is UTC 00:05; the injected +8h conversion
        // proves the row actually applies `toLocalTime` rather than showing
        // the raw UTC string.
        expect(find.text(loc.careTodayDoneAtLabel('08:05')), findsOneWidget);
      },
    );

    testWidgets('shows the all-done celebration when nothing is pending or overdue', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-22',
          slots: [_slot(status: CareTodayStatus.done)],
        ),
      );
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-today-celebration')), findsOneWidget);
      expect(find.byKey(const Key('care-today-focus-card')), findsNothing);
    });

    testWidgets('shows the empty-state guide when there are no schedules today', (
      tester,
    ) async {
      var opened = false;
      final controller = _controller();
      await _pumpScreen(tester, controller, onOpenCareItems: () => opened = true);

      expect(find.byKey(const Key('care-today-empty-state')), findsOneWidget);

      await tester.tap(find.byKey(const Key('care-today-empty-manage-button')));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('the AppBar history icon pushes /care-history', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('care-today-history-button')));
      await tester.pumpAndSettle();

      expect(find.text('/care-history'), findsOneWidget);
    });

    testWidgets('a load reauth failure shows the full-screen reauth exit', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: const CareToday(date: '2026-07-22', slots: []),
      )..getError = const CareReauthRequired();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      expect(find.byKey(const Key('care-today-empty-state')), findsNothing);
    });

    testWidgets('a load failure shows a retry button that reloads the list', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: const CareToday(date: '2026-07-22', slots: []),
      )..getError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-today-load-error')), findsOneWidget);

      repository.getError = null;
      repository.today = CareToday(
        date: '2026-07-22',
        slots: [_slot(status: CareTodayStatus.done)],
      );
      await tester.tap(find.byKey(const Key('care-today-retry-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-today-celebration')), findsOneWidget);
    });

    testWidgets('a failed mark shows a SnackBar and keeps the list', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-22',
          slots: [_slot(status: CareTodayStatus.overdue)],
        ),
      )..logError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('care-today-focus-done')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careErrorGeneric), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('care-today-focus-card')), findsOneWidget);
    });

    testWidgets(
      'the failed-mark SnackBar has a Retry action that re-invokes the mark',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        )..logError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-focus-done')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.retry), findsOneWidget);

        // Clear the error and retry — the same mark should succeed this
        // time.
        repository.logError = null;
        await tester.tap(find.text(loc.retry));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-today-celebration')), findsOneWidget);
      },
    );

    testWidgets(
      'the Done group shows distinct status text for skipped vs missed rows '
      '(FIX 5)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-skipped', title: 'Skipped dose', status: CareTodayStatus.skipped, timeOfDay: '07:00'),
              _slot(careScheduleId: 'sch-missed', title: 'Missed dose', status: CareTodayStatus.missed, timeOfDay: '06:00'),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text('07:00 · ${loc.careTodayStatusSkipped}'),
          findsOneWidget,
        );
        expect(
          find.text('06:00 · ${loc.careTodayStatusMissed}'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'during a mark, only the acted-on row spins — but every row disables, '
      'because the re-entrancy gate is global (FIX 8 + design §B)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.pending, timeOfDay: '08:00'),
              _slot(careScheduleId: 'sch-2', title: 'Later dose', status: CareTodayStatus.pending, timeOfDay: '09:00'),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final completer = Completer<void>();
        repository.logCompleter = completer;
        await tester.tap(find.byKey(const Key('care-today-focus-done')));
        await tester.pump();

        expect(controller.marking, isTrue);
        final focusDoneButton = tester.widget<FilledButton>(
          find.byKey(const Key('care-today-focus-done')),
        );
        expect(focusDoneButton.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // The other row carries no spinner — that part is still per row —
        // but its buttons are disabled all the same: the controller's gate
        // is one global flag, so a tap here would be dropped in silence.
        expect(
          find.descendant(
            of: find.byKey(const Key('care-today-row-sch-2')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('care-today-row-done-sch-2')),
              )
              .onPressed,
          isNull,
        );

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Re-enabled once the mark settles (sch-2 is the focus slot by now —
        // sch-1 moved to Done — so it is the focus card's button that has to
        // be live again).
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('care-today-focus-done')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'a narrow surface does not overflow a long-titled group row (FIX 9)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-focus', status: CareTodayStatus.pending, timeOfDay: '07:00'),
              _slot(
                careScheduleId: 'sch-long',
                title:
                    'A very long custom care reminder title that keeps going and going and going',
                status: CareTodayStatus.pending,
                timeOfDay: '09:00',
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await tester.binding.setSurfaceSize(const Size(300, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          l10nTestApp(
            home: CareTodayScreen(
              controller: controller,
              authRepository: _FakeAuthRepository(),
              onOpenCareItems: () {},
              pushHealthController: testPushHealthController(PushHealth.ok),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('care-today-row-done-sch-long')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-today-row-skip-sch-long')),
          findsOneWidget,
        );
      },
    );
  });

  group('CareTodayScreen Done-group correction sheet', () {
    testWidgets(
      'a done row (including missed) offers an edit affordance that opens a '
      'correction sheet headed with the item, date, time, and current '
      'status',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                careScheduleId: 'sch-missed',
                title: 'Missed dose',
                status: CareTodayStatus.missed,
                timeOfDay: '07:00',
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        final rowKey = const Key('care-today-row-sch-missed-2026-07-22-07:00');
        expect(find.byKey(rowKey), findsOneWidget);
        // The row shows an edit affordance rather than looking read-only.
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

        await tester.tap(find.byKey(rowKey));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careTodayEditSheetTitle), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('care-today-edit-sheet-title')))
              .data,
          'Missed dose',
        );
        final expectedDate = mediumDateLabel(
          tester.element(find.byType(CareTodayScreen)),
          DateTime(2026, 7, 22),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('care-today-edit-sheet-subtitle')),
              )
              .data,
          '$expectedDate · 07:00 · ${loc.careTodayStatusMissed}',
        );
        expect(find.byKey(const Key('care-today-edit-status-done')), findsOneWidget);
        expect(
          find.byKey(const Key('care-today-edit-status-skipped')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('care-today-edit-time')), findsOneWidget);
        expect(find.byKey(const Key('care-today-edit-submit')), findsOneWidget);
      },
    );

    // The row's edit icon otherwise reads to a screen reader as a bare,
    // unlabelled "button" — the same generic announcement as any other
    // icon-only affordance on the row. A verb label ("Edit"), not the
    // sheet's own noun-phrase title (careTodayEditSheetTitle, "Update this
    // record") — the two ARB keys serve different UI spots and must not
    // collapse into one.
    testWidgets(
      "the Done row's edit icon carries an assistive-technology label",
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
            matching: find.byIcon(Icons.edit_outlined),
          ),
        );
        expect(icon.semanticLabel, loc.careEditActionLabel);
      },
    );

    // The default 9/16 sheet-height cap and the scrim/system-back gesture
    // are the only dismiss routes without this — neither is discoverable by
    // a screen-reader or keyboard user scanning the sheet's own content.
    testWidgets(
      'the correction sheet exposes a reachable drag handle to dismiss it',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
          isTrue,
        );
      },
    );

    testWidgets(
      'choosing Skipped disables the completion-time row — a skip never '
      'carries a completion time',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done)],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-today-edit-status-skipped')));
        await tester.pumpAndSettle();

        final timeTile = tester.widget<ListTile>(
          find.byKey(const Key('care-today-edit-time')),
        );
        expect(timeTile.enabled, isFalse);
      },
    );

    testWidgets(
      'submitting Done with a picked time edits the slot identified by its '
      "own careScheduleId/localDate/timeOfDay, with the picked doneTime — "
      'and the list reloads quietly (no full-page loading state)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                careScheduleId: 'sch-1',
                status: CareTodayStatus.missed,
                timeOfDay: '08:00',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        // Built from the slot's own localDate (2026-07-22), not "today" —
        // the injected pickDoneTime stands in for the real time picker
        // (bypassing it entirely, mirroring today_screen_test.dart's
        // pickMealTime injection).
        final pickedDoneTime = DateTime.utc(2026, 7, 22, 12, 30);
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, ___, ____) async => pickedDoneTime,
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-today-edit-status-done')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();

        // sch-1's next getToday() reflects the correction — the fake
        // CareHistoryRepository above doesn't mutate the CareTodayRepository
        // fake's data, so the test seeds the post-edit state the same way
        // the existing inline-mark test does.
        repository.today = CareToday(
          date: '2026-07-22',
          slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
        );

        // Hold the PUT in flight so the *mid-edit* frame can be inspected —
        // the quiet-reload claim is only falsifiable while the edit is
        // running; after pumpAndSettle everything is back on screen either
        // way.
        final editCompleter = Completer<void>();
        historyRepository.editCompleter = editCompleter;
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pump();

        // The checklist is still rendered mid-edit — the screen never
        // replaced it with the full-page spinner or error state (design
        // D2/§B).
        expect(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('care-today-load-error')), findsNothing);

        editCompleter.complete();
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastCareScheduleId, 'sch-1');
        expect(historyRepository.lastLocalDate, '2026-07-22');
        expect(historyRepository.lastTimeOfDay, '08:00');
        expect(historyRepository.lastStatus, CareLogStatus.done);
        expect(historyRepository.lastDoneTime, pickedDoneTime);
      },
    );

    testWidgets(
      'a composite key lets a schedule that fires twice a day be edited '
      "correctly — tapping the later slot's row opens a sheet for that "
      'slot, not the earlier one',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.done, timeOfDay: '08:00'),
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.done, timeOfDay: '20:00'),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-20:00')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-20:00')),
        );
        await tester.pumpAndSettle();

        final subtitle = tester
            .widget<Text>(find.byKey(const Key('care-today-edit-sheet-subtitle')))
            .data;
        expect(subtitle, contains('20:00'));
        // The *other* slot's scheduled time must not appear at all — the
        // discriminating half of this test: with the pre-fix single-id key
        // the tap resolved to the 08:00 row and the sheet headed itself
        // '… · 08:00 · …'.
        expect(subtitle, isNot(contains('08:00')));
      },
    );

    testWidgets(
      'editing shows an in-flight indicator on the row (and disables it), '
      'and a failed edit shows a SnackBar and keeps the list',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done)],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository()
          ..editError = const CareRequestFailed();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        final completer = Completer<void>();
        historyRepository.editCompleter = completer;
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        // Don't settle — the in-flight indicator animates indefinitely.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
          findsOneWidget,
        );
        final row = tester.widget<ListTile>(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        expect(row.onTap, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete();
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careErrorGeneric), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        // task 4.5: a failed correction offers a retry, same as the inline
        // mark path.
        expect(find.text(loc.retry), findsOneWidget);
        // The list is kept — the row is still there.
        expect(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
          findsOneWidget,
        );
      },
    );

    // task 4.5/4.6: retrying a failed correction must resend exactly what
    // the user already picked in the (now-closed) sheet — not force them
    // to reopen it and pick again. This is the only test that actually
    // exercises the resend: the SnackBar test above only confirms a retry
    // action exists.
    testWidgets(
      "retrying a failed correction resends the same (status, doneTime) the "
      'user already chose, without reopening the sheet',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(status: CareTodayStatus.missed, timeOfDay: '07:00'),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository()
          ..editError = const CareRequestFailed();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        final pickedDoneTime = DateTime.utc(2026, 7, 22, 9, 15);
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, ___, ____) async => pickedDoneTime,
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-07:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-status-done')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastDoneTime, pickedDoneTime);
        // The sheet is gone — retry must not need it.
        expect(find.byKey(const Key('care-today-edit-submit')), findsNothing);

        // The next attempt succeeds — proves the retry actually re-ran the
        // edit rather than just dismissing the SnackBar.
        historyRepository.editError = null;
        repository.today = CareToday(
          date: '2026-07-22',
          slots: [_slot(status: CareTodayStatus.done, timeOfDay: '07:00')],
        );
        final loc = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(loc.retry));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 2);
        expect(historyRepository.lastCareScheduleId, 'sch-1');
        expect(historyRepository.lastStatus, CareLogStatus.done);
        // The exact same picked time, not re-derived from the slot.
        expect(historyRepository.lastDoneTime, pickedDoneTime);
        expect(find.text(loc.careErrorGeneric), findsNothing);
      },
    );

    testWidgets(
      'a correction dropped by the in-flight guard is not silent (design '
      '§B) — a second stacked sheet\'s submit is dropped, not silently '
      'swallowed, while the first is still in flight',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.done, timeOfDay: '07:00'),
              _slot(
                careScheduleId: 'sch-2',
                title: 'Second dose',
                status: CareTodayStatus.done,
                timeOfDay: '08:00',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        final row1 = find.byKey(
          const Key('care-today-row-sch-1-2026-07-22-07:00'),
        );
        final row2 = find.byKey(
          const Key('care-today-row-sch-2-2026-07-22-08:00'),
        );
        // Simulate a fast double-tap across two rows the same way
        // care_history_screen_test.dart does: invoke each row's onTap
        // callback back-to-back with nothing in between, so both sheets get
        // pushed before either one's own re-entrancy check can react to the
        // other.
        final onTap1 = tester.widget<ListTile>(row1).onTap!;
        final onTap2 = tester.widget<ListTile>(row2).onTap!;
        onTap1();
        onTap2();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-today-edit-submit')), findsNWidgets(2));

        // Hold the first-submitted edit in flight.
        final completer = Completer<void>();
        historyRepository.editCompleter = completer;
        // The top sheet (painted last, `.last`) is sch-2's — pushed second.
        await tester.tap(find.byKey(const Key('care-today-edit-submit')).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.marking, isTrue);
        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastCareScheduleId, 'sch-2');

        // sch-1's sheet is now revealed underneath; submit it too — this
        // must be dropped (the after-sheet-await gate), not silently
        // swallowed by the controller's own guard.
        expect(find.byKey(const Key('care-today-edit-submit')), findsOneWidget);
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Still only the one edit dispatched, still for sch-2.
        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastCareScheduleId, 'sch-2');
        // The user is told the drop happened — never silent. task 4.5:
        // worded as "not applied" (nothing failed, the gate just dropped
        // it), not the generic "something went wrong" text — and still
        // offers a retry.
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryEditNotAppliedMessage), findsOneWidget);
        expect(find.text(loc.careErrorGeneric), findsNothing);
        expect(find.text(loc.retry), findsOneWidget);

        // Tapping that retry must resend the values the DROPPED sheet had
        // (sch-1's), not reopen the sheet and make the user pick again.
        // Asserting the button merely exists leaves that half unguarded:
        // routing retry to `_openEditSheet` keeps this test green unless we
        // actually press it and check what went out.
        completer.complete();
        await tester.pumpAndSettle();
        expect(historyRepository.editCalls, 1);

        historyRepository.editCompleter = null;
        await tester.tap(find.text(loc.retry));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 2);
        expect(historyRepository.lastCareScheduleId, 'sch-1');
        expect(historyRepository.lastStatus, CareLogStatus.done);
      },
    );

    testWidgets(
      "the sheet's completion time is shown in local time — a non-identity "
      'toLocalTime proves the conversion actually runs (the CI runner is '
      'UTC, where .toLocal() is identity — design §C)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                status: CareTodayStatus.done,
                timeOfDay: '08:00',
                doneTime: '2026-07-22T00:05:00.000Z',
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(
          tester,
          controller,
          toLocalTime: (dt) => dt.add(const Duration(hours: 8)),
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        // 00:05 UTC + the injected 8h offset — not the raw UTC 00:05, and
        // not the scheduled 08:00 either.
        final timeTile = tester.widget<ListTile>(
          find.byKey(const Key('care-today-edit-time')),
        );
        expect((timeTile.subtitle! as Text).data, '08:05');
      },
    );

    testWidgets(
      'a missed slot back-filled without touching the time submits the '
      'scheduled time it displayed — what the user saw is what gets written '
      '(previously it displayed 07:00 but sent no done_time at all, which '
      'the backend reads as "leave the field alone")',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(status: CareTodayStatus.missed, timeOfDay: '07:00'),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-07:00')),
        );
        await tester.pumpAndSettle();

        final timeTile = tester.widget<ListTile>(
          find.byKey(const Key('care-today-edit-time')),
        );
        expect((timeTile.subtitle! as Text).data, '07:00');

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastStatus, CareLogStatus.done);
        // The displayed 07:00, on the slot's own local date, as a UTC
        // instant — not null.
        expect(historyRepository.lastDoneTime, DateTime(2026, 7, 22, 7).toUtc());
      },
    );

    testWidgets(
      "the screen's own completion-time picker (not injected) seeds from the "
      "recorded doneTime in local time and combines the pick with the slot's "
      'own localDate as UTC',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                status: CareTodayStatus.done,
                timeOfDay: '08:00',
                doneTime: '2026-07-22T00:05:00.000Z',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          // The real picker — no injection, so this is the only test that
          // executes the screen's default pickDoneTime end to end.
          pickDoneTime: null,
          toLocalTime: (dt) => dt.add(const Duration(hours: 8)),
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();

        // The real Material time picker is up; confirming it returns its
        // initial time, which is the recorded 00:05 UTC seen through the
        // injected +8h conversion — 08:05, not 00:05 and not the scheduled
        // 08:00.
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(
          historyRepository.lastDoneTime,
          DateTime(2026, 7, 22, 8, 5).toUtc(),
        );
      },
    );

    // The other half of the seed rule, and the only test that exercises it:
    // re-opening the REAL picker must start from what the sheet currently
    // holds, not from the slot's recorded value. The injected-picker test can
    // only prove the sheet passes `current` out; it never runs the default
    // implementation, so without this a default that ignores `current` and
    // recomputes from the slot passes everything.
    testWidgets(
      "the screen's own picker re-opens from the time already chosen in the "
      'sheet, not from the slot value it started with',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                status: CareTodayStatus.done,
                doneTime: '2026-07-22T00:05:00.000Z',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: null,
          // Deliberately NOT injecting toLocalTime here. `_doneInstantOn`
          // rebuilds the instant from the HOST's local zone, while the seed
          // goes through `toLocalTime` — so the two only round-trip when
          // they're the same conversion. Injecting a fake (+8h) against a
          // host-local rebuild passes only where the offsets happen to
          // cancel: it went green on a UTC+8 machine and red on CI's UTC
          // runner. This test is about *which value seeds the second open*,
          // not about the conversion, so it uses the real one and stays
          // timezone-independent.
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        // First open: seeded from the recorded 00:05Z. Switch to the dialog's
        // input mode and change it to 10:30 — the exact value doesn't matter,
        // only that it differs from what the slot would re-seed.
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(IconButton).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '10');
        await tester.enterText(find.byType(TextField).last, '30');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Second open: must start at 10:30, the value now held by the sheet.
        // Confirming without touching anything therefore returns 10:30 — a
        // default that re-seeded from the slot would return the recorded
        // 00:05Z in local time instead, whatever that is on this host.
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(
          historyRepository.lastDoneTime,
          DateTime(2026, 7, 22, 10, 30).toUtc(),
        );
      },
    );

    testWidgets(
      "the screen's own picker seeds from the scheduled timeOfDay when the "
      'slot has no recorded doneTime',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(status: CareTodayStatus.missed, timeOfDay: '07:00'),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: null,
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-07:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(
          historyRepository.lastDoneTime,
          DateTime(2026, 7, 22, 7).toUtc(),
        );
      },
    );

    testWidgets(
      'the sheet fits a 360x640 phone at 1.3x text: nothing overflows and '
      'the submit button is reachable without scrolling (the default 9/16 '
      'sheet-height cap clipped it clean off the bottom)',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          surfaceSize: const Size(360, 640),
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Reachable, not clipped off the bottom of the sheet — `tap` throws
        // if the button isn't hit-testable at its centre.
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(historyRepository.editCalls, 1);
      },
    );

    testWidgets(
      'while any row is mid-mark, the other Done rows are disabled rather '
      'than staying tappable and silently swallowing the tap (the '
      're-entrancy gate is global, not per row)',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                careScheduleId: 'sch-1',
                status: CareTodayStatus.done,
                timeOfDay: '07:00',
              ),
              _slot(
                careScheduleId: 'sch-2',
                title: 'Second dose',
                status: CareTodayStatus.done,
                timeOfDay: '08:00',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        final other = find.byKey(
          const Key('care-today-row-sch-2-2026-07-22-08:00'),
        );
        expect(tester.widget<ListTile>(other).onTap, isNotNull);

        // Hold sch-1's edit in flight.
        final completer = Completer<void>();
        historyRepository.editCompleter = completer;
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-07:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.marking, isTrue);
        final otherTile = tester.widget<ListTile>(other);
        expect(otherTile.onTap, isNull);
        expect(otherTile.enabled, isFalse);

        completer.complete();
        await tester.pumpAndSettle();

        // Re-enabled once the edit settles.
        expect(tester.widget<ListTile>(other).onTap, isNotNull);
      },
    );

    testWidgets(
      'an edit whose PUT saved but whose follow-up reload failed says so — '
      "not the generic 'something went wrong, try again' that tells the user "
      'their correction was lost when it was not',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, ___, ____) async =>
              DateTime.utc(2026, 7, 22, 4, 30),
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        // Only the *reload* that follows the successful PUT fails; the
        // initial load already happened.
        repository.getError = const CareRequestFailed();
        repository.getErrorAfterCalls = repository.getCalls;

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(historyRepository.editCalls, 1);
        expect(
          find.text(loc.careHistoryEditRefreshErrorMessage),
          findsOneWidget,
        );
        expect(find.text(loc.careErrorGeneric), findsNothing);
        // And deliberately NO retry here: the PUT already succeeded, so
        // retrying would re-send an edit that is already stored. Without
        // this, widening `offerRetry` to every outcome stays green.
        expect(find.text(loc.retry), findsNothing);
      },
    );

    testWidgets(
      "while a Done row's edit is in flight, the Overdue/Later rows' and the "
      'focus card\'s inline buttons are disabled too — the re-entrancy gate '
      'is global, so leaving them live would drop the tap in silence',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                careScheduleId: 'sch-focus',
                title: 'Focus dose',
                status: CareTodayStatus.overdue,
                timeOfDay: '09:00',
              ),
              _slot(
                careScheduleId: 'sch-overdue',
                title: 'Other overdue dose',
                status: CareTodayStatus.overdue,
                timeOfDay: '10:00',
              ),
              _slot(
                careScheduleId: 'sch-done',
                title: 'Already done',
                status: CareTodayStatus.done,
                timeOfDay: '07:00',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, ___, ____) async =>
              DateTime.utc(2026, 7, 22, 4, 30),
        );

        final overdueDone = find.byKey(
          const Key('care-today-row-done-sch-overdue'),
        );
        final overdueSkip = find.byKey(
          const Key('care-today-row-skip-sch-overdue'),
        );
        final focusDone = find.byKey(const Key('care-today-focus-done'));
        expect(tester.widget<FilledButton>(overdueDone).onPressed, isNotNull);
        expect(tester.widget<FilledButton>(focusDone).onPressed, isNotNull);

        // Hold the Done row's edit — the longest-running of the three
        // in-flight kinds, since the user spends time in the sheet first.
        final completer = Completer<void>();
        historyRepository.editCompleter = completer;
        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-done-2026-07-22-07:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.marking, isTrue);
        expect(tester.widget<FilledButton>(overdueDone).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(overdueSkip).onPressed, isNull);
        expect(tester.widget<FilledButton>(focusDone).onPressed, isNull);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('care-today-focus-skip')),
              )
              .onPressed,
          isNull,
        );

        completer.complete();
        await tester.pumpAndSettle();

        expect(tester.widget<FilledButton>(overdueDone).onPressed, isNotNull);
        expect(tester.widget<FilledButton>(focusDone).onPressed, isNotNull);
      },
    );

    testWidgets(
      "the sheet's two status rows expose which one is selected to "
      'assistive tech (a bare trailing check icon is invisible to a screen '
      'reader), and the selection follows taps',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        final doneRow = find.byKey(const Key('care-today-edit-status-done'));
        final skippedRow = find.byKey(
          const Key('care-today-edit-status-skipped'),
        );

        expect(tester.widget<ListTile>(doneRow).selected, isTrue);
        expect(tester.widget<ListTile>(skippedRow).selected, isFalse);
        expect(
          tester.getSemantics(doneRow),
          containsSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(skippedRow),
          containsSemantics(isSelected: false),
        );

        await tester.tap(skippedRow);
        await tester.pumpAndSettle();

        expect(tester.widget<ListTile>(doneRow).selected, isFalse);
        expect(tester.widget<ListTile>(skippedRow).selected, isTrue);
        expect(
          tester.getSemantics(skippedRow),
          containsSemantics(isSelected: true),
        );

        // The visual half of the same rule. Without this, the leading icons
        // can silently go back to the pre-fix shape — a permanent
        // `check_circle_outline` on the Done row (the status-icon set, not a
        // selection indicator) plus a separate trailing check — which is what
        // made the sheet's selection unreadable in the first place.
        expect(
          find.descendant(of: skippedRow, matching: find.byIcon(Icons.check_circle)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: doneRow, matching: find.byIcon(Icons.circle_outlined)),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.check), findsNothing);
        semantics.dispose();
      },
    );

    testWidgets(
      'a completion-time pick that lands after the sheet is gone does not '
      'setState on a disposed State',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final controller = _controller(repository: repository);
        final pickCompleter = Completer<DateTime?>();
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, ___, ____) => pickCompleter.future,
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pump();

        // Dismiss the sheet (its barrier) while the picker is still open.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('care-today-edit-submit')), findsNothing);

        pickCompleter.complete(DateTime.utc(2026, 7, 22, 4, 30));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      're-opening the picker seeds from the time already chosen in the '
      'sheet, not from the slot value the sheet started with',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                status: CareTodayStatus.done,
                timeOfDay: '08:00',
                doneTime: '2026-07-22T00:05:00.000Z',
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        final seeds = <DateTime?>[];
        final picked = DateTime.utc(2026, 7, 22, 4, 30);
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, current, ____) async {
            seeds.add(current);
            return picked;
          },
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();

        expect(seeds, [DateTime.parse('2026-07-22T00:05:00.000Z'), picked]);
      },
    );

    testWidgets(
      "the screen's own picker is always 24-hour, whatever the locale — the "
      "row and the sheet render the time with 'HH:mm', so a 12-hour picker "
      "would have the user choose '9:30 PM' and then read back '21:30'",
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(status: CareTodayStatus.missed, timeOfDay: '21:30'),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller, pickDoneTime: null);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-21:30')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-time')));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        // The day-period (AM/PM) control only exists in the 12-hour layout.
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
      },
    );

    testWidgets(
      "the sheet's submit button clears the bottom safe-area inset — "
      'showModalBottomSheet\'s useSafeArea leaves the bottom edge to the '
      'sheet, so on a gesture-navigation phone the button sat 16dp from the '
      'screen edge',
      (tester) async {
        // 96 physical px at the test view's 3.0 device pixel ratio = 32dp,
        // roughly an iPhone home-indicator inset.
        tester.view.padding = const FakeViewPadding(bottom: 96);
        addTearDown(tester.view.resetPadding);
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.done, timeOfDay: '08:00')],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller, surfaceSize: const Size(400, 800));

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        final submitBottom = tester
            .getBottomLeft(find.byKey(const Key('care-today-edit-submit')))
            .dy;
        final inset = tester.view.padding.bottom / tester.view.devicePixelRatio;
        expect(submitBottom, lessThanOrEqualTo(800 - inset));
      },
    );

    testWidgets(
      'a Done row disabled by another row\'s in-flight edit greys its edit '
      'icon — the icon carries its own explicit colour, so ListTile.enabled '
      'alone leaves it looking tappable',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-22',
            slots: [
              _slot(
                careScheduleId: 'sch-1',
                status: CareTodayStatus.done,
                timeOfDay: '07:00',
              ),
              _slot(
                careScheduleId: 'sch-2',
                title: 'Second dose',
                status: CareTodayStatus.done,
                timeOfDay: '08:00',
              ),
            ],
          ),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(
          tester,
          controller,
          pickDoneTime: (_, __, ___, ____) async =>
              DateTime.utc(2026, 7, 22, 4, 30),
        );

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        Color otherEditIconColor() => tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(
                  const Key('care-today-row-sch-2-2026-07-22-08:00'),
                ),
                matching: find.byIcon(Icons.edit_outlined),
              ),
            )
            .color!;

        final enabledColor = otherEditIconColor();

        final completer = Completer<void>();
        historyRepository.editCompleter = completer;
        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-07:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.marking, isTrue);
        expect(otherEditIconColor(), isNot(enabledColor));

        completer.complete();
        await tester.pumpAndSettle();

        expect(otherEditIconColor(), enabledColor);
      },
    );

    // design D4 / task 4.9: a slot whose `localDate` cannot be parsed has no
    // reasonable date to pin a completion time to — substituting one (e.g.
    // "today") would file the record under the wrong day, which is worse
    // than sending nothing (the backend treats an absent `done_time` as
    // "leave this field alone"). Covers two of the six D4 call sites:
    // `_doneInstantOn` and `_EditSheet.build`'s date label.
    testWidgets(
      "a slot whose localDate can't be parsed: the correction sheet doesn't "
      'crash, its completion-time row is disabled and shows "—", and '
      'submitting sends no doneTime',
      (tester) async {
        const malformedSlot = CareTodaySlot(
          careItemId: 'care-1',
          careScheduleId: 'sch-1',
          category: CareCategory.medication,
          title: 'Metformin',
          timeOfDay: '08:00',
          localDate: 'not-a-date',
          status: CareTodayStatus.missed,
          doseQuantity: 1,
        );
        final repository = _FakeCareTodayRepository(
          today: const CareToday(date: '2026-07-22', slots: [malformedSlot]),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-not-a-date-08:00')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final timeTile = tester.widget<ListTile>(
          find.byKey(const Key('care-today-edit-time')),
        );
        expect(timeTile.enabled, isFalse);
        expect((timeTile.subtitle! as Text).data, '—');

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastStatus, CareLogStatus.done);
        expect(historyRepository.lastDoneTime, isNull);
      },
    );

    // design D4, the case the fixture above misses: the same unparseable
    // `localDate`, but on a slot that *does* carry a recorded `doneTime`.
    // Seeding the sheet from that recorded value made `_doneTime` non-null,
    // so the row — disabled, and therefore not correctable — still displayed
    // a concrete time, and submitting sent it back pinned to a date the app
    // admits it cannot determine. D4 says "shows no time" and "sends no
    // completion time at all".
    testWidgets(
      "a slot whose localDate can't be parsed but has a recorded doneTime "
      'still shows "—" and still submits no doneTime',
      (tester) async {
        const malformedSlot = CareTodaySlot(
          careItemId: 'care-1',
          careScheduleId: 'sch-1',
          category: CareCategory.medication,
          title: 'Metformin',
          timeOfDay: '08:00',
          localDate: 'not-a-date',
          status: CareTodayStatus.done,
          doseQuantity: 1,
          doneTime: '2026-07-22T04:58:00.000Z',
        );
        final repository = _FakeCareTodayRepository(
          today: const CareToday(date: '2026-07-22', slots: [malformedSlot]),
        );
        final historyRepository = _FakeCareHistoryRepository();
        final controller = _controller(
          repository: repository,
          historyRepository: historyRepository,
        );
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-not-a-date-08:00')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final timeTile = tester.widget<ListTile>(
          find.byKey(const Key('care-today-edit-time')),
        );
        expect(timeTile.enabled, isFalse);
        expect((timeTile.subtitle! as Text).data, '—');

        await tester.tap(find.byKey(const Key('care-today-edit-submit')));
        await tester.pumpAndSettle();

        expect(historyRepository.editCalls, 1);
        expect(historyRepository.lastDoneTime, isNull);
      },
    );

    // design D4: `timeOfDay` unparseable (with no recorded `doneTime`) only
    // ever affects the picker's *initial* value — it falls back to a fixed
    // default rather than crashing, since `localDate` (a separate field) is
    // still fine here and there's no reason to disable the whole row.
    testWidgets(
      "a slot whose timeOfDay can't be parsed and has no recorded doneTime: "
      "the correction sheet doesn't crash and its completion-time row falls "
      'back to a fixed default time',
      (tester) async {
        const malformedSlot = CareTodaySlot(
          careItemId: 'care-1',
          careScheduleId: 'sch-1',
          category: CareCategory.medication,
          title: 'Metformin',
          timeOfDay: 'not-a-time',
          localDate: '2026-07-22',
          status: CareTodayStatus.missed,
          doseQuantity: 1,
        );
        final repository = _FakeCareTodayRepository(
          today: const CareToday(date: '2026-07-22', slots: [malformedSlot]),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('care-today-row-sch-1-2026-07-22-not-a-time')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final timeTile = tester.widget<ListTile>(
          find.byKey(const Key('care-today-edit-time')),
        );
        // Not disabled, and not "—" — a usable fallback, since localDate is
        // fine.
        expect(timeTile.enabled, isTrue);
        expect((timeTile.subtitle! as Text).data, isNot('—'));
      },
    );
  });

  // design D4 / task 4.9: the checklist's own date header
  // (`mediumDateLabel(parseDayString(controller.date))`) reads a
  // backend-sourced string too — the third of the six D4 call sites.
  group('CareTodayScreen malformed controller.date', () {
    testWidgets(
      "a malformed controller.date falls back rather than crashing the "
      'checklist header',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: const CareToday(date: 'not-a-date', slots: []),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Text>(find.byKey(const Key('care-today-date'))).data,
          '—',
        );
      },
    );
  });

  group('CareTodayScreen push-off banner', () {
    testWidgets(
      'permissionPrompt with slots today: the banner sits under the date '
      'header and its action pushes /reminders',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-22', slots: [_slot()]),
        );
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          pushHealthController: testPushHealthController(
            PushHealth.permissionPrompt,
          ),
        );

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
        // Header first: the user learns which day they are looking at before
        // the warning, matching every other screen's date header.
        expect(
          tester.getTopLeft(find.byKey(const Key('push-off-banner'))).dy,
          greaterThan(
            tester.getTopLeft(find.byKey(const Key('care-today-date'))).dy,
          ),
        );

        await tester.tap(find.byKey(const Key('push-off-action')));
        await tester.pumpAndSettle();

        expect(find.text('/reminders'), findsOneWidget);
      },
    );

    testWidgets('permissionDenied with slots today shows the banner', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      await _pumpScreen(
        tester,
        _controller(repository: repository),
        pushHealthController: testPushHealthController(
          PushHealth.permissionDenied,
        ),
      );

      expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
    });

    for (final health in [
      PushHealth.ok,
      PushHealth.unknown,
      PushHealth.unsupported,
      PushHealth.syncFailed,
    ]) {
      testWidgets('${health.name} with slots today shows no banner', (
        tester,
      ) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-22', slots: [_slot()]),
        );
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          pushHealthController: testPushHealthController(health),
        );

        expect(find.byKey(const Key('push-off-banner')), findsNothing);
      });
    }

    testWidgets(
      'no care slots today: no banner — there is no reminder to miss',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: const CareToday(date: '2026-07-22', slots: []),
        );
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          pushHealthController: testPushHealthController(
            PushHealth.permissionDenied,
          ),
        );

        expect(find.byKey(const Key('care-today-empty-state')), findsOneWidget);
        expect(find.byKey(const Key('push-off-banner')), findsNothing);
      },
    );

    testWidgets(
      'a token renewal that throws does not make the tap vanish — the write '
      'still goes out unauthenticated so the 401 path takes over',
      (tester) async {
        // `getIdToken()` reaches the network once the token nears expiry and
        // throws when that fails. Unguarded, the throw escapes the provider
        // *before* the controller is entered: no write, no message, the slot
        // unchanged — the tap simply disappears. `guardedIdToken` resolves to
        // `''` instead so the request goes out and the backend's 401 drives
        // the existing re-auth exit.
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-22', slots: [_slot()]),
        );
        final authRepository = _FakeAuthRepository();
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          authRepository: authRepository,
        );
        repository.logTokens.clear();

        authRepository.throws = true;
        await tester.tap(find.byKey(const Key('care-today-focus-done')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          repository.logTokens,
          [''],
          reason: 'the write must still go out, with an empty token',
        );
      },
    );

    testWidgets(
      'a push-health change while the screen is open shows the banner '
      'without reopening it',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-22', slots: [_slot()]),
        );
        final pushHealth = testPushHealthController(PushHealth.ok);
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          pushHealthController: pushHealth,
        );
        expect(find.byKey(const Key('push-off-banner')), findsNothing);

        pushHealth.health = PushHealth.permissionDenied;
        pushHealth.notifyListeners();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('push-off-banner')), findsOneWidget);
      },
    );
  });
}
