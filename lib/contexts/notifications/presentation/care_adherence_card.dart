import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/card_error_retry.dart';
import '../../../shared/widgets/card_loading.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/care_history.dart';
import 'care_history_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

// The heatmap is a *luminance ramp*, not five hues. A 25px square carries
// almost no shape, so hue is the only channel it has left — and a greyscale
// print, a monochrome display, or a fully color-blind reader has none of it.
// Both themes' scheme roles are bunched at one end of the range (the light
// pastels all sit at 0.54–0.76 relative luminance against a 0.98 card; the
// dark ones at 0.38–0.64 against a 0.02 card), so used raw, "complete" and
// "no schedule" measured 1.01:1 apart in the light theme. Each state
// therefore gets its own tier, ~1.38× apart, so every fill clears 1.3:1
// against the card *and* against every other fill (guarded by
// care_adherence_card_test.dart's per-state and pairwise assertions).
//
// The ramp runs noSchedule → upcoming → partial → full → missed, i.e. faint
// to strong, which in the light theme means light to dark and in the dark
// theme dim to bright. `missed` anchors the strong end with `scheme.error`
// untouched (and, in the dark theme, `full` with `scheme.primary`); the
// others are pulled toward the theme's ink (light — the pastels are too
// pale) or toward the card surface (dark — they are too bright and too
// close together). All values stay derived from the ColorScheme, never
// hard-coded, so a theme change moves the whole ramp with it.
const _lightFullAlpha = 0.46; // primary, deepened toward the ink
const _lightPartialAlpha = 0.55; // tertiary, deepened toward the ink
const _lightUpcomingAlpha = 0.93; // secondary, deepened toward the ink
const _lightNoScheduleAlpha = 0.24; // onSurfaceVariant, tinted onto the card
const _darkPartialAlpha = 0.57; // tertiary, dimmed onto the card
const _darkUpcomingAlpha = 0.5; // secondary, dimmed onto the card
const _darkNoScheduleAlpha = 0.35; // onSurfaceVariant, dimmed onto the card

/// The fill for [state]'s heatmap cell (and its legend swatch — one source,
/// so a swatch can't drift from the cells it counts). `onSurfaceVariant`
/// rather than `surfaceContainerHighest` for `noSchedule`: this app's
/// hand-written ColorScheme leaves the container roles unset, so they fall
/// back to `surface` — exactly the enclosing LedgeCard's own fill, i.e. an
/// invisible cell.
Color _dayStateColor(ColorScheme scheme, CareDayState state) {
  final light = scheme.brightness == Brightness.light;
  return switch (state) {
    CareDayState.missed => scheme.error,
    CareDayState.full => light
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: _lightFullAlpha),
            scheme.onSurface,
          )
        : scheme.primary,
    CareDayState.partial => light
        ? Color.alphaBlend(
            scheme.tertiary.withValues(alpha: _lightPartialAlpha),
            scheme.onSurface,
          )
        : scheme.tertiary.withValues(alpha: _darkPartialAlpha),
    CareDayState.upcoming => light
        ? Color.alphaBlend(
            scheme.secondary.withValues(alpha: _lightUpcomingAlpha),
            scheme.onSurface,
          )
        : scheme.secondary.withValues(alpha: _darkUpcomingAlpha),
    CareDayState.noSchedule => scheme.onSurfaceVariant.withValues(
      alpha: light ? _lightNoScheduleAlpha : _darkNoScheduleAlpha,
    ),
  };
}

/// The screen-reader summary sentence announced immediately before the
/// heatmap grid (design D1): every state that actually occurs in the loaded
/// period, with its day count, joined by the locale's own list separator.
///
/// States with a count of zero are dropped — "Partial (0), Missed (0)" is
/// pure noise in a linear announcement, and the sighted legend still shows
/// them. The separator comes from the ARB rather than a hard-coded `', '`
/// because `careAdherenceLegendWithCount` already wraps Chinese counts in
/// full-width parentheses, which an ASCII comma clashes with.
String _heatmapSummaryDetails(
  AppLocalizations loc,
  Map<CareDayState, int> counts,
) => CareDayState.values
    .where((state) => counts[state]! > 0)
    .map(
      (state) =>
          loc.careAdherenceLegendWithCount(_dayStateLabel(loc, state), counts[state]!),
    )
    .join(loc.careAdherenceHeatmapSummarySeparator);

/// The legend/tooltip/Semantics word for [state] — shared between the
/// heatmap cells (date + state text) and the legend (label + count).
String _dayStateLabel(AppLocalizations loc, CareDayState state) => switch (state) {
  CareDayState.full => loc.careHistoryLegendFull,
  CareDayState.partial => loc.careHistoryLegendPartial,
  CareDayState.missed => loc.careHistoryLegendMissed,
  CareDayState.upcoming => loc.careHistoryLegendUpcoming,
  CareDayState.noSchedule => loc.careHistoryLegendNoSchedule,
};

/// The trend tab's second card (after [TrendCard]): a heatmap summarizing
/// care schedule adherence over a selectable period (7/30/90 days), with a
/// headline (adherence rate / days with care done / missed slots), a
/// per-day heatmap, and a legend — derived from the same
/// [CareHistoryController] that drives the care history screen, but its own
/// instance (design §B) so the two periods don't fight over shared state.
/// Lives inside [HealthScaffold]'s `_TrendBody`, which is already a
/// `ListView`, so unlike the old care-history "chart mode" this card holds
/// no scrollable of its own — everything here is `shrinkWrap`/non-scrolling.
/// Does **not** load on its own (only `addListener`, mirroring `TrendCard`)
/// — [HealthScaffold._load] drives the first load, since this card lives
/// inside a scaffold that already owns a `Future.wait` over every overview/
/// trend controller; a second, card-driven load here would race it (design
/// §A).
class CareAdherenceCard extends StatefulWidget {
  final CareHistoryController controller;
  final IdTokenProvider idToken;

  /// Opens the care history record list (`/care-history`), wired by the
  /// caller. Seeing "Missed 5" here is the moment a user wants to go correct
  /// those records, and `/care-history` is a top-level route with no link
  /// anywhere inside the health module — without this the shortest path
  /// runs through the More tab and care management.
  final VoidCallback onOpenHistory;

  /// Opens care management (`/care-items`), wired by the caller — offered
  /// from the empty state (task 4.3) for a user with no care items at all,
  /// distinct from [onOpenHistory] (which opens the record list, the wrong
  /// destination when there is nothing to correct in the first place).
  final VoidCallback onOpenCareItems;

  const CareAdherenceCard({
    super.key,
    required this.controller,
    required this.idToken,
    required this.onOpenHistory,
    required this.onOpenCareItems,
  });

  @override
  State<CareAdherenceCard> createState() => _CareAdherenceCardState();
}

class _CareAdherenceCardState extends State<CareAdherenceCard> {
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Only the very first load (no days fetched yet) gets a card-sized
    // spinner; a period-switch reload keeps the card shell and shows a thin
    // progress indicator instead. `needsReauth` is handled by the
    // HealthScaffold (which replaces the whole body with a sign-in-again
    // exit), so this card renders the same placeholder for it as for the
    // initial load — it won't actually be visible once the scaffold reacts.
    if ((controller.status == CareHistoryLoadStatus.loading &&
            controller.days.isEmpty) ||
        controller.status == CareHistoryLoadStatus.reauth) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: CardLoading(indicatorKey: Key('care-adherence-card-loading')),
      );
    }

    // The header (title + period selector) is shared with the error state on
    // purpose: dropping the selector there would strand a user whose 90-day
    // load failed (the slowest, likeliest-to-time-out period) with nothing
    // but a retry of the very request that just failed.
    final header = [
      Row(
        children: [
          Expanded(
            child: Text(
              loc.careAdherenceCardTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          TextButton.icon(
            key: const Key('care-adherence-open-history'),
            onPressed: widget.onOpenHistory,
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: Text(loc.careAdherenceOpenHistory),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SegmentedButton<int>(
        key: const Key('care-adherence-range-selector'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 7, label: Text(loc.trendRange7)),
          ButtonSegment(value: 30, label: Text(loc.trendRange30)),
          ButtonSegment(value: 90, label: Text(loc.trendRange90)),
        ],
        selected: {controller.spanDays},
        onSelectionChanged: (selection) async =>
            controller.setSpan(await widget.idToken(), selection.first),
      ),
    ];

    if (controller.status == CareHistoryLoadStatus.error) {
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: CardErrorRetry(
          message: loc.careErrorForPeriod(controller.spanDays),
          messageKey: const Key('care-adherence-card-error'),
          retryKey: const Key('care-adherence-card-retry'),
          onRetry: () async => controller.load(await widget.idToken()),
          header: header,
        ),
      );
    }

    final reloading = controller.status == CareHistoryLoadStatus.loading;
    final empty = careHistoryIsEmpty(controller.days);
    final summary = careHistorySummary(controller.days);
    final counts = careDayStateCounts(controller.days);
    final sortedDays = [...controller.days]..sort((a, b) => a.date.compareTo(b.date));

    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...header,
          if (reloading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              key: Key('care-adherence-card-reloading'),
              minHeight: 2,
            ),
          ],
          const SizedBox(height: 16),
          if (empty)
            _EmptyState(onOpenCareItems: widget.onOpenCareItems)
          else ...[
            _HeadlineRow(summary: summary),
            const SizedBox(height: 16),
            _Heatmap(sortedDays: sortedDays, counts: counts),
            const SizedBox(height: 16),
            _Legend(counts: counts),
          ],
        ],
      ),
    );
  }
}

/// The heatmap grid itself: 7 fixed columns (design D3 — so a given column
/// is always the same weekday), each cell capped at 24dp with the grid
/// left-aligned rather than stretched once the available width exceeds that
/// (design D2 — a `GridView`'s cross axis otherwise always spans the full
/// incoming width regardless of `shrinkWrap`). A weekday header sits above
/// the grid and a start–end date caption below it; both are derived from
/// [sortedDays.first]/[sortedDays.last] since this card has no clock of its
/// own (design D3 — relies on the backend's `days` array being dense).
///
/// The weekday header row doubles as the carrier for the screen-reader
/// summary (design D1). It is *not* a standalone `Semantics` wrapping a
/// `SizedBox.shrink()`: a node whose rect is empty is invisible
/// (`SemanticsNode.isInvisible`) and gets dropped from its parent's children
/// before the tree is sent to the platform, so such a summary would never be
/// announced at all — while `tester.getSemantics`/`find.bySemanticsLabel`,
/// which read the render object's *cached* `debugSemantics`, would keep
/// passing. Hanging it on the header row gives it real geometry, and
/// excluding the header's own seven one-letter abbreviations from semantics
/// removes context-free noise (each cell's label already carries its full
/// date) in the same stroke.
class _Heatmap extends StatelessWidget {
  final List<CareHistoryDay> sortedDays;

  /// Day counts per state, for the screen-reader summary above the grid.
  final Map<CareDayState, int> counts;

  const _Heatmap({required this.sortedDays, required this.counts});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // `null` for a malformed date (design D4) — the weekday header/caption
    // fall back to "—" for that day rather than crashing the entire grid;
    // unlike the other five D4 call sites, this one sits inside a
    // `GridView.builder` loop, so an uncaught parse failure here would take
    // down the whole heatmap, not just one cell.
    final firstDate = tryParseDayString(sortedDays.first.date);
    // The period always ends today (design D3), so the last day in the
    // dense, date-sorted array is today.
    final todayDate = sortedDays.last.date;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 3.0;
        final cellSize = math.min(24.0, (constraints.maxWidth - spacing * 6) / 7);
        final rowWidth = cellSize * 7 + spacing * 6;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: rowWidth,
                child: Semantics(
                  key: const Key('care-adherence-heatmap-summary'),
                  container: true,
                  label: loc.careAdherenceHeatmapSummaryLabel(
                    _heatmapSummaryDetails(loc, counts),
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      key: const Key('care-adherence-heatmap-weekday-header'),
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: spacing),
                          SizedBox(
                            width: cellSize,
                            child: Text(
                              firstDate == null
                                  ? '—'
                                  : narrowWeekdayLabel(
                                      context,
                                      // Calendar-day arithmetic, not
                                      // `add(Duration(days: i))`: `firstDate`
                                      // is a *local* midnight, and adding 24h
                                      // across a DST fall-back lands on the
                                      // same calendar day — repeating one
                                      // weekday and shifting every column
                                      // after it by a day.
                                      DateTime(
                                        firstDate.year,
                                        firstDate.month,
                                        firstDate.day + i,
                                      ),
                                    ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: rowWidth,
                child: GridView.builder(
                  key: const Key('care-adherence-heatmap'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                  ),
                  itemCount: sortedDays.length,
                  itemBuilder: (context, index) {
                    final day = sortedDays[index];
                    final state = careDayState(day);
                    final isToday = day.date == todayDate;
                    final cellLabel = loc.careAdherenceHeatmapCellLabel(
                      mediumDateLabelOrDash(context, day.date),
                      _dayStateLabel(loc, state),
                    );
                    return Tooltip(
                      message: cellLabel,
                      // Without this, Tooltip's own semantics annotation
                      // merges its `message` into this cell's Semantics node
                      // as `SemanticsProperties.tooltip` — the same node
                      // already carrying `label` below — so a screen reader
                      // announces the cell twice (design D1). The Tooltip
                      // itself (hover/long-press) still works; only its
                      // semantics contribution is dropped.
                      excludeFromSemantics: true,
                      child: Semantics(
                        label: cellLabel,
                        child: AspectRatio(
                          key: Key('care-adherence-cell-${day.date}'),
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _dayStateColor(scheme, state),
                              borderRadius: BorderRadius.circular(4),
                              // A subtle border so a no-schedule/upcoming
                              // cell (whose fill matches the scaffold
                              // background) still reads as an empty *cell*,
                              // not a gap. Today's cell gets a thicker
                              // border instead — distinct from every other
                              // cell's, not just by color.
                              //
                              // `onSurface`, not `primary`: the dark theme's
                              // `full` fill *is* `scheme.primary`, so a
                              // primary outline around a completed today
                              // (the commonest evening state) sat at 1.000
                              // contrast against its own fill — invisible.
                              // `onSurface` is not the source of any of the
                              // five state fills in either theme.
                              border: isToday
                                  ? Border.all(color: scheme.onSurface, width: 2)
                                  : Border.all(
                                      color: scheme.outline.withValues(alpha: 0.3),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.careAdherenceHeatmapRangeCaption(
                firstDate == null ? '—' : mediumDateLabel(context, firstDate),
                mediumDateLabelOrDash(context, todayDate),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  /// Opens care management (`/care-items`) — task 4.3: the card has no
  /// other callback pointed at it (only [CareAdherenceCard.onOpenHistory],
  /// which opens the record list — the wrong destination when there is
  /// nothing to correct in the first place).
  final VoidCallback onOpenCareItems;

  const _EmptyState({required this.onOpenCareItems});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      key: const Key('care-adherence-empty-state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.event_note_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        // The "no care items yet" wording, not "nothing was scheduled in
        // this period": the only action offered here is "go to care
        // management", and a period-scoped complaint followed by a
        // configure-your-items button is the very mismatch the care history
        // screen's own empty state already fixed. This card has its own
        // period picker, so widening isn't the story here either.
        Text(loc.careHistoryNoCareItemsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          loc.careHistoryNoCareItemsBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('care-adherence-empty-manage-button'),
          onPressed: onOpenCareItems,
          child: Text(loc.careHistoryEmptyManageButton),
        ),
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
    return Row(
      children: [
        Expanded(
          child: _HeadlineMetric(
            key: const Key('care-adherence-adherence-rate'),
            label: loc.careHistoryAdherenceRateLabel,
            value: rateText,
          ),
        ),
        Expanded(
          child: _HeadlineMetric(
            key: const Key('care-adherence-days-with-dose'),
            label: loc.careHistoryDaysWithDoseLabel,
            value: '${summary.daysWithDose}',
          ),
        ),
        Expanded(
          child: _HeadlineMetric(
            key: const Key('care-adherence-missed-count'),
            label: loc.careHistoryMissedCountLabel,
            value: '${summary.missedCount}',
          ),
        ),
      ],
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

/// The heatmap legend: one dot per [CareDayState], each labeled with its
/// state name *and* its day count within the currently loaded period (e.g.
/// "Complete (12)") — so a sighted touch user can read each state's size
/// without long-pressing individual heatmap cells (design §B accessibility).
///
/// Excluded from semantics: it is a *visual* key (a color swatch mapped to a
/// word), and its text is word-for-word the same label+count set the heatmap
/// summary above the grid already announces — leaving both in made a screen
/// reader read every state twice. The summary is kept because it is the one
/// that comes first and carries the states that actually occurred.
class _Legend extends StatelessWidget {
  final Map<CareDayState, int> counts;

  const _Legend({required this.counts});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ExcludeSemantics(
      child: Wrap(
        key: const Key('care-adherence-legend'),
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final state in CareDayState.values)
            _LegendDot(
              state: state,
              label: loc.careAdherenceLegendWithCount(
                _dayStateLabel(loc, state),
                counts[state]!,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  /// The state this swatch previews — its color comes from the same
  /// [_dayStateColor] the heatmap cells use, never a second list, so a
  /// swatch can't drift away from the cells it counts.
  final CareDayState state;
  final String label;

  const _LegendDot({required this.state, required this.label});

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
            color: _dayStateColor(theme.colorScheme, state),
            borderRadius: BorderRadius.circular(3),
            // Same border treatment as the heatmap cells themselves, so the
            // swatch is a faithful preview of what a cell of this state
            // looks like.
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
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
