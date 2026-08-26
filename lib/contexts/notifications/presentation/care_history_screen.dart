import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/care_history.dart';
import '../domain/care_history_filter.dart';
import '../domain/care_history_period.dart';
import '../domain/care_today.dart';
import 'care_dose_label.dart';
import 'care_history_controller.dart';
import 'care_history_filter_bar.dart';
import '../../../shared/auth/id_token_provider.dart';

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

/// The composite identity of a slot within a history range — matches the
/// fields used to build a [_SlotTile]'s [Key] — used to tell which slot (if
/// any) is the target of an in-flight edit.
String _slotCompositeKey(CareTodaySlot slot) =>
    '${slot.careScheduleId}-${slot.localDate}-${slot.timeOfDay}';

/// The two destinations offered by the AppBar's overflow menu (follow-up 9)
/// — this screen is otherwise a dead-end leaf, so it offers a way back into
/// the care context.
enum _HistoryMenuOption { todayCare, careManagement }

/// The three rolling-span options the period picker offers. Custom is a date
/// pair rather than a length, so it isn't a value here — it is the picker's
/// fourth row (see [_pickCustomRange] and [_openPeriodSheet]).
///
/// The picker is a sheet of tappable rows rather than a `SegmentedButton`:
/// that control only calls `onSelectionChanged` on a selection *change*, so
/// re-pressing the row for the period already in effect is a no-op — which
/// on the custom row would leave the user unable to adjust an
/// already-picked range at all. Every row here reopens/reapplies on tap.
enum _CareHistoryPeriodChoice { d7, d30, d90 }

/// The rolling span [period] is currently on; `null` for anything the picker
/// doesn't offer as a span — which is what puts the check mark on its custom
/// row instead.
_CareHistoryPeriodChoice? _periodChoice(CareHistoryPeriod period) =>
    switch (period.spanDays) {
      7 => _CareHistoryPeriodChoice.d7,
      30 => _CareHistoryPeriodChoice.d30,
      90 => _CareHistoryPeriodChoice.d90,
      _ => null,
    };

/// The next longer period in the 7→30→90 progression used by the empty
/// state's "see a longer period" action (follow-up 5). Only called when
/// [spanDays] < 90.
int _nextSpanDays(int spanDays) => spanDays < 30 ? 30 : 90;

/// The care history screen (route `/care-history`): a pure record list +
/// edit screen — one time-range control (7/30/90 days or a custom range,
/// picked in a sheet) above a list of the period's slots grouped by day (newest first,
/// skipping days with nothing scheduled — the backend's `days` array is
/// dense, so an empty slot list per day is normal, not an absent day);
/// tapping a slot (each tile carries a trailing edit-icon affordance) opens
/// a bottom sheet — headed with the slot's item name, date, time, and
/// current status so the record being changed is unambiguous — to set it
/// done/skipped. While that edit's PUT/refresh is in flight the tapped tile
/// swaps its edit icon for a small progress indicator and can't be tapped
/// again; once it settles a SnackBar confirms success, or — if the PUT
/// itself failed vs. only the follow-up refresh failed — one of two
/// distinct error messages (the edit is never reported as failed when it
/// actually saved). Only the very first load shows a full-page spinner; a
/// period switch keeps the previous content visible with a thin progress
/// indicator instead of blanking (design mirrors [TrendCard]). The heatmap/
/// headline chart view that used to live here as a second mode has moved to
/// the health module's trends tab (`CareAdherenceCard`).
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
  /// A fresh id token per request (see [IdTokenProvider]); the shape
  /// `FriendsScreen._token` uses. Deliberately not cached in a field — a
  /// token fetched at mount is already expired for a screen left open.
  Future<String> _idToken() => guardedIdToken(widget.authRepository);

  /// Whether *this* instance has resolved a non-empty token at least once.
  /// [widget.controller] is a main.dart singleton that outlives the screen, so
  /// re-entering can start with `firstLoadSettled == true` from an earlier
  /// instance — which makes [AsyncStateScaffold] skip the full-page spinner and
  /// render the period selector / widen button on the very first frame, before
  /// this instance's own [_load] has resolved anything. Gates those controls so
  /// a tap in that window can't send an unauthenticated GET and drop the user
  /// into a spurious 401 reauth exit (task 4.7).
  ///
  /// A flag, not a held token: a request carrying no bearer is exactly what
  /// this gate exists to prevent — whether the token hasn't arrived yet or
  /// never will — while the token each request actually sends is re-resolved
  /// by [_idToken] at that moment.
  bool _tokenReady = false;

  /// The composite key ([_slotCompositeKey]) of the slot currently being
  /// edited, so its tile can show an in-flight affordance instead of the
  /// whole screen — cleared once [CareHistoryController.edit] settles.
  String? _editingSlotKey;

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
    final idToken = await _idToken();
    if (!mounted) return;
    setState(() => _tokenReady = idToken.isNotEmpty);
    await widget.controller.load(idToken);
  }

  Future<void> _reload() async => widget.controller.load(await _idToken());

  Future<void> _setSpan(int spanDays) async =>
      widget.controller.setSpan(await _idToken(), spanDays);

  Future<void> _onPeriodChoice(_CareHistoryPeriodChoice choice) async {
    switch (choice) {
      case _CareHistoryPeriodChoice.d7:
        await _setSpan(7);
      case _CareHistoryPeriodChoice.d30:
        await _setSpan(30);
      case _CareHistoryPeriodChoice.d90:
        await _setSpan(90);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today.subtract(
      // Bounded rather than validated after the fact: `/api/care/range`
      // rejects a span wider than 366 days with a 400, and a picker that
      // can only produce acceptable ranges needs no error copy for one.
      const Duration(days: careHistoryMaxRangeDays - 1),
    );
    // The picker opens on the period already on screen — with no initial
    // range it opens a year back, at `firstDate`, which is nowhere near the
    // dates the user is looking at. But the period on screen can be a
    // *persisted* custom range from a previous day (`CareHistoryFilterStore`
    // only validates its length, not its age against "today"), so it can
    // fall outside `[firstDate, today]` by now — an out-of-bounds
    // `initialDateRange` trips `showDateRangePicker`'s own assert. Clamp
    // rather than pass it through.
    final current = widget.controller.period.resolve(now);
    var start = parseDayString(current.from);
    var end = parseDayString(current.to);
    if (start.isBefore(firstDate)) start = firstDate;
    if (end.isAfter(today)) end = today;
    final initialDateRange = start.isAfter(end)
        ? null
        : DateTimeRange(start: start, end: end);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today,
      initialDateRange: initialDateRange,
    );
    if (picked == null || !mounted) return;
    await widget.controller.setPeriod(
      await _idToken(),
      CareHistoryPeriod.custom(dayString(picked.start), dayString(picked.end)),
    );
  }

  /// The time-range picker: one row per option, exactly one of them checked.
  ///
  /// Each row pops the sheet *before* acting, so the date-range picker the
  /// custom row opens isn't stacked on top of a sheet it would outlive.
  Future<void> _openPeriodSheet() => showAppSheet<void>(
    context,
    builder: (sheetContext) {
      final loc = AppLocalizations.of(sheetContext)!;
      final period = widget.controller.period;
      final choice = _periodChoice(period);
      final theme = Theme.of(sheetContext);
      Widget selectionIcon(bool selected) => Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        key: selected ? const Key('care-history-period-option-selected') : null,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      );
      return SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                loc.careHistoryPeriodPickerTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final option in const [
              (days: 7, choice: _CareHistoryPeriodChoice.d7),
              (days: 30, choice: _CareHistoryPeriodChoice.d30),
              (days: 90, choice: _CareHistoryPeriodChoice.d90),
            ])
              ListTile(
                key: Key('care-history-period-option-${option.days}'),
                selected: choice == option.choice,
                leading: selectionIcon(choice == option.choice),
                title: Text(loc.careHistoryPeriodSpanLabel(option.days)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _onPeriodChoice(option.choice);
                },
              ),
            ListTile(
              key: const Key('care-history-period-option-custom'),
              selected: choice == null,
              leading: selectionIcon(choice == null),
              title: Text(loc.careHistoryPeriodCustom),
              subtitle: switch (period) {
                CareHistoryCustomPeriod(:final from, :final to) => Text(
                  loc.careHistoryPeriodCustomLabel(
                    monthDayLabel(sheetContext, parseDayString(from)),
                    monthDayLabel(sheetContext, parseDayString(to)),
                  ),
                ),
                CareHistorySpanPeriod() => null,
              },
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCustomRange();
              },
            ),
          ],
        ),
      );
    },
  );

  Future<void> _openFilterSheet() => showCareHistoryFilterSheet(
    context,
    filter: widget.controller.filter,
    itemOptions: careHistoryItemOptions(widget.controller.days),
    onChanged: widget.controller.setFilter,
  );

  Future<void> _openEditSheet(CareTodaySlot slot) async {
    // Guards against opening a second sheet while an edit is already in
    // flight. This alone isn't enough for a fast double-tap (see the
    // re-check after the sheet's await below), but it still avoids
    // needlessly opening a sheet whose choice would just be dropped.
    if (widget.controller.editing) return;
    final loc = AppLocalizations.of(context)!;
    final dateLabel = mediumDateLabelOrDash(context, slot.localDate);
    final chosen = await showModalBottomSheet<CareLogStatus>(
      context: context,
      // Not `showAppSheet`, in two respects: this short status picker is
      // deliberately left un-scroll-controlled (it stays capped at 9/16 of
      // the screen instead of growing full-height), and it wraps its own
      // `SafeArea` below rather than taking `useSafeArea`. It does keep the
      // drag handle, for the reason `showAppSheet`'s doc gives, and here it
      // is load-bearing: this picker's content is options only, with no
      // Cancel button, so the handle is the only dismiss affordance inside
      // the sheet's own semantics.
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  loc.careHistoryEditSheetTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  slot.title,
                  key: const Key('care-history-edit-sheet-title'),
                ),
                subtitle: Text(
                  '$dateLabel ${slot.timeOfDay} · ${_statusLabel(loc, slot.status)}',
                  key: const Key('care-history-edit-sheet-subtitle'),
                ),
              ),
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
                onTap: () =>
                    Navigator.of(sheetContext).pop(CareLogStatus.skipped),
              ),
            ],
          ),
        );
      },
    );
    // The screen (or its ancestor) can be disposed while the sheet is open
    // — e.g. sign-out flipping the app to the login screen, or the route
    // being popped — so `context`/`setState` below must not be touched
    // without checking first.
    if (!mounted) return;
    if (chosen == null) return;
    // Re-check re-entrancy *after* the sheet's await: the check at the top
    // of this method only guards against opening a second sheet while an
    // edit is already in flight, but a fast double-tap can open two sheets
    // before either one reaches that point. Re-checking here means the
    // second sheet's choice is dropped right here (visibly consistent with
    // the guard above) rather than silently swallowed by the controller's
    // own re-entrancy guard after already flipping `_editingSlotKey`.
    if (widget.controller.editing) return;
    setState(() => _editingSlotKey = _slotCompositeKey(slot));
    // The outcome comes back as a return value, never from the controller's
    // `editError`/`refreshError` fields after the await: a concurrent load
    // (the user tapping the period selector) clears those by design, and a
    // later edit clears them on entry — so reading them here could report a
    // *failed* PUT as saved. The returned value is this call's own snapshot.
    final outcome = await widget.controller.edit(
      await _idToken(),
      careScheduleId: slot.careScheduleId,
      localDate: slot.localDate,
      timeOfDay: slot.timeOfDay,
      status: chosen,
    );
    if (!mounted) return;
    setState(() => _editingSlotKey = null);
    final loc2 = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final message = switch (outcome) {
      CareEditOutcome.editFailed => loc2.careErrorGeneric,
      CareEditOutcome.refreshFailed => loc2.careHistoryEditRefreshErrorMessage,
      CareEditOutcome.saved => loc2.careHistoryEditSuccessMessage,
      // The screen shows its own re-auth exit; a dropped call did nothing.
      CareEditOutcome.reauth || CareEditOutcome.skipped => null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final appBar = AppBar(
      title: Text(loc.careHistoryTitle),
      actions: [
        PopupMenuButton<_HistoryMenuOption>(
          key: const Key('care-history-menu'),
          onSelected: (option) => switch (option) {
            _HistoryMenuOption.todayCare => context.push('/care-today'),
            _HistoryMenuOption.careManagement => context.push('/care-items'),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              key: const Key('care-history-menu-today'),
              value: _HistoryMenuOption.todayCare,
              child: Text(loc.careTodayTitle),
            ),
            PopupMenuItem(
              key: const Key('care-history-menu-items'),
              value: _HistoryMenuOption.careManagement,
              child: Text(loc.careRemindersTitle),
            ),
          ],
        ),
      ],
    );

    return AsyncStateScaffold(
      // Only a load that has never had content gets the full-page spinner.
      // Not `days.isEmpty`: a failed first load leaves days empty too, so
      // retrying (or switching period) from the error state would drop back
      // to a spinner that has no period selector — the very control this
      // screen keeps on screen so a failing period isn't a dead end.
      isLoading:
          controller.status == CareHistoryLoadStatus.loading &&
          !controller.firstLoadSettled,
      isReauth: controller.status == CareHistoryLoadStatus.reauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: () => unawaited(widget.authRepository.signOut()),
      appBar: appBar,
      builder: (context) {
        final reloading = controller.status == CareHistoryLoadStatus.loading;
        // The list, the summary and the empty states all read this one
        // value, so the three can never describe different sets of records.
        final filteredDays = controller.filteredDays;
        final empty = careHistoryIsEmpty(controller.days);
        // The period does hold records; the active filter is what emptied
        // it. A different state, because widening the period can't bring
        // filtered-out records back — only clearing the filter can.
        final filteredEmpty = !empty && careHistoryIsEmpty(filteredDays);
        final todayDate = dayString(widget.clock());

        final Widget content;
        if (controller.status == CareHistoryLoadStatus.error) {
          // The error replaces the list, not the whole screen: the period
          // selector has to stay reachable so a period that fails
          // (typically the slowest, 90 days) isn't a dead end. Retry alone
          // can only re-issue the same failing request, and the controller
          // — holding spanDays — is a main.dart singleton that outlives
          // this screen, so leaving and coming back would return to the
          // same failing period. Mirrors CareAdherenceCard's error state.
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadErrorText(context, loc, controller.period),
                key: const Key('care-history-load-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('care-history-retry-button'),
                onPressed: _reload,
                child: Text(loc.retry),
              ),
            ],
          );
        } else if (empty) {
          // The period the *displayed* (settled) content describes, not
          // `controller.period` — `setPeriod` writes that before awaiting
          // the reload, so reading it here mid-reload would flip the
          // wording/buttons to the just-selected, still-unconfirmed period
          // (task 4.1). Falls back to the selected period only before any
          // load has ever settled, which the empty state can't reach anyway.
          final displaySpanDays =
              (controller.daysPeriod ?? controller.period).lengthInDays;
          content = _EmptyState(
            spanDays: displaySpanDays,
            onWiden: _tokenReady && displaySpanDays < 90 && !reloading
                ? () => _setSpan(_nextSpanDays(displaySpanDays))
                : null,
            onOpenCareItems: () => context.push('/care-items'),
          );
        } else if (filteredEmpty) {
          content = _FilteredEmptyState(
            onClearFilter: () =>
                controller.setFilter(const CareHistoryFilter()),
          );
        } else {
          content = _HistoryList(
            days: filteredDays,
            todayDate: todayDate,
            onTapSlot: _openEditSheet,
            inFlightSlotKey: controller.editing ? _editingSlotKey : null,
          );
        }

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
                  child: Row(
                    children: [
                      // Expanded + Align rather than Flexible + Spacer: the
                      // button takes only the width its label needs (up to
                      // what is left beside the filter button) while the
                      // filter button still sits at the row's end. Two
                      // flexible children would split the free space and
                      // squeeze this one to half a row.
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Tooltip(
                            // At 320dp × textScale 2.0 the widest possible
                            // label (an actual custom date range) does not
                            // fit next to the filter button — the button's
                            // own text ellipsizes rather than overflowing
                            // the row, and the tooltip carries the full
                            // range for anyone who needs it.
                            message: _periodButtonLabel(
                              context,
                              loc,
                              controller.period,
                            ),
                            child: OutlinedButton.icon(
                              key: const Key('care-history-period-button'),
                              onPressed: _tokenReady ? _openPeriodSheet : null,
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.arrow_drop_down),
                              label: Text(
                                _periodButtonLabel(
                                  context,
                                  loc,
                                  controller.period,
                                ),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                      CareHistoryFilterButton(
                        filter: controller.filter,
                        // Purely client-side, so unlike the period control
                        // it needs no token — but an empty range has nothing
                        // to filter and no options to offer.
                        onPressed: empty ? null : _openFilterSheet,
                      ),
                    ],
                  ),
                ),
                CareHistoryAppliedFilters(
                  filter: controller.filter,
                  itemOptions: careHistoryItemOptions(controller.days),
                  onChanged: controller.setFilter,
                ),
                if (!empty && controller.status != CareHistoryLoadStatus.error)
                  _SummaryRow(summary: careHistorySummary(filteredDays)),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: content,
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

/// The period button's label: the period actually in effect, since it is now
/// the only thing on screen saying which one that is. A rolling span names
/// its length ("Last 30 days", not the bare "30 days" the trend cards use
/// beside a heading), a custom period names its dates.
String _periodButtonLabel(
  BuildContext context,
  AppLocalizations loc,
  CareHistoryPeriod period,
) => switch (period) {
  CareHistorySpanPeriod(:final days) => loc.careHistoryPeriodSpanLabel(days),
  CareHistoryCustomPeriod(:final from, :final to) =>
    loc.careHistoryPeriodCustomLabel(
      monthDayLabel(context, parseDayString(from)),
      monthDayLabel(context, parseDayString(to)),
    ),
};

/// The load-failure message for [period]. A custom range has no length to
/// name, so it names its dates instead — `careErrorForPeriod` would have to
/// invent a day count for it.
String _loadErrorText(
  BuildContext context,
  AppLocalizations loc,
  CareHistoryPeriod period,
) => switch (period) {
  CareHistorySpanPeriod(:final days) => loc.careErrorForPeriod(days),
  CareHistoryCustomPeriod(:final from, :final to) =>
    loc.careHistoryErrorForCustomRange(
      mediumDateLabelOrDash(context, from),
      mediumDateLabelOrDash(context, to),
    ),
};

/// The headline numbers for what is currently on screen — derived from the
/// *filtered* days, so they answer "how did the records I am looking at go",
/// not "how did the whole period go".
class _SummaryRow extends StatelessWidget {
  final CareHistorySummary summary;

  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final rate = summary.adherenceRate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      // Wrapped, not a three-column Row: at 320dp with a large text scale
      // three columns clip their labels, and a Wrap re-flows instead.
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          _SummaryMetric(
            metricKey: const Key('care-history-summary-rate'),
            label: loc.careHistoryAdherenceRateLabel,
            value: rate == null ? '—' : '${(rate * 100).round()}%',
          ),
          _SummaryMetric(
            metricKey: const Key('care-history-summary-days-with-dose'),
            label: loc.careHistoryDaysWithDoseLabel,
            value: '${summary.daysWithDose}',
          ),
          _SummaryMetric(
            metricKey: const Key('care-history-summary-missed-count'),
            label: loc.careHistoryMissedCountLabel,
            value: '${summary.missedCount}',
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final Key metricKey;
  final String label;
  final String value;

  const _SummaryMetric({
    required this.metricKey,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Value first and dominant, label second and quiet: the two used to be
    // the same size in reading order label→value, which across three
    // metrics read as one run-on sentence. The number is what is being
    // looked up, so it leads, bigger and heavier than the word naming it.
    //
    // Two measured limits shape this, both at 320dp × textScale 2.0 (the
    // narrow-screen guards in `care_history_screen_test.dart`):
    //
    // - Still *one line* per metric. Stacking the value above its label
    //   costs one extra text line per metric, and three of them take the
    //   record list — the thing this screen exists to show — from 208dp
    //   down to 40dp.
    // - `titleMedium`, not `titleLarge`. The value sits before the label on
    //   the same line, so every point it grows is a point the label loses:
    //   at `titleLarge` the labels wrap one line deeper and the list falls
    //   to 176dp, under the 200dp floor that guard has held since the
    //   filter row landed.
    return Row(
      key: metricKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        // Flexible, not a bare Text: inside the Wrap each metric is offered
        // the full row width, and at 320dp with a large text scale a label
        // like "Days with care done" is wider than that — it has to wrap
        // rather than overflow.
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The empty state for a period that *does* hold records, all of them
/// filtered out. Offers only clearing the filter — deliberately not the
/// widen-period action of [_EmptyState], which would send the user after
/// records that are already in range.
class _FilteredEmptyState extends StatelessWidget {
  final VoidCallback onClearFilter;

  const _FilteredEmptyState({required this.onClearFilter});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LedgeCard(
        padding: const EdgeInsets.all(20),
        child: EmptyStateGuide(
          stateKey: const Key('care-history-filtered-empty-state'),
          icon: Icons.filter_list_off,
          title: loc.careHistoryFilteredEmptyTitle,
          body: loc.careHistoryFilteredEmptyBody,
          actions: [
            FilledButton(
              key: const Key('care-history-clear-filter-button'),
              onPressed: onClearFilter,
              child: Text(loc.careHistoryFilterClearButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  /// The period the displayed (settled) content actually describes — decides
  /// both the wording (task 4.1: 90 days reads as "no care items", shorter
  /// periods read as "nothing scheduled") and whether widening is offered at
  /// all (only below 90).
  final int spanDays;

  /// Widens the period to the next longer option (7→30→90) and reloads
  /// (follow-up 5); `null` either because [spanDays] is already 90 (widening
  /// isn't rendered at all then) or because the widen it triggered is still
  /// reloading — so the button stays visible but disabled, and a fast
  /// double-tap can't skip a period (task 4.1).
  final VoidCallback? onWiden;

  /// Opens care management (`/care-items`) — offered alongside [onWiden]
  /// at every period length (task 4.1: a user with no care items at all
  /// shouldn't have to widen twice to reach the only action that helps
  /// them), and alone once the period is already the longest one.
  final VoidCallback onOpenCareItems;

  const _EmptyState({
    required this.spanDays,
    this.onWiden,
    required this.onOpenCareItems,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final atLongest = spanDays >= 90;
    // Tier 1: the record list is the screen, and every day in the period is
    // empty. Two actions below 90 days — the case that made the shared guide
    // take a *list* of actions rather than one slot.
    //
    // Its box is bounded (`Expanded` > `Center` > `ConstrainedBox` at the
    // call site) so, unlike the `ListView`-child guides, an overflow here
    // does throw — hence the scroll view, and hence the narrow-screen guard
    // in this screen's tests.
    return SingleChildScrollView(
      // Keyed so the narrow-screen guard can scroll *this* view: the screen
      // has more than one scrollable now (the period selector scrolls
      // horizontally), and `scrollUntilVisible` refuses to guess.
      key: const Key('care-history-empty-scroll'),
      padding: const EdgeInsets.all(20),
      child: LedgeCard(
        padding: const EdgeInsets.all(20),
        child: EmptyStateGuide(
          stateKey: const Key('care-history-empty-state'),
          icon: Icons.event_note_outlined,
          title: atLongest
              ? loc.careHistoryNoCareItemsTitle
              : loc.careHistoryEmptyTitle,
          body: atLongest
              ? loc.careHistoryNoCareItemsBody
              : loc.careHistoryEmptyBody,
          actions: [
            if (!atLongest)
              FilledButton(
                key: const Key('care-history-widen-button'),
                onPressed: onWiden,
                child: Text(loc.careHistoryWidenPeriodButton),
              ),
            if (!atLongest)
              OutlinedButton(
                key: const Key('care-history-empty-manage-button'),
                onPressed: onOpenCareItems,
                child: Text(loc.careHistoryEmptyManageButton),
              )
            else
              FilledButton(
                key: const Key('care-history-empty-manage-button'),
                onPressed: onOpenCareItems,
                child: Text(loc.careHistoryEmptyManageButton),
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

  /// The [_slotCompositeKey] of the slot with an edit PUT/refresh in
  /// flight, if any — passed down so only that one tile shows the
  /// in-flight affordance.
  final String? inFlightSlotKey;

  const _HistoryList({
    required this.days,
    required this.todayDate,
    required this.onTapSlot,
    this.inFlightSlotKey,
  });

  @override
  Widget build(BuildContext context) {
    final visibleDays = days.where((d) => d.slots.isNotEmpty).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ListView.builder(
      key: const Key('care-history-list'),
      padding: const EdgeInsets.all(20),
      itemCount: visibleDays.length,
      itemBuilder: (context, index) {
        final day = visibleDays[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DayCard(
            day: day,
            isToday: day.date == todayDate,
            onTapSlot: onTapSlot,
            inFlightSlotKey: inFlightSlotKey,
          ),
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  final CareHistoryDay day;
  final bool isToday;
  final ValueChanged<CareTodaySlot> onTapSlot;
  final String? inFlightSlotKey;

  const _DayCard({
    required this.day,
    required this.isToday,
    required this.onTapSlot,
    this.inFlightSlotKey,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final header = isToday
        ? loc.dietDayToday
        : mediumDateLabelOrDash(context, day.date);
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
            _SlotTile(
              slot: slot,
              onTap: () => onTapSlot(slot),
              isEditing: inFlightSlotKey == _slotCompositeKey(slot),
              // Only today's slots are editable (design §D) — corrections
              // for earlier days belong on the Today care checklist instead.
              editable: isToday,
            ),
          // Says *why* an earlier day's rows have no edit icon and do
          // nothing when tapped. Without it the restriction is only
          // discoverable by tapping and getting no response — and since the
          // Today checklist only lists today, there is no other screen left
          // that could correct an earlier day.
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                loc.careHistoryPastReadOnlyHint,
                key: Key('care-history-read-only-hint-${day.date}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final CareTodaySlot slot;
  final VoidCallback onTap;

  /// Whether this slot's edit PUT/refresh is currently in flight — shows a
  /// small progress affordance in place of the edit icon and disables the
  /// tile so a second tap can't re-open the sheet mid-edit.
  final bool isEditing;

  /// Whether this slot can be corrected here (design §D — only today's
  /// slots; earlier days are read-only, since corrections for them belong on
  /// the Today care checklist). `false` hides the edit icon entirely and
  /// makes the tile untappable, rather than opening a sheet that would do
  /// nothing.
  final bool editable;

  const _SlotTile({
    required this.slot,
    required this.onTap,
    this.isEditing = false,
    required this.editable,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final doseLabel = careDoseLabel(
      loc,
      slot.category,
      slot.doseQuantity,
      slot.dose,
    );
    final statusLine = '${slot.timeOfDay} · ${_statusLabel(loc, slot.status)}';
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
      subtitle: doseLabel.isEmpty
          ? Text(statusLine)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(statusLine),
                Semantics(
                  label: loc.careDoseSemanticLabel(doseLabel),
                  child: ExcludeSemantics(child: Text(doseLabel)),
                ),
              ],
            ),
      trailing: !editable
          ? null
          : isEditing
          ? SizedBox(
              key: Key(
                'care-history-slot-editing-${slot.careScheduleId}-${slot.localDate}-${slot.timeOfDay}',
              ),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Icon(
              Icons.edit_outlined,
              size: 20,
              semanticLabel: loc.careEditActionLabel,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      onTap: !editable || isEditing ? null : onTap,
    );
  }
}
