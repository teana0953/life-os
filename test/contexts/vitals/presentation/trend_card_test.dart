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

  /// Whether the spo2 / body-fat series have points (so the normal-range band
  /// tests can plot a clinical metric and a range-less metric with a chart).
  bool spo2HasData = false;
  bool bodyFatHasData = false;

  /// Whether the systolic / diastolic / pulse series have points (so the
  /// combined blood pressure & pulse view can be plotted).
  bool bpHasData = false;

  /// Whether the glucose series has points (with meal contexts) so the
  /// per-context glucose view can be plotted.
  bool glucoseHasData = false;

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
                SeriesPoint(day: from, time: '', value: 65),
                SeriesPoint(day: to, time: '', value: 64),
              ]
            : const [],
        // body fat has no points → its empty-state can be asserted.
        bodyFat: bodyFatHasData
            ? [
                SeriesPoint(day: from, time: '', value: 20),
                SeriesPoint(day: to, time: '', value: 21),
              ]
            : const [],
        systolic: bpHasData
            ? [
                SeriesPoint(day: from, time: '', value: 120),
                SeriesPoint(day: to, time: '', value: 118),
              ]
            : const [],
        diastolic: bpHasData
            ? [
                SeriesPoint(day: from, time: '', value: 80),
                SeriesPoint(day: to, time: '', value: 78),
              ]
            : const [],
        pulse: bpHasData
            ? [
                SeriesPoint(day: from, time: '', value: 72),
                SeriesPoint(day: to, time: '', value: 70),
              ]
            : const [],
        glucose: glucoseHasData
            ? [
                // Two contexts + one untagged reading (the 未分類 line).
                SeriesPoint(
                  day: from,
                  time: '07:00',
                  value: 95,
                  mealContext: GlucoseMealContext.fasting,
                ),
                SeriesPoint(
                  day: from,
                  time: '13:00',
                  value: 130,
                  mealContext: GlucoseMealContext.postMeal,
                ),
                SeriesPoint(day: to, time: '18:00', value: 110),
              ]
            : const [],
        spo2: spo2HasData
            ? [
                SeriesPoint(day: from, time: '', value: 98),
                SeriesPoint(day: to, time: '', value: 97),
              ]
            : const [],
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
  double? heightCm,
}) async {
  final controller = _controller(repository);
  if (load) await controller.load('token');
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrendCard(
            controller: controller,
            idToken: 'token',
            heightCm: heightCm,
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
  testWidgets('shows the metric picker, range selector, and a chart with data',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    // The 5 view labels and 3 range labels are present.
    expect(find.text(_en.trendMetricWeight), findsOneWidget);
    expect(find.text(_en.trendMetricBodyFat), findsOneWidget);
    expect(find.text(_en.trendMetricBloodPressurePulse), findsOneWidget);
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
      await tester.tap(find.byKey(const Key('trend-view-bodyFat')));
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

    await tester.tap(find.byKey(const Key('trend-view-spo2')));
    await tester.pumpAndSettle();
    expect(find.text(_en.trendUnitPercent), findsOneWidget);
  });

  testWidgets('a metric with no points shows the empty message and no chart',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    // Switch to body fat, which has no points.
    await tester.tap(find.byKey(const Key('trend-view-bodyFat')));
    await tester.pumpAndSettle();

    expect(find.text(_en.trendEmpty), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('switching metric back to one with data re-plots the chart',
      (tester) async {
    await _pump(tester, _FakeVitalsRepository());

    await tester.tap(find.byKey(const Key('trend-view-bodyFat')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);

    await tester.tap(find.byKey(const Key('trend-view-weight')));
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
    expect(find.byKey(const Key('trend-view-weight')), findsOneWidget);
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

  List<HorizontalRangeAnnotation> bands(WidgetTester tester) => tester
      .widget<LineChart>(find.byType(LineChart))
      .data
      .rangeAnnotations
      .horizontalRangeAnnotations;

  testWidgets(
    'a clinical metric shows a normal-range band and legend',
    (tester) async {
      await _pump(tester, _FakeVitalsRepository()..spo2HasData = true);

      await tester.tap(find.byKey(const Key('trend-view-spo2')));
      await tester.pumpAndSettle();

      // The chart carries a single horizontal band, and the legend labels it.
      expect(bands(tester), hasLength(1));
      expect(find.text(_en.trendNormalRangeLabel), findsOneWidget);

      // The y-axis extent includes the whole band so it can't be clipped.
      final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
      final band = bands(tester).single;
      expect(chart.minY <= band.y1, isTrue);
      expect(chart.maxY >= band.y2, isTrue);
    },
  );

  testWidgets(
    'a range-less metric (body fat) shows no band and no legend',
    (tester) async {
      await _pump(tester, _FakeVitalsRepository()..bodyFatHasData = true);

      await tester.tap(find.byKey(const Key('trend-view-bodyFat')));
      await tester.pumpAndSettle();

      // Body fat has a chart (it has points) but no normal range → no band.
      expect(find.byType(LineChart), findsOneWidget);
      expect(bands(tester), isEmpty);
      expect(find.text(_en.trendNormalRangeLabel), findsNothing);
    },
  );

  testWidgets(
    'the weight band appears only when a height is provided',
    (tester) async {
      // Default metric is weight, which has data. With a height, a band shows.
      await _pump(tester, _FakeVitalsRepository(), heightCm: 165);
      expect(bands(tester), hasLength(1));
      expect(find.text(_en.trendNormalRangeLabel), findsOneWidget);
    },
  );

  testWidgets(
    'the weight band is absent when no height is provided',
    (tester) async {
      await _pump(tester, _FakeVitalsRepository());
      expect(find.byType(LineChart), findsOneWidget);
      expect(bands(tester), isEmpty);
      expect(find.text(_en.trendNormalRangeLabel), findsNothing);
    },
  );

  int lineCount(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.length;

  testWidgets(
    'the BP & pulse view plots three lines with a per-line legend and no band',
    (tester) async {
      await _pump(tester, _FakeVitalsRepository()..bpHasData = true);

      await tester.tap(
        find.byKey(const Key('trend-view-bloodPressurePulse')),
      );
      await tester.pumpAndSettle();

      // One chart, three lines (systolic / diastolic / pulse), no shaded band.
      expect(find.byType(LineChart), findsOneWidget);
      expect(lineCount(tester), 3);
      expect(bands(tester), isEmpty);
      expect(find.text(_en.trendNormalRangeLabel), findsNothing);

      // The per-line legend names all three series.
      expect(find.byKey(const Key('trend-lines-legend')), findsOneWidget);
      expect(find.text(_en.trendMetricSystolic), findsOneWidget);
      expect(find.text(_en.trendMetricDiastolic), findsOneWidget);
      expect(find.text(_en.trendMetricPulse), findsOneWidget);
    },
  );

  testWidgets(
    'the BP & pulse view uses the multi-line screen-reader summary',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _FakeVitalsRepository()..bpHasData = true);

      await tester.tap(
        find.byKey(const Key('trend-view-bloodPressurePulse')),
      );
      await tester.pumpAndSettle();

      // A multi-line view has no single latest value, so it uses the
      // value-less summary (not the single-metric one).
      expect(
        find.bySemanticsLabel(
          _en.trendChartSemanticsMulti(
            _en.trendMetricBloodPressurePulse,
            30,
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets(
    'the glucose view splits by meal context into lines and keeps a band',
    (tester) async {
      await _pump(tester, _FakeVitalsRepository()..glucoseHasData = true);

      await tester.tap(find.byKey(const Key('trend-view-glucose')));
      await tester.pumpAndSettle();

      // Fasting + post-meal + untagged → three lines (pre-meal has no data).
      expect(find.byType(LineChart), findsOneWidget);
      expect(lineCount(tester), 4); // one bar per context (empty ones plot nothing)
      // The per-context legend names the contexts that have data.
      expect(find.byKey(const Key('trend-lines-legend')), findsOneWidget);
      expect(find.text(_en.glucoseContextFasting), findsOneWidget);
      expect(find.text(_en.glucoseContextPostMeal), findsOneWidget);
      expect(find.text(_en.glucoseContextUnspecified), findsOneWidget);
      // Pre-meal has no data, so it's absent from the legend.
      expect(find.text(_en.glucoseContextPreMeal), findsNothing);

      // The glucose band (70–140) is kept, with its normal-range legend.
      expect(bands(tester), hasLength(1));
      expect(find.byKey(const Key('trend-normal-range-legend')), findsOneWidget);
      expect(find.text(_en.trendNormalRangeLabel), findsOneWidget);
    },
  );
}
