import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/care_history.dart';
import '../domain/care_today.dart';
import 'care_history_controller.dart';

/// Which content the AppBar's SegmentedButton shows below the period picker.
enum CareHistoryMode { list, chart }

/// The `from`/`to` `YYYY-MM-DD` range for [spanDays] ending [now] (inclusive
/// of today) — mirrors [TrendController]'s span arithmetic (UTC date
/// components so a DST boundary can't shift the span by a day), but returns
/// strings directly since [CareHistoryController.load] takes them as such.
({String from, String to}) careHistoryRangeFor(int spanDays, DateTime now) {
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  final fromUtc = todayUtc.subtract(Duration(days: spanDays - 1));
  return (from: dayString(fromUtc), to: dayString(todayUtc));
}

DateTime _parseDate(String s) {
  final parts = s.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

String _statusLabel(AppLocalizations loc, CareTodayStatus status) =>
    switch (status) {
      CareTodayStatus.pending => loc.careHistoryStatusPending,
      CareTodayStatus.overdue => loc.careHistoryStatusOverdue,
      CareTodayStatus.done => loc.careHistoryStatusDone,
      CareTodayStatus.skipped => loc.careTodayStatusSkipped,
      CareTodayStatus.missed => loc.careTodayStatusMissed,
    };

IconData _statusIcon(CareTodayStatus status) => switch (status) {
  CareTodayStatus.done => Icons.check_circle_outline,
  CareTodayStatus.skipped => Icons.remove_circle_outline,
  CareTodayStatus.missed => Icons.error_outline,
  CareTodayStatus.overdue => Icons.warning_amber_outlined,
  CareTodayStatus.pending => Icons.schedule_outlined,
};

Color _statusColor(ColorScheme scheme, CareTodayStatus status) => switch (status) {
  CareTodayStatus.done => scheme.primary,
  CareTodayStatus.missed || CareTodayStatus.overdue => scheme.error,
  CareTodayStatus.skipped || CareTodayStatus.pending => scheme.onSurfaceVariant,
};

Color _dayStateColor(ColorScheme scheme, CareDayState state) => switch (state) {
  CareDayState.full => scheme.primary,
  CareDayState.partial => scheme.tertiary,
  CareDayState.missed => scheme.error,
  CareDayState.noSchedule => scheme.surfaceContainerHighest,
};

/// The care history screen (route `/care-history`): an AppBar-level
/// list/chart [CareHistoryMode] toggle plus a 7/30/90-day period picker
/// (design mirrors [TrendCard]). List mode groups the period's slots by day
/// (newest first, skipping days with nothing scheduled — the backend's
/// `days` array is dense, so an empty slot list per day is normal, not an
/// absent day); tapping a slot opens a bottom sheet to set it done/skipped.
/// Chart mode shows a headline (adherence rate / days with a dose / missed
/// count) and a per-day heatmap. Only the very first load shows a
/// full-page spinner; a period switch keeps the previous content visible
/// with a thin progress indicator instead of blanking (design mirrors
/// [TrendCard]).
class CareHistoryScreen extends StatefulWidget {
  final CareHistoryController controller;
  final AuthRepository authRepository;

  /// Returns the current time; injectable so tests can pin "today" (only the
  /// date component is used).
  final DateTime Function() clock;

  const CareHistoryScreen({
    super.key,
    required this.controller,
    required this.authRepository,
    this.clock = DateTime.now,
  });

  @override
  State<CareHistoryScreen> createState() => _CareHistoryScreenState();
}

class _CareHistoryScreenState extends State<CareHistoryScreen> {
  String _idToken = '';
  CareHistoryMode _mode = CareHistoryMode.list;
  int _spanDays = 7;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    _idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await _reload();
  }

  Future<void> _reload() {
    final range = careHistoryRangeFor(_spanDays, widget.clock());
    return widget.controller.load(_idToken, range.from, range.to);
  }

  void _setSpan(int spanDays) {
    setState(() => _spanDays = spanDays);
    _reload();
  }

  Future<void> _openEditSheet(CareTodaySlot slot) async {
    final loc = AppLocalizations.of(context)!;
    final chosen = await showModalBottomSheet<CareLogStatus>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(loc.careHistoryEditSheetTitle)),
            ListTile(
              key: const Key('care-history-edit-done'),
              leading: const Icon(Icons.check_circle_outline),
              title: Text(loc.careTodayMarkDoneButton),
              onTap: () => Navigator.of(sheetContext).pop(CareLogStatus.done),
            ),
            ListTile(
              key: const Key('care-history-edit-skip'),
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(loc.careTodaySkipButton),
              onTap: () => Navigator.of(sheetContext).pop(CareLogStatus.skipped),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await widget.controller.edit(
      _idToken,
      careScheduleId: slot.careScheduleId,
      localDate: slot.localDate,
      timeOfDay: slot.timeOfDay,
      status: chosen,
    );
    if (!mounted) return;
    if (widget.controller.editError != null) {
      final loc2 = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc2.careErrorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final appBar = AppBar(
      title: Text(loc.careHistoryTitle),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SegmentedButton<CareHistoryMode>(
            key: const Key('care-history-mode-toggle'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CareHistoryMode.list,
                label: Text(loc.careHistoryListMode),
              ),
              ButtonSegment(
                value: CareHistoryMode.chart,
                label: Text(loc.careHistoryChartMode),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
        ),
      ],
    );

    return AsyncStateScaffold(
      isLoading: controller.status == CareHistoryLoadStatus.loading &&
          controller.days.isEmpty,
      isReauth: controller.status == CareHistoryLoadStatus.reauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        if (controller.status == CareHistoryLoadStatus.error) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.careErrorGeneric,
                    key: const Key('care-history-load-error'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('care-history-retry-button'),
                    onPressed: _reload,
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final reloading = controller.status == CareHistoryLoadStatus.loading;
        final empty = careHistoryIsEmpty(controller.days);
        final todayDate = dayString(widget.clock());

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Column(
              children: [
                if (reloading)
                  const LinearProgressIndicator(
                    key: Key('care-history-reloading'),
                    minHeight: 2,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SegmentedButton<int>(
                    key: const Key('care-history-range-selector'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 7, label: Text(loc.trendRange7)),
                      ButtonSegment(value: 30, label: Text(loc.trendRange30)),
                      ButtonSegment(value: 90, label: Text(loc.trendRange90)),
                    ],
                    selected: {_spanDays},
                    onSelectionChanged: (selection) => _setSpan(selection.first),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: empty
                          ? const _EmptyState()
                          : _mode == CareHistoryMode.list
                          ? _HistoryList(
                              days: controller.days,
                              todayDate: todayDate,
                              onTapSlot: _openEditSheet,
                            )
                          : _HistoryChart(
                              days: controller.days,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          key: const Key('care-history-empty-state'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(loc.careHistoryEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              loc.careHistoryEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<CareHistoryDay> days;
  final String todayDate;
  final ValueChanged<CareTodaySlot> onTapSlot;

  const _HistoryList({
    required this.days,
    required this.todayDate,
    required this.onTapSlot,
  });

  @override
  Widget build(BuildContext context) {
    final visibleDays = days.where((d) => d.slots.isNotEmpty).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      key: const Key('care-history-list'),
      padding: const EdgeInsets.all(20),
      children: [
        for (final day in visibleDays)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _DayCard(
              day: day,
              isToday: day.date == todayDate,
              onTapSlot: onTapSlot,
            ),
          ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final CareHistoryDay day;
  final bool isToday;
  final ValueChanged<CareTodaySlot> onTapSlot;

  const _DayCard({
    required this.day,
    required this.isToday,
    required this.onTapSlot,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final header = isToday ? loc.dietDayToday : mediumDateLabel(context, _parseDate(day.date));
    final sortedSlots = [...day.slots]
      ..sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            header,
            key: Key('care-history-day-header-${day.date}'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final slot in sortedSlots)
            _SlotTile(slot: slot, onTap: () => onTapSlot(slot)),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final CareTodaySlot slot;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListTile(
      key: Key(
        'care-history-slot-${slot.careScheduleId}-${slot.localDate}-${slot.timeOfDay}',
      ),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _statusIcon(slot.status),
        color: _statusColor(theme.colorScheme, slot.status),
      ),
      title: Text(slot.title),
      subtitle: Text('${slot.timeOfDay} · ${_statusLabel(loc, slot.status)}'),
      onTap: onTap,
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<CareHistoryDay> days;

  const _HistoryChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final summary = careHistorySummary(days);
    final sortedDays = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return ListView(
      key: const Key('care-history-chart'),
      padding: const EdgeInsets.all(20),
      children: [
        _HeadlineRow(summary: summary),
        const SizedBox(height: 16),
        GridView.builder(
          key: const Key('care-history-heatmap'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final day = sortedDays[index];
            final state = careDayState(day);
            return Tooltip(
              message: mediumDateLabel(context, _parseDate(day.date)),
              child: AspectRatio(
                key: Key('care-history-cell-${day.date}'),
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _dayStateColor(Theme.of(context).colorScheme, state),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const _Legend(),
      ],
    );
  }
}

class _HeadlineRow extends StatelessWidget {
  final CareHistorySummary summary;

  const _HeadlineRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final rateText = summary.adherenceRate == null
        ? '—'
        : '${(summary.adherenceRate! * 100).round()}%';
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _HeadlineMetric(
              key: const Key('care-history-adherence-rate'),
              label: loc.careHistoryAdherenceRateLabel,
              value: rateText,
            ),
          ),
          Expanded(
            child: _HeadlineMetric(
              key: const Key('care-history-days-with-dose'),
              label: loc.careHistoryDaysWithDoseLabel,
              value: '${summary.daysWithDose}',
            ),
          ),
          Expanded(
            child: _HeadlineMetric(
              key: const Key('care-history-missed-count'),
              label: loc.careHistoryMissedCountLabel,
              value: '${summary.missedCount}',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeadlineMetric({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      key: const Key('care-history-legend'),
      spacing: 16,
      runSpacing: 4,
      children: [
        _LegendDot(color: scheme.primary, label: loc.careHistoryLegendFull),
        _LegendDot(color: scheme.tertiary, label: loc.careHistoryLegendPartial),
        _LegendDot(color: scheme.error, label: loc.careHistoryLegendMissed),
        _LegendDot(
          color: scheme.surfaceContainerHighest,
          label: loc.careHistoryLegendNoSchedule,
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

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
            border: Border.all(color: theme.colorScheme.outlineVariant),
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
