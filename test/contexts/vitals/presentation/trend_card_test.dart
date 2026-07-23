import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/presentation/trend_card.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class _FakeVitalsRepository implements VitalsRepository {
  DateTime? gotFrom;
  DateTime? gotTo;
  int getRangeCalls = 0;
  Object? getError;

  /// Whether the weight series has points (so the empty-state test can toggle).
  bool weightHasData = true;

  /// When set, getRange blocks on this until it completes (so a reload's
  /// loading state can be observed mid-flight).
  Completer<void>? gate;

  @override
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async {
    getRangeCalls++;
    gotFrom = from;
    gotTo = to;
    if (gate != null) await gate!.future;
    if (getError != null) throw getError!;
    return VitalsRange(
      from: from,
      to: to,
      series: VitalsSeries(
        weight: weightHasData
            ? [
                SeriesPoint(day: from, value: 65),
                SeriesPoint(day: to, value: 64),
              ]
            : const [],
        // body fat has no points → its empty-state can be asserted.
        bodyFat: const [],
        systolic: const [],
        diastolic: const [],
        pulse: const [],
        glucose: const [],
        spo2: const [],
      ),
    );
  }

  @override
  Future<VitalsDay> getDay(String idToken, String day) => throw UnimplementedError();

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) => throw UnimplementedError();
}

TrendController _controller(_FakeVitalsRepository repository) => TrendController(
  GetVitalsTrends(repository),
  clock: () => DateTime(2026, 7, 22),
);

Future<TrendController> _pump(
  WidgetTester tester,
  _FakeVitalsRepository repository, {
  bool load = true,
  Locale locale = const Locale('en'),
}) async {
  final controller = _controller(repository);
  if (load) await controller.load('token');
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrendCard(controller: controller, idToken: 'token'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('shows the metric picker, range selector, and a chart with data',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    // The 7 metric labels and 3 range labels are present.
    expect(find.text(_en.trendMetricWeight), findsOneWidget);
    expect(find.text(_en.trendMetricBodyFat), findsOneWidget);
    expect(find.text(_en.trendMetricSpo2), findsOneWidget);
    expect(find.text(_en.trendRange7), findsOneWidget);
    expect(find.text(_en.trendRange30), findsOneWidget);
    expect(find.text(_en.trendRange90), findsOneWidget);

    // Weight (the default metric) has data → a LineChart is plotted.
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('the chart renders localized date labels on the x axis',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    // The bottom axis shows a few short M/d date labels (en uses a "/"),
    // so a point can be tied to a day. The left axis shows plain numbers.
    expect(find.textContaining('/'), findsWidgets);
  });

  testWidgets(
    'the chart renders localized date labels under a zh-Hant locale',
    (tester) async {
      // Locks in that DateFormat.Md is initialized for the active locale (a
      // non-initialized locale would throw); zh-Hant's Md is also "M/d".
      await _pump(
        tester,
        _FakeVitalsRepository(),
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('/'), findsWidgets);
    },
  );

  testWidgets(
    'the chart exposes a screen-reader summary when the metric has data',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _FakeVitalsRepository());

      // Default metric weight, default 30-day span, latest weight point is 64.
      expect(
        find.bySemanticsLabel(
          _en.trendChartSemantics(_en.trendMetricWeight, 30, 64, _en.trendUnitKg),
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'the chart summary announces no data for an empty metric',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _FakeVitalsRepository());

      // Body fat has no points → the empty summary is exposed instead.
      await tester.tap(find.byKey(const Key('trend-metric-bodyFat')));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          _en.trendChartSemanticsEmpty(_en.trendMetricBodyFat, 30),
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets('the card shows the selected metric unit', (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    // Default metric is weight → kg. Switching to a percentage metric updates.
    expect(find.byKey(const Key('trend-unit')), findsOneWidget);
    expect(find.text(_en.trendUnitKg), findsOneWidget);

    await tester.tap(find.byKey(const Key('trend-metric-spo2')));
    await tester.pumpAndSettle();
    expect(find.text(_en.trendUnitPercent), findsOneWidget);
  });

  testWidgets('a metric with no points shows the empty message and no chart',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    // Switch to body fat, which has no points.
    await tester.tap(find.byKey(const Key('trend-metric-bodyFat')));
    await tester.pumpAndSettle();

    expect(find.text(_en.trendEmpty), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('switching metric back to one with data re-plots the chart',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    await tester.tap(find.byKey(const Key('trend-metric-bodyFat')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);

    await tester.tap(find.byKey(const Key('trend-metric-weight')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('switching range calls setSpan with the new from/to',
      (tester) async {
    final repository = _FakeVitalsRepository();
    await _pump(tester, repository);
    expect(repository.getRangeCalls, 1);

    await tester.tap(find.text(_en.trendRange7));
    await tester.pumpAndSettle();

    expect(repository.getRangeCalls, 2);
    // 7-day span ending 2026-07-22 → from 2026-07-16.
    expect(repository.gotFrom, DateTime(2026, 7, 16));
    expect(repository.gotTo, DateTime(2026, 7, 22));
  });

  testWidgets('switching range keeps the card shell instead of collapsing',
      (tester) async {
    final repository = _FakeVitalsRepository();
    final controller = await _pump(tester, repository);

    // Hold the next load mid-flight, then switch span.
    final gate = Completer<void>();
    repository.gate = gate;
    controller.setSpan('token', 7); // not awaited: stays in loading
    await tester.pump();

    // The shell survives: metric chips + range selector still there, a
    // lightweight reload bar shows, and it did NOT collapse to the card spinner.
    expect(find.byKey(const Key('trend-metric-weight')), findsOneWidget);
    expect(find.byKey(const Key('trend-range-selector')), findsOneWidget);
    expect(find.byKey(const Key('trend-card-reloading')), findsOneWidget);
    expect(find.byKey(const Key('trend-card-loading')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trend-card-reloading')), findsNothing);
  });

  testWidgets('a load failure shows an error state with a retry',
      (tester) async {
    final repository = _FakeVitalsRepository()
      ..getError = const VitalsFetchFailure('boom');
    final controller = await _pump(tester, repository);

    expect(find.text(_en.trendLoadFailed), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);

    // Recover, then tap retry → reloads and the chart appears.
    repository.getError = null;
    await tester.tap(find.byKey(const Key('trend-card-retry')));
    await tester.pumpAndSettle();

    expect(controller.status, TrendStatus.loaded);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
