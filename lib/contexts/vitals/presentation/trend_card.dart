import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/vitals_series.dart';
import 'trend_controller.dart';

/// The dashboard's second card: a line chart of one vitals metric over a date
/// range, with a metric picker and a 7 / 30 / 90-day range selector. The
/// selected metric is card-local state (switching it only re-plots); the range
/// span drives [TrendController.setSpan] (which reloads). Loading and error
/// states render inside the card; `needsReauth` is left to the
/// [DashboardScreen] layer. Colors come from [Theme] only.
class TrendCard extends StatefulWidget {
  final TrendController controller;
  final String idToken;

  const TrendCard({super.key, required this.controller, required this.idToken});

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  VitalsMetric _selected = VitalsMetric.weight;

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

  /// The unit suffix shown for [metric] (near the card title), so the plotted
  /// numbers aren't ambiguous.
  String _metricUnit(AppLocalizations loc, VitalsMetric metric) =>
      switch (metric) {
        VitalsMetric.weight => loc.trendUnitKg,
        VitalsMetric.bodyFat => loc.trendUnitPercent,
        VitalsMetric.systolic => loc.trendUnitMmhg,
        VitalsMetric.diastolic => loc.trendUnitMmhg,
        VitalsMetric.pulse => loc.trendUnitBpm,
        VitalsMetric.glucose => loc.trendUnitMgdl,
        VitalsMetric.spo2 => loc.trendUnitPercent,
      };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // needsReauth is handled by the DashboardScreen (which replaces the whole
    // body with a sign-in-again exit), so the card renders nothing for it.
    // Only the *initial* load (no range fetched yet) gets a card-sized spinner;
    // a span-switch reload keeps the card shell (title + pickers + previous
    // chart) and shows a lightweight overlay instead of collapsing to a spinner.
    if ((controller.status == TrendStatus.loading &&
            controller.range == null) ||
        controller.status == TrendStatus.needsReauth) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(key: Key('trend-card-loading')),
          ),
        ),
      );
    }

    if (controller.status == TrendStatus.error) {
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.trendLoadFailed,
              key: const Key('trend-card-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('trend-card-retry'),
              onPressed: () => controller.load(widget.idToken),
              child: Text(loc.retry),
            ),
          ],
        ),
      );
    }

    final range = controller.range;
    final points = range == null
        ? const <SeriesPoint>[]
        : seriesFor(range.series, _selected);
    // A span-switch reload (status is loading but a previous range is still
    // held): keep the shell and overlay a thin progress bar over the chart.
    final reloading = controller.status == TrendStatus.loading;

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
                _metricUnit(loc, _selected),
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
              for (final metric in VitalsMetric.values)
                ChoiceChip(
                  key: Key('trend-metric-${metric.name}'),
                  label: Text(_metricLabel(loc, metric)),
                  selected: _selected == metric,
                  onSelected: (_) => setState(() => _selected = metric),
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: points.isEmpty || range == null
                      ? Center(
                          child: Text(
                            loc.trendEmpty,
                            key: const Key('trend-empty'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : _TrendChart(points: points, from: range.from),
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
        ],
      ),
    );
  }
}

/// The fl_chart line plot of [points] over the range starting at [from]. The
/// x value of each point is its day offset from [from], computed with
/// UTC/date-component arithmetic so a DST boundary can't shift it by a day.
class _TrendChart extends StatelessWidget {
  final List<SeriesPoint> points;
  final DateTime from;

  const _TrendChart({required this.points, required this.from});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageTag = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.Md(languageTag);
    final spots = [
      for (final p in points) FlSpot(_dayOffset(p.day, from), p.value),
    ];
    // The x axis runs 0 (range start) → maxX (last day offset). A handful of
    // evenly spaced date labels (~4: start, thirds, end) so a point can be tied
    // to a day and the 7 / 30 / 90-day spans read differently — without so many
    // labels that they overlap.
    final maxX = spots.fold<double>(0, (m, s) => s.x > m ? s.x : m);
    final bottomInterval = maxX <= 0 ? 1.0 : maxX / 3;
    // With many points the per-point dots merge into a blob, so only show them
    // on sparse series.
    final showDots = spots.length <= 14;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX <= 0 ? 1 : maxX,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
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
                child: Text(
                  dateFormat.format(
                    from.add(Duration(days: value.round())),
                  ),
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
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: showDots),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
