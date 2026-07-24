import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_summary_card.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

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

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async => today;

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
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: title,
  note: null,
  dose: dose,
  timeOfDay: timeOfDay,
  localDate: '2026-07-24',
  status: status,
  doseQuantity: 1,
);

CareTodayController _controllerFor(List<CareTodaySlot> slots, {_FakeCareTodayRepository? repository}) {
  final repo = repository ?? _FakeCareTodayRepository(today: CareToday(date: '2026-07-24', slots: slots));
  return CareTodayController(
    GetCareToday(repo),
    MarkCareDone(repo),
    MarkCareSkipped(repo),
  );
}

Future<void> _pumpCard(WidgetTester tester, CareTodayController controller) async {
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: Scaffold(
        body: CareTodaySummaryCard(controller: controller, idToken: 'token-123'),
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
      expect(find.textContaining(loc.careTodaySummarySeeAll), findsNothing);
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
    });

    testWidgets('no schedules: renders nothing', (tester) async {
      final controller = _controllerFor(const []);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
    });

    testWidgets('loading: renders nothing', (tester) async {
      final controller = _controllerFor([_slot(status: CareTodayStatus.overdue)]);
      // Deliberately not calling load() — status stays at its initial
      // `loading` value.

      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('care-today-summary-card')), findsNothing);
    });

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

    testWidgets('tapping the card body pushes /care-today', (tester) async {
      final controller = _controllerFor([_slot(status: CareTodayStatus.overdue)]);
      await controller.load('token-123');

      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(loc.careTodayTitle));
      await tester.pumpAndSettle();

      expect(find.text('/care-today'), findsOneWidget);
    });

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
}
