import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_dose_label.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_summary_card.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../../support/l10n_test_app.dart';

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

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
  Object? logError;
  Completer<void>? logCompleter;

  /// When set, `getToday` waits on this before completing — lets a test
  /// observe the in-flight loading state of a reload.
  Completer<void>? getGate;

  /// When set, `getToday` throws this instead of returning [today] — lets a
  /// test drive a load to `error`/`reauth`.
  Object? getError;

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async {
    if (getGate != null) await getGate!.future;
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
  String? dose = '500mg',
  double doseQuantity = 1,
  CareCategory category = CareCategory.medication,
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: category,
  title: title,
  note: null,
  dose: dose,
  timeOfDay: timeOfDay,
  localDate: '2026-07-24',
  status: status,
  doseQuantity: doseQuantity,
);

class _FakeCareHistoryRepository implements CareHistoryRepository {
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
  }) async {}
}

CareTodayController _controllerFor(List<CareTodaySlot> slots, {_FakeCareTodayRepository? repository}) {
  final repo = repository ?? _FakeCareTodayRepository(today: CareToday(date: '2026-07-24', slots: slots));
  return CareTodayController(
    GetCareToday(repo),
    MarkCareDone(repo),
    MarkCareSkipped(repo),
    EditCareSlot(_FakeCareHistoryRepository()),
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  CareTodayController controller, {
  VoidCallback? onManage,
  VoidCallback? onSetup,
}) async {
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: Scaffold(
        body: CareTodaySummaryCard(
          controller: controller,
          idToken: () async => 'token-123',
          onManage: onManage ?? () {},
          onSetup: onSetup ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CareTodaySummaryCard', () {
    testWidgets('overdue: shows the urgent focus slot with inline Done/Skip '
        'and a more-count footer', (tester) async {
      final controller = _controllerFor([
        _slot(careScheduleId: 'sch-overdue', status: CareTodayStatus.overdue, timeOfDay: '07:00'),
        _slot(careScheduleId: 'sch-overdue-2', title: 'Other overdue', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
        _slot(careScheduleId: 'sch-pending', title: 'Later dose', status: CareTodayStatus.pending, timeOfDay: '18:00'),
      ]);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-done')), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-skip')), findsOneWidget);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careTodaySummaryProgress(0, 3)), findsOneWidget);
      // 2 more slots besides the shown focus slot (the other overdue + the
      // pending one).
      expect(
        find.textContaining(loc.careTodaySummaryMoreCount(2)),
        findsOneWidget,
      );
      expect(find.textContaining(loc.careTodaySummarySeeAll), findsOneWidget);
      expect(
        find.byKey(const Key('care-today-summary-overdue-chip')),
        findsOneWidget,
      );
      expect(find.text(loc.careTodayOverdueSection), findsOneWidget);
    });

    testWidgets('pending-only: shows "up next" with an inline Done action '
        'and no Skip', (tester) async {
      final controller = _controllerFor([
        _slot(careScheduleId: 'sch-pending', status: CareTodayStatus.pending, timeOfDay: '08:00'),
        _slot(careScheduleId: 'sch-later', title: 'Later dose', status: CareTodayStatus.pending, timeOfDay: '18:00'),
      ]);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.textContaining(loc.careTodayUpNext), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-done')), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-skip')), findsNothing);
      expect(find.textContaining(loc.careTodaySummaryMoreCount(1)), findsOneWidget);
      // The open affordance is always present, even when the focus isn't
      // overdue.
      expect(find.textContaining(loc.careTodaySummarySeeAll), findsOneWidget);
      expect(
        find.byKey(const Key('care-today-summary-overdue-chip')),
        findsNothing,
      );
    });

    testWidgets('all-done: shows a mini celebration and the card is tappable', (
      tester,
    ) async {
      final controller = _controllerFor([_slot(status: CareTodayStatus.done)]);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careTodayCelebrationTitle), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-done')), findsNothing);
      expect(find.text(loc.careTodaySummaryProgress(1, 1)), findsOneWidget);
      // The open affordance stays discoverable even with nothing left to do.
      expect(find.byKey(const Key('care-today-summary-open')), findsOneWidget);
      expect(find.textContaining(loc.careTodaySummarySeeAll), findsOneWidget);
    });

    testWidgets(
      'no schedules: shows a slim setup CTA and tapping it triggers onSetup',
      (tester) async {
        final controller = _controllerFor(const []);
        await controller.load('token-123');
        var setupTapped = false;

        await _pumpCard(
          tester,
          controller,
          onSetup: () => setupTapped = true,
        );

        expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
        expect(find.byKey(const Key('care-today-summary-setup')), findsOneWidget);
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.textContaining(loc.careTodaySummarySetupTitle), findsOneWidget);
        expect(find.textContaining(loc.careTodaySummarySetupCta), findsOneWidget);

        await tester.tap(find.byKey(const Key('care-today-summary-setup')));
        await tester.pumpAndSettle();

        expect(setupTapped, isTrue);
      },
    );

    testWidgets('loading: renders nothing', (tester) async {
      final controller = _controllerFor([_slot(status: CareTodayStatus.overdue)]);
      // Deliberately not calling load() — status stays at its initial
      // `loading` value.

      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
    });

    testWidgets(
      'a reload (e.g. after a chaodays import) keeps showing the last '
      'loaded summary instead of disappearing',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);

        final gate = Completer<void>();
        repository.getGate = gate;
        unawaited(controller.load('token-123'));
        await tester.pump();

        // Still loading, but the previously loaded summary stays put — and a
        // refresh in flight is not a failure, so nothing is marked.
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
        expect(find.text('Metformin'), findsOneWidget);
        // The marking's row, not [StaleNotice] itself: the card keeps the
        // widget mounted through a reload so it can remember a retry the user
        // pressed, and it renders nothing until it has something to say.
        expect(find.byKey(const Key('stale-notice-row')), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
      },
    );

    testWidgets(
      'a reload that ends in error (e.g. a failed chaodays-import refresh) '
      'still shows the last loaded summary instead of disappearing',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);

        repository.getError = const CareRequestFailed();
        await controller.load('token-123');
        await tester.pumpAndSettle();

        expect(controller.status, CareTodayLoadStatus.error);
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
        expect(find.text('Metformin'), findsOneWidget);
        // Keeping it silently is what left the top card of the overview
        // quietly stale; the marking is what makes keeping it honest.
        expect(find.byType(StaleNotice), findsOneWidget);
        expect(find.text(_en.cardRefreshFailed), findsOneWidget);
      },
    );

    testWidgets(
      'the marking\'s retry reloads today\'s care, and a successful one '
      'clears the marking',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);
        repository.getError = const CareRequestFailed();
        await controller.load('token-123');
        await tester.pumpAndSettle();
        expect(find.byType(StaleNotice), findsOneWidget);
        // byType only proves it is mounted — it mounts while reloading too, and
        // renders nothing then. The copy is what says the user can see it.
        expect(find.text(_en.cardRefreshFailed), findsOneWidget);

        repository.getError = null;
        await tester.tap(find.byKey(const Key('stale-notice-retry')));
        await tester.pumpAndSettle();

        expect(controller.status, CareTodayLoadStatus.loaded);
        expect(find.byType(StaleNotice), findsNothing);
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
      },
    );

    testWidgets(
      'a reload that ends in reauth still shows the last loaded summary '
      'instead of disappearing',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);

        repository.getError = const CareReauthRequired();
        await controller.load('token-123');
        await tester.pumpAndSettle();

        expect(controller.status, CareTodayLoadStatus.reauth);
        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
        expect(find.text('Metformin'), findsOneWidget);
        // And it is not the card's failure to report: "couldn't refresh,
        // retry" would send the user round a loop that cannot succeed until
        // they sign in again. The overview's re-authenticate exit takes over.
        expect(find.byType(StaleNotice), findsNothing);
      },
    );

    testWidgets(
      'a first-ever load that ends in error (never loaded before) says so '
      'with a retry, instead of the top card of the overview just not '
      'being there',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        )..getError = const CareRequestFailed();
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        expect(controller.status, CareTodayLoadStatus.error);
        expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
        expect(find.byKey(const Key('care-today-summary-setup')), findsNothing);
        // Vanishing reads as "you have no care today" — the one thing the
        // card must never imply by accident.
        expect(find.byKey(const Key('care-today-summary-error')), findsOneWidget);
        expect(find.byKey(const Key('care-today-summary-retry')), findsOneWidget);
        // And it names what failed. `careErrorGeneric` was written for the
        // full care screens, whose app bar supplies the subject; on a card
        // sitting between three others that each name theirs, a bare
        // "something went wrong" says nothing about which one.
        expect(find.text(_en.errorCareTodayLoadFailed), findsOneWidget);
        expect(find.text(_en.careErrorGeneric), findsNothing);
        // Nothing has loaded, so there is nothing to mark as unrefreshed.
        expect(find.byType(StaleNotice), findsNothing);

        repository.getError = null;
        await tester.tap(find.byKey(const Key('care-today-summary-retry')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
      },
    );

    testWidgets(
      'a first-ever load still in flight keeps rendering nothing — it is '
      'about to resolve',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        );
        final gate = Completer<void>();
        repository.getGate = gate;
        final controller = _controllerFor(const [], repository: repository);
        unawaited(controller.load('token-123'));

        await tester.pumpWidget(
          l10nRouterTestApp(
            home: Scaffold(
              body: CareTodaySummaryCard(
                controller: controller,
                idToken: () async => 'token-123',
                onManage: () {},
                onSetup: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
        expect(find.byKey(const Key('care-today-summary-setup')), findsNothing);
        expect(find.byKey(const Key('care-today-summary-error')), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a day with no schedules keeps its setup prompt through a failed '
      'refresh, marked — having nothing scheduled is loaded content',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: const []),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);
        expect(find.byKey(const Key('care-today-summary-setup')), findsOneWidget);

        repository.getError = const CareRequestFailed();
        await controller.load('token-123');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-today-summary-setup')), findsOneWidget);
        expect(find.byKey(const Key('care-today-summary-error')), findsNothing);
        expect(find.byType(StaleNotice), findsOneWidget);
        // byType only proves it is mounted — it mounts while reloading too, and
        // renders nothing then. The copy is what says the user can see it.
        expect(find.text(_en.cardRefreshFailed), findsOneWidget);
      },
    );

    testWidgets(
      'a day with no schedules keeps its setup prompt through a refresh in '
      'flight, unmarked',
      (tester) async {
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: const []),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);

        final gate = Completer<void>();
        repository.getGate = gate;
        unawaited(controller.load('token-123'));
        await tester.pump();

        expect(find.byKey(const Key('care-today-summary-setup')), findsOneWidget);
        expect(find.byKey(const Key('stale-notice-row')), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a controller left in error with slots in hand shows them, marked, on '
      'a fresh mount — re-entering the health module must not look like a '
      'first-ever failure',
      (tester) async {
        // The controller is an app-level singleton, so the card can be built
        // fresh over one that is already stuck in `error`. `_hasLoadedOnce`
        // seeds from `status == loaded` and so is false here; only
        // `controller.date` survives the remount.
        final repository = _FakeCareTodayRepository(
          today: CareToday(
            date: '2026-07-24',
            slots: [_slot(status: CareTodayStatus.overdue)],
          ),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        repository.getError = const CareRequestFailed();
        await controller.load('token-123');
        expect(controller.status, CareTodayLoadStatus.error);

        await _pumpCard(tester, controller);

        expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
        expect(find.text('Metformin'), findsOneWidget);
        expect(find.byKey(const Key('care-today-summary-error')), findsNothing);
        expect(find.byType(StaleNotice), findsOneWidget);
        // byType only proves it is mounted — it mounts while reloading too, and
        // renders nothing then. The copy is what says the user can see it.
        expect(find.text(_en.cardRefreshFailed), findsOneWidget);
      },
    );

    testWidgets(
      'a no-schedule day left in error keeps its setup prompt on a fresh '
      'mount too — this is the case only `controller.date` gets right',
      (tester) async {
        // Neither `_hasLoadedOnce` (false across the remount) nor
        // `slots.isNotEmpty` (a day with nothing scheduled has none) can tell
        // this apart from a first-ever failure; both would replace the setup
        // prompt with an error card.
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: const []),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        repository.getError = const CareRequestFailed();
        await controller.load('token-123');
        expect(controller.status, CareTodayLoadStatus.error);
        expect(controller.slots, isEmpty);

        await _pumpCard(tester, controller);

        expect(find.byKey(const Key('care-today-summary-setup')), findsOneWidget);
        expect(find.byKey(const Key('care-today-summary-error')), findsNothing);
        expect(find.byType(StaleNotice), findsOneWidget);
        // byType only proves it is mounted — it mounts while reloading too, and
        // renders nothing then. The copy is what says the user can see it.
        expect(find.text(_en.cardRefreshFailed), findsOneWidget);
      },
    );

    testWidgets(
      'the setup prompt\'s marking names it — the prompt is its own card, and '
      'a bare "Retry" beside three others says nothing about which failed',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repository = _FakeCareTodayRepository(
          today: CareToday(date: '2026-07-24', slots: const []),
        );
        final controller = _controllerFor(const [], repository: repository);
        await controller.load('token-123');
        await _pumpCard(tester, controller);
        repository.getError = const CareRequestFailed();
        await controller.load('token-123');
        await tester.pump();

        expect(
          tester.getSemantics(find.byType(StaleNotice)).getSemanticsData().label,
          startsWith(_en.careTodaySummarySetupTitle),
        );

        handle.dispose();
      },
    );

    testWidgets('tapping inline Done triggers markDone with idToken + slot ids', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-24',
          slots: [_slot(careScheduleId: 'sch-overdue', status: CareTodayStatus.overdue)],
        ),
      );
      final controller = _controllerFor(const [], repository: repository);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('care-today-summary-done')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careTodayCelebrationTitle), findsOneWidget);
    });

    testWidgets('an in-flight mark shows a spinner on the pressed button and '
        'disables both buttons', (tester) async {
      final logCompleter = Completer<void>();
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-24',
          slots: [_slot(careScheduleId: 'sch-overdue', status: CareTodayStatus.overdue)],
        ),
      )..logCompleter = logCompleter;
      final controller = _controllerFor(const [], repository: repository);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('care-today-summary-done')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final doneButton = tester.widget<FilledButton>(
        find.byKey(const Key('care-today-summary-done')),
      );
      expect(doneButton.onPressed, isNull);
      final skipButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('care-today-summary-skip')),
      );
      expect(skipButton.onPressed, isNull);

      logCompleter.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping the card body pushes /care-today', (tester) async {
      final controller = _controllerFor([_slot(status: CareTodayStatus.overdue)]);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(loc.careTodayTitle));
      await tester.pumpAndSettle();

      expect(find.text('/care-today'), findsOneWidget);
    });

    testWidgets(
      'has schedules: shows a header manage icon button and tapping it '
      'triggers onManage',
      (tester) async {
        final controller = _controllerFor([_slot(status: CareTodayStatus.overdue)]);
        await controller.load('token-123');
        var manageTapped = false;

        await _pumpCard(tester, controller, onManage: () => manageTapped = true);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.byKey(const Key('care-today-summary-manage')),
          findsOneWidget,
        );
        expect(
          tester.widget<IconButton>(
            find.byKey(const Key('care-today-summary-manage')),
          ).tooltip,
          loc.careTodaySummaryManage,
        );

        await tester.tap(find.byKey(const Key('care-today-summary-manage')));
        await tester.pumpAndSettle();

        expect(manageTapped, isTrue);
      },
    );

    testWidgets('a failed inline mark shows a SnackBar and keeps the summary', (
      tester,
    ) async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-24',
          slots: [_slot(careScheduleId: 'sch-overdue', status: CareTodayStatus.overdue)],
        ),
      )..logError = const CareRequestFailed();
      final controller = _controllerFor(const [], repository: repository);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('care-today-summary-done')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careErrorGeneric), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('care-today-summary-card')), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
    });
  });

  group('CareTodaySummaryCard focus dose', () {
    testWidgets('shows the quantity and the free-text dose together', (
      tester,
    ) async {
      final controller = _controllerFor([
        _slot(doseQuantity: 2, dose: '500mg'),
      ]);
      await controller.load('token-123');
      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(careDoseLabel(loc, CareCategory.medication, 2, '500mg')),
        findsOneWidget,
      );
    });

    // Regression guard for the dropped "hide when dose is empty" branch —
    // pairs with the same case on CareTodayScreen.
    testWidgets('a slot with only a quantity still shows a dose line', (
      tester,
    ) async {
      final controller = _controllerFor([
        _slot(doseQuantity: 2, dose: null),
      ]);
      await controller.load('token-123');
      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careDoseQuantityValue('2')), findsOneWidget);
    });

    // Regression guard for the medication-only gate: the backend still sends
    // a default doseQuantity of 1 for every category, but the form never
    // lets a non-medication item set it, so nothing should render.
    testWidgets('a non-medication slot shows no dose line', (tester) async {
      final controller = _controllerFor([
        _slot(category: CareCategory.rehab, doseQuantity: 1, dose: null),
      ]);
      await controller.load('token-123');
      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careDoseQuantityValue('1')), findsNothing);
    });
  });

  // The dose line is wrapped in Semantics + ExcludeSemantics, which *removes*
  // the visible text from the semantics tree: dropping the wrapper would
  // silence the dose for screen readers while every find.text assertion above
  // stays green. This is the only guard that would fail.
  //
  //
  // The whole card is one tappable node, so the dose label is a line inside a
  // multi-line label rather than a node of its own — hence the RegExp form of
  // find.bySemanticsLabel, which substring-matches, instead of the String
  // form, which compares the label whole.
  group('CareTodaySummaryCard dose semantics', () {
    testWidgets('the focus row announces its dose as a dose', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = _controllerFor([
        _slot(doseQuantity: 2, dose: '500mg'),
      ]);
      await controller.load('token-123');
      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(
              loc.careDoseSemanticLabel(
                careDoseLabel(loc, CareCategory.medication, 2, '500mg'),
              ),
            ),
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
