import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/card_error_retry.dart';
import '../../../shared/widgets/card_loading.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/vitals_day.dart';
import '../domain/vitals_series.dart';
import 'trend_controller.dart';

/// The dashboard's second card: a line chart of one vitals metric over a date
/// range, with a metric picker and a 7 / 30 / 90-day range selector. The
/// selected metric is card-local state (switching it only re-plots); the range
/// span drives [TrendController.setSpan] (which reloads). Loading and error
/// states render inside the card; `needsReauth` is left to the
/// [HealthScaffold] layer. Colors come from [Theme] only.
class TrendCard extends StatefulWidget {
  final TrendController controller;
  final String idToken;

  /// The user's height in cm, used to derive the weight metric's normal-range
  /// band (null when unset → no weight band).
  final double? heightCm;

  const TrendCard({
    super.key,
    required this.controller,
    required this.idToken,
    this.heightCm,
  });

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  TrendView _selected = TrendView.weight;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// The metric-picker label for a [view].
  String _viewLabel(AppLocalizations loc, TrendView view) => switch (view) {
    TrendView.weight => loc.trendMetricWeight,
    TrendView.bodyFat => loc.trendMetricBodyFat,
    TrendView.bloodPressurePulse => loc.trendMetricBloodPressurePulse,
    TrendView.glucose => loc.trendMetricGlucose,
    TrendView.spo2 => loc.trendMetricSpo2,
  };

  /// The legend label for a single [metric] line (used for the combined view's
  /// per-line legend).
  String _metricLabel(AppLocalizations loc, VitalsMetric metric) =>
      switch (metric) {
        VitalsMetric.weight => loc.trendMetricWeight,
        VitalsMetric.bodyFat => loc.trendMetricBodyFat,
        VitalsMetric.systolic => loc.trendMetricSystolic,
        VitalsMetric.diastolic => loc.trendMetricDiastolic,
        VitalsMetric.pulse => loc.trendMetricPulse,
        VitalsMetric.glucose => loc.trendMetricGlucose,
        VitalsMetric.spo2 => loc.trendMetricSpo2,
      };

  /// The unit suffix shown for [view] (near the card title), so the plotted
  /// numbers aren't ambiguous. The combined view mixes mmHg and bpm.
  String _viewUnit(AppLocalizations loc, TrendView view) => switch (view) {
    TrendView.weight => loc.trendUnitKg,
    TrendView.bodyFat => loc.trendUnitPercent,
    TrendView.bloodPressurePulse => '${loc.trendUnitMmhg} · ${loc.trendUnitBpm}',
    TrendView.glucose => loc.trendUnitMgdl,
    TrendView.spo2 => loc.trendUnitPercent,
  };

  /// The Theme-derived line color for [metric] within the combined view, so the
  /// three lines stay visually distinct. Three well-separated hues that each read
  /// against the pale card: blue (systolic), muted ink (diastolic), pink (pulse).
  /// The `tertiary` accent is a pale yellow — too low-contrast for a thin line —
  /// so it is avoided here.
  Color _metricColor(ColorScheme scheme, VitalsMetric metric) =>
      switch (metric) {
        VitalsMetric.diastolic => scheme.onSurfaceVariant,
        VitalsMetric.pulse => scheme.secondary,
        _ => scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // needsReauth is handled by the HealthScaffold (which replaces the whole
    // body with a sign-in-again exit), so the card renders nothing for it.
    // Only the *initial* load (no range fetched yet) gets a card-sized spinner;
    // a span-switch reload keeps the card shell (title + pickers + previous
    // chart) and shows a lightweight overlay instead of collapsing to a spinner.
    if ((controller.status == TrendStatus.loading &&
            controller.range == null) ||
        controller.status == TrendStatus.needsReauth) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: CardLoading(indicatorKey: Key('trend-card-loading')),
      );
    }

    if (controller.status == TrendStatus.error) {
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: CardErrorRetry(
          message: loc.trendLoadFailed,
          messageKey: const Key('trend-card-error'),
          retryKey: const Key('trend-card-retry'),
          onRetry: () => controller.load(widget.idToken),
        ),
      );
    }

    final scheme = theme.colorScheme;
    final range = controller.range;
    final isGlucose = _selected == TrendView.glucose;

    // The lines plotted for the selected view. Most views map to their metrics
    // (one line each; three for blood pressure & pulse). The glucose view is
    // special: its single glucose series is split by meal context into up to
    // four coloured lines (fasting / pre-meal / post-meal / unspecified).
    final List<_ChartLine> lines;
    if (isGlucose) {
      final glucose = range?.series.glucose ?? const <SeriesPoint>[];
      List<SeriesPoint> pointsFor(GlucoseMealContext? context) =>
          [for (final p in glucose) if (p.mealContext == context) p];
      lines = [
        _ChartLine(
          points: pointsFor(GlucoseMealContext.fasting),
          color: scheme.primary,
          label: loc.glucoseContextFasting,
        ),
        _ChartLine(
          points: pointsFor(GlucoseMealContext.preMeal),
          color: scheme.secondary,
          label: loc.glucoseContextPreMeal,
        ),
        _ChartLine(
          points: pointsFor(GlucoseMealContext.postMeal),
          color: scheme.onSurfaceVariant,
          label: loc.glucoseContextPostMeal,
        ),
        _ChartLine(
          points: pointsFor(null),
          color: scheme.tertiary,
          label: loc.glucoseContextUnspecified,
        ),
      ];
    } else {
      final metrics = metricsForView(_selected);
      lines = [
        for (final metric in metrics)
          _ChartLine(
            points: range == null
                ? const <SeriesPoint>[]
                : seriesFor(range.series, metric),
            color: _metricColor(scheme, metric),
            label: _metricLabel(loc, metric),
          ),
      ];
    }
    final hasChart = range != null && lines.any((l) => l.points.isNotEmpty);
    // A span-switch reload (status is loading but a previous range is still
    // held): keep the shell and overlay a thin progress bar over the chart.
    final reloading = controller.status == TrendStatus.loading;

    // The normal reference band: a single-metric view uses its metric's range;
    // the glucose view keeps a general glucose band (70–140) behind its
    // per-context lines; the BP & pulse view shows none (three overlapping
    // clinical bands would be noise). Its subtle fill is Theme-derived so it
    // reads in both light and dark.
    final NormalRange? normal;
    if (isGlucose) {
      normal = normalRangeFor(VitalsMetric.glucose);
    } else {
      final metrics = metricsForView(_selected);
      normal = metrics.length == 1
          ? normalRangeFor(metrics.single, heightCm: widget.heightCm)
          : null;
    }
    final bandColor = scheme.tertiary.withValues(alpha: 0.14);
    final isMultiLine = lines.length > 1;

    // Screen-reader summary of the chart (fl_chart renders no semantics of its
    // own): the view + range in days, plus the latest value with unit for a
    // single-line view, or a "no data" summary when nothing is plotted.
    final chartSemantics = !hasChart
        ? loc.trendChartSemanticsEmpty(
            _viewLabel(loc, _selected),
            controller.spanDays,
          )
        : !isMultiLine
        ? loc.trendChartSemantics(
            _viewLabel(loc, _selected),
            controller.spanDays,
            lines.single.points.last.value,
            _viewUnit(loc, _selected),
          )
        : loc.trendChartSemanticsMulti(
            _viewLabel(loc, _selected),
            controller.spanDays,
          );

    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.trendCardTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Text(
                _viewUnit(loc, _selected),
                key: const Key('trend-unit'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final view in TrendView.values)
                ChoiceChip(
                  key: Key('trend-view-${view.name}'),
                  label: Text(_viewLabel(loc, view)),
                  selected: _selected == view,
                  onSelected: (_) => setState(() => _selected = view),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            key: const Key('trend-range-selector'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 7, label: Text(loc.trendRange7)),
              ButtonSegment(value: 30, label: Text(loc.trendRange30)),
              ButtonSegment(value: 90, label: Text(loc.trendRange90)),
            ],
            selected: {controller.spanDays},
            onSelectionChanged: (selection) =>
                controller.setSpan(widget.idToken, selection.first),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: chartSemantics,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: !hasChart
                        ? Center(
                            child: Text(
                              loc.trendEmpty,
                              key: const Key('trend-empty'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : _TrendChart(
                            lines: lines,
                            from: range.from,
                            normal: normal,
                            bandColor: bandColor,
                          ),
                  ),
                  if (reloading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        key: Key('trend-card-reloading'),
                        minHeight: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // A multi-line view labels each line; a view with a band labels it.
          // The glucose view has both (per-context lines over a glucose band).
          if (hasChart && isMultiLine) ...[
            const SizedBox(height: 8),
            Wrap(
              key: const Key('trend-lines-legend'),
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final line in lines)
                  if (line.points.isNotEmpty)
                    _LegendEntry(
                      color: line.color,
                      label: line.label,
                      outlined: false,
                    ),
              ],
            ),
          ],
          if (hasChart && normal != null) ...[
            const SizedBox(height: 8),
            _LegendEntry(
              key: const Key('trend-normal-range-legend'),
              color: bandColor,
              label: loc.trendNormalRangeLabel,
              outlined: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// A legend row: a small [color] swatch and its [label]. [outlined] draws a
/// swatch border (used for the soft normal-range band, which needs an edge to
/// read against the card) versus a solid dot (used for the line legend).
class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;

  const _LegendEntry({
    super.key,
    required this.color,
    required this.label,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined
                ? Border.all(color: theme.colorScheme.outlineVariant)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A single plotted line: its daily [points], a Theme-derived [color], and a
/// [label] for the multi-line legend.
class _ChartLine {
  final List<SeriesPoint> points;
  final Color color;
  final String label;

  const _ChartLine({
    required this.points,
    required this.color,
    required this.label,
  });
}

/// The fl_chart plot of one or more [lines] over the range starting at [from].
/// The x value of each point is its day offset from [from] plus the fraction of
/// the day its time represents, so several readings on one day spread across
/// that day's slot; day arithmetic uses UTC components so DST can't shift it.
class _TrendChart extends StatelessWidget {
  final List<_ChartLine> lines;
  final DateTime from;

  /// The single-metric view's normal range, or null when it has none (no band
  /// — including every multi-line view).
  final NormalRange? normal;

  /// The band's Theme-derived fill (shared with the card's legend swatch).
  final Color bandColor;

  const _TrendChart({
    required this.lines,
    required this.from,
    required this.normal,
    required this.bandColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.Md(languageTag);
    final spotsPerLine = [
      for (final line in lines)
        [
          for (final p in line.points)
            FlSpot(_pointX(p.day, p.time, from), p.value),
        ],
    ];
    final allSpots = [for (final spots in spotsPerLine) ...spots];
    // The x axis runs 0 (range start) → maxX (last day offset). A handful of
    // evenly spaced date labels (~4: start, thirds, end) so a point can be tied
    // to a day and the 7 / 30 / 90-day spans read differently — without so many
    // labels that they overlap.
    final maxX = allSpots.fold<double>(0, (m, s) => s.x > m ? s.x : m);
    final bottomInterval = maxX <= 0 ? 1.0 : maxX / 3;
    // With many points the per-point dots merge into a blob, so only show them
    // on sparse series — judged per line (the busiest line) so a multi-line view
    // isn't pushed over the threshold by its lines' combined count. A single-line
    // view fills the area under its line; the multi-line view omits fills so
    // overlapping lines stay readable.
    final maxLinePoints = spotsPerLine.fold<int>(
      0,
      (m, s) => s.length > m ? s.length : m,
    );
    final showDots = maxLinePoints <= 14;
    final singleLine = lines.length == 1;

    // When the metric has a normal range, draw a shaded band over it and widen
    // the y axis to include both the data and the band (with padding) so the
    // band can't be clipped; otherwise leave fl_chart's automatic y range.
    final rangeAnnotations = normal == null
        ? const RangeAnnotations()
        : RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                y1: normal!.min,
                y2: normal!.max,
                color: bandColor,
              ),
            ],
          );
    double? minY;
    double? maxY;
    if (normal != null) {
      final values = [...allSpots.map((s) => s.y), normal!.min, normal!.max];
      final dataMin = values.reduce((a, b) => a < b ? a : b);
      final dataMax = values.reduce((a, b) => a > b ? a : b);
      final pad = (dataMax - dataMin) * 0.1;
      final effectivePad = pad > 1 ? pad : 1.0;
      minY = dataMin - effectivePad;
      maxY = dataMax + effectivePad;
    }
    // Faint edges at the band's min/max so the range reads clearly even when the
    // band fill is close to the line's own area fill.
    final bandEdge = bandColor.withValues(alpha: 0.5);
    final extraLinesData = normal == null
        ? const ExtraLinesData()
        : ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: normal!.min, color: bandEdge, strokeWidth: 1),
              HorizontalLine(y: normal!.max, color: bandEdge, strokeWidth: 1),
            ],
          );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX <= 0 ? 1 : maxX,
        minY: minY,
        maxY: maxY,
        rangeAnnotations: rangeAnnotations,
        extraLinesData: extraLinesData,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: bottomInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                // Nudge the edge labels inward so the rightmost (and leftmost)
                // date isn't clipped by the chart's right/left border.
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  dateFormat.format(from.add(Duration(days: value.round()))),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                meta.formattedValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          for (var i = 0; i < lines.length; i++)
            LineChartBarData(
              spots: spotsPerLine[i],
              isCurved: false,
              color: lines[i].color,
              barWidth: 3,
              dotData: FlDotData(show: showDots),
              belowBarData: BarAreaData(
                show: singleLine,
                color: lines[i].color.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

/// The whole-day offset of [day] from [from], via UTC date components so DST
/// can't introduce an off-by-one.
double _dayOffset(DateTime day, DateTime from) {
  final d = DateTime.utc(day.year, day.month, day.day);
  final f = DateTime.utc(from.year, from.month, from.day);
  return d.difference(f).inDays.toDouble();
}

/// The x position of a point: its whole-day offset plus the fraction of the day
/// its [time] (`HH:mm`) represents, so several readings on one day spread across
/// that day's slot instead of stacking. An empty/invalid time contributes 0.
double _pointX(DateTime day, String time, DateTime from) =>
    _dayOffset(day, from) + _dayFraction(time);

/// The fraction of a day (0–1) that an `HH:mm` [time] represents; 0 when empty
/// or malformed.
double _dayFraction(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return 0;
  return (h * 60 + m) / 1440;
}
