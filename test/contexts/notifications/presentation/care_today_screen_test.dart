import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

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
  Object? logError;
  Completer<void>? logCompleter;

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async {
    if (getError != null) throw getError!;
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
              doneTime: status == CareLogStatus.done ? '08:05' : null,
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
  doseQuantity: 1,
);

CareTodayController _controller({CareTodayRepository? repository}) {
  final repo =
      repository ??
      _FakeCareTodayRepository(today: const CareToday(date: '2026-07-22', slots: []));
  return CareTodayController(
    GetCareToday(repo),
    MarkCareDone(repo),
    MarkCareSkipped(repo),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CareTodayController controller, {
  VoidCallback? onOpenCareItems,
}) async {
  // The focus card + Overdue/Later/Done sections can exceed the default
  // 800x600 test surface — a taller surface keeps every section built (a
  // ListView only builds children within its viewport/cache extent).
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: CareTodayScreen(
        controller: controller,
        authRepository: _FakeAuthRepository(),
        onOpenCareItems: onOpenCareItems ?? () {},
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
      expect(find.byKey(const Key('care-today-row-sch-done')), findsNothing);

      await tester.tap(find.byKey(const Key('care-today-done-toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-today-row-sch-done')), findsOneWidget);
    });

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
        await _pumpScreen(tester, controller);

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
        expect(find.byKey(const Key('care-today-row-sch-1')), findsOneWidget);
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
      'during a mark, only the acted-on row disables and spins — other rows '
      'stay tappable (FIX 8)',
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

        // The other row's Done button is untouched by this mark — still
        // tappable, no spinner.
        final otherDoneButton = tester.widget<FilledButton>(
          find.byKey(const Key('care-today-row-done-sch-2')),
        );
        expect(otherDoneButton.onPressed, isNotNull);

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
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
}
