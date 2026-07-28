import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/menstrual/presentation/next_period_card.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

/// A repository that is never reached: the card is a listener, not a loader
/// (design D4), so any call here is a bug the tests below should surface.
class _UnusedMenstrualRepository implements MenstrualRepository {
  @override
  Future<MenstrualOverview> getOverview(String idToken) async =>
      throw UnimplementedError();

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async => throw UnimplementedError();

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deletePeriod(String idToken, String id) async =>
      throw UnimplementedError();
}

/// A controller whose status/overview are set directly, so every state the
/// card has to render — including "reloading with content already on screen" —
/// can be posed without driving a repository. [loadCount] proves the card
/// never loads on its own.
class _FakeMenstrualController extends MenstrualController {
  _FakeMenstrualController()
    : super(
        GetMenstrualOverview(_UnusedMenstrualRepository()),
        AddPeriod(_UnusedMenstrualRepository()),
        UpdatePeriod(_UnusedMenstrualRepository()),
        DeletePeriod(_UnusedMenstrualRepository()),
      );

  int loadCount = 0;

  @override
  Future<void> load(String idToken) async {
    loadCount++;
  }
}

MenstrualPeriod _period(DateTime start, [DateTime? end]) =>
    MenstrualPeriod(id: 'p-${start.toIso8601String()}', startDate: start, endDate: end);

MenstrualOverview _overview({
  List<MenstrualPeriod> periods = const [],
  DateTime? predictedNextStart,
}) => MenstrualOverview(
  periods: periods,
  stats: MenstrualStats(predictedNextStart: predictedNextStart),
  lastPeriod: periods.isEmpty ? null : periods.last,
);

/// The date exactly as the card formats it (the app's `mediumDateLabel`), so
/// the assertions don't hard-code a locale's date shape.
String _dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

final _loc = lookupAppLocalizations(const Locale('en'));

Future<_FakeMenstrualController> _pumpCard(
  WidgetTester tester, {
  required MenstrualStatus status,
  MenstrualOverview? overview,
  DateTime? clock,
  VoidCallback? onOpen,
}) async {
  final controller = _FakeMenstrualController()
    ..status = status
    ..overview = overview;
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: NextPeriodCard(
          controller: controller,
          onOpen: onOpen ?? () {},
          clock: () => clock ?? DateTime(2026, 7, 28),
        ),
      ),
    ),
  );
  // `pump`, not `pumpAndSettle`: the first-load state renders an indeterminate
  // progress indicator, which never settles.
  await tester.pump();
  return controller;
}

void main() {
  group('NextPeriodCard states', () {
    testWidgets('a future prediction shows the date and the days to it', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
      );

      expect(find.text(_loc.nextPeriodTitle), findsOneWidget);
      expect(
        find.text(_loc.nextPeriodUpcoming(_dateLabel(DateTime(2026, 8, 2)), 5)),
        findsOneWidget,
      );
    });

    testWidgets('a prediction for today says so', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 28),
        ),
      );

      expect(find.text(_loc.nextPeriodToday), findsOneWidget);
    });

    testWidgets('a past prediction shows the date and how late it is', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 2),
        ),
      );

      expect(
        find.text(_loc.nextPeriodOverdue(_dateLabel(DateTime(2026, 7, 2)), 26)),
        findsOneWidget,
      );
    });

    testWidgets('an ongoing period shows its day and still shows the '
        'prediction', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [
            _period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
            _period(DateTime(2026, 7, 26)),
          ],
          predictedNextStart: DateTime(2026, 8, 20),
        ),
      );

      expect(find.text(_loc.nextPeriodOngoing(3)), findsOneWidget);
      expect(
        find.text(
          _loc.nextPeriodOngoingNext(_dateLabel(DateTime(2026, 8, 20))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an ongoing period with no prediction drops the secondary line '
        'entirely', (tester) async {
      // A brand-new user on the day of their first recording. Formatting a
      // null prediction here is the crash the pure-function tests cannot
      // catch, because the pure function only hands back a nullable date.
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(periods: [_period(DateTime(2026, 7, 28))]),
      );

      expect(find.text(_loc.nextPeriodOngoing(1)), findsOneWidget);
      expect(find.byKey(const Key('next-period-secondary')), findsNothing);
    });

    testWidgets('no records at all says so', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(),
      );

      expect(find.text(_loc.nextPeriodNoRecords), findsOneWidget);
      expect(find.text(_loc.nextPeriodNeedsOneMore), findsNothing);
    });

    testWidgets('a single recorded period asks for one more', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        ),
      );

      expect(find.text(_loc.nextPeriodNeedsOneMore), findsOneWidget);
    });
  });

  group('NextPeriodCard tapping', () {
    testWidgets('tapping the card opens the tracker', (tester) async {
      var opened = 0;
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
        onOpen: () => opened++,
      );

      await tester.tap(find.byKey(const Key('next-period-card')));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('the card still opens the tracker with nothing recorded — the '
        'state where the shortcut matters most', (tester) async {
      var opened = 0;
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(),
        onOpen: () => opened++,
      );

      await tester.tap(find.byKey(const Key('next-period-card')));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });
  });

  group('NextPeriodCard loading and error', () {
    testWidgets('the first load shows a spinner inside the card', (
      tester,
    ) async {
      await _pumpCard(tester, status: MenstrualStatus.loading);

      expect(find.byKey(const Key('next-period-loading')), findsOneWidget);
    });

    testWidgets('a reload keeps the content it already has instead of blanking '
        'the card', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loading,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
      );

      expect(find.byKey(const Key('next-period-loading')), findsNothing);
      expect(
        find.text(_loc.nextPeriodUpcoming(_dateLabel(DateTime(2026, 8, 2)), 5)),
        findsOneWidget,
      );
    });

    testWidgets('a load failure shows the shared menstrual error copy inside '
        'the card', (tester) async {
      await _pumpCard(tester, status: MenstrualStatus.error);

      expect(find.text(_loc.errorMenstrualLoadFailed), findsOneWidget);
    });
  });

  testWidgets('the card never loads by itself — the scaffold owns that', (
    tester,
  ) async {
    final controller = await _pumpCard(
      tester,
      status: MenstrualStatus.loaded,
      overview: _overview(),
    );

    expect(controller.loadCount, 0);
  });
}
