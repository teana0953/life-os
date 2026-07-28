import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_exceptions.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_card.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../../support/l10n_test_app.dart';

class _FakeRepository implements HealthCalendarRepository {
  Object? error;
  int getCalls = 0;

  /// When set, `getCalendar` waits on this before completing — lets a test
  /// observe the in-flight loading state of a reload.
  Completer<void>? gate;
  HealthCalendar Function(int year, int month) build =
      (year, month) => HealthCalendar(
            year: year,
            month: month,
            loggedDays: const {'2026-07-03', '2026-07-04'},
            daysElapsed: 5,
            loggingRate: 20,
            dietAdherenceRate: 40,
          );

  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async {
    getCalls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return build(year, month);
  }
}

Future<HealthCalendarController> _pump(
  WidgetTester tester,
  _FakeRepository repo, {
  int? weightAchievementRate = 75,
}) async {
  final controller = HealthCalendarController(
    GetHealthCalendar(repo),
    clock: () => DateTime(2026, 7, 5),
  );
  await controller.load('token');
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HealthCalendarCard(
            controller: controller,
            idToken: 'token',
            weightAchievementRate: weightAchievementRate,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('shows three rings, the month dots, and a legend', (tester) async {
    await _pump(tester, _FakeRepository());

    // Three adherence rings.
    expect(find.byKey(const Key('health-calendar-ring-logging')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-ring-diet')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-ring-weight')), findsOneWidget);

    // The month rates + the reused weight-goal rate are shown.
    expect(find.text('20%'), findsOneWidget); // logging rate
    expect(find.text('40%'), findsOneWidget); // diet adherence
    expect(find.text('75%'), findsOneWidget); // weight achievement (reused)

    // Dots mark the two logged days but not an unlogged one.
    expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-dot-4')), findsOneWidget);
    expect(find.byKey(const Key('health-calendar-dot-15')), findsNothing);

    expect(find.byKey(const Key('health-calendar-legend')), findsOneWidget);
  });

  testWidgets('a null rate shows an empty ring and no percentage', (tester) async {
    final repo = _FakeRepository()
      ..build = (year, month) => HealthCalendar(
            year: year,
            month: month,
            loggedDays: const {},
            daysElapsed: 0,
            loggingRate: null,
            dietAdherenceRate: null,
          );
    await _pump(tester, repo, weightAchievementRate: null);

    // No percentage text anywhere (all three rings are null).
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('an error with no month drawn yet shows a retry that reloads', (
    tester,
  ) async {
    final repo = _FakeRepository()..error = const HealthCalendarFetchFailure();
    final controller = HealthCalendarController(
      GetHealthCalendar(repo),
      clock: () => DateTime(2026, 7, 5),
    );
    await controller.load('token');
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(
          body: HealthCalendarCard(
            controller: controller,
            idToken: 'token',
            weightAchievementRate: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_en.healthCalendarLoadFailed), findsOneWidget);
    // Nothing has been drawn, so there is nothing to mark as unrefreshed.
    expect(find.byType(StaleNotice), findsNothing);

    repo.error = null;
    await tester.tap(find.byKey(const Key('health-calendar-retry')));
    await tester.pumpAndSettle();

    expect(controller.status, HealthCalendarStatus.loaded);
    expect(find.byKey(const Key('health-calendar-ring-logging')), findsOneWidget);
  });

  testWidgets('a first-ever load in flight shows the loading state', (
    tester,
  ) async {
    final repo = _FakeRepository();
    final controller = HealthCalendarController(
      GetHealthCalendar(repo),
      clock: () => DateTime(2026, 7, 5),
    );
    // Deliberately not awaiting load() — status stays `loading` with no month
    // held yet. `pump`, not `pumpAndSettle`: the spinner never settles.
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(
          body: HealthCalendarCard(
            controller: controller,
            idToken: 'token',
            weightAchievementRate: null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('health-calendar-loading')), findsOneWidget);
  });

  testWidgets(
    'a reload in flight keeps the month it already drew, unmarked — a refresh '
    'in flight is not a failure',
    (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);

      final gate = Completer<void>();
      repo.gate = gate;
      unawaited(controller.load('token'));
      await tester.pump();

      expect(find.byKey(const Key('health-calendar-loading')), findsNothing);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
      // The marking's row, not [StaleNotice] itself: the card keeps the widget
      // mounted through a reload so it can remember a retry the user pressed,
      // and it renders nothing until it has something to say.
      expect(find.byKey(const Key('stale-notice-row')), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a failed reload keeps the month it already drew and marks it as not '
    'refreshed — the largest card on the overview does not disappear',
    (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);

      repo.error = const HealthCalendarFetchFailure();
      await controller.load('token');
      await tester.pumpAndSettle();

      expect(controller.status, HealthCalendarStatus.error);
      expect(find.text(_en.healthCalendarLoadFailed), findsNothing);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
      expect(find.byKey(const Key('health-calendar-ring-logging')), findsOneWidget);
      expect(find.byType(StaleNotice), findsOneWidget);
      expect(find.text(_en.cardRefreshFailed), findsOneWidget);
    },
  );

  testWidgets(
    'a reload that 401s is not the card\'s to report — no marking, no error '
    'card, the overview\'s re-authenticate exit takes over',
    (tester) async {
      final repo = _FakeRepository();
      final controller = await _pump(tester, repo);

      repo.error = const HealthCalendarReauthenticationRequired();
      await controller.load('token');
      await tester.pumpAndSettle();

      expect(controller.status, HealthCalendarStatus.needsReauth);
      expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
      // "Couldn't refresh, retry" would send the user round a loop that
      // cannot succeed until they sign in again.
      expect(find.byType(StaleNotice), findsNothing);
      expect(find.text(_en.healthCalendarLoadFailed), findsNothing);
    },
  );

  testWidgets('the marking\'s retry reloads the calendar and clears it on '
      'success', (tester) async {
    final repo = _FakeRepository();
    final controller = await _pump(tester, repo);
    repo.error = const HealthCalendarFetchFailure();
    await controller.load('token');
    await tester.pumpAndSettle();
    final callsBefore = repo.getCalls;

    repo.error = null;
    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pumpAndSettle();

    expect(repo.getCalls, callsBefore + 1);
    expect(find.byType(StaleNotice), findsNothing);
    expect(find.byKey(const Key('health-calendar-dot-3')), findsOneWidget);
  });
}
