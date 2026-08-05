import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/tracker_busy_bar.dart';
import '../domain/menstrual_period.dart';
import 'menstrual_calendar.dart';
import 'menstrual_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

/// Menstrual (period) tracker: a mini-calendar marking recorded periods and the
/// predicted next start, a cycle-statistics card, and the most recent period.
/// Not tied to any viewed day — it shows the whole history. Add/edit/delete a
/// period takes effect immediately (the controller re-reads the overview).
class MenstrualScreen extends StatefulWidget {
  final MenstrualController controller;
  final IdTokenProvider idToken;

  /// Returns the current time, used to resolve "today" for the calendar and
  /// open-period ranges. Defaults to [DateTime.now]; tests inject a fixed clock.
  final DateTime Function() clock;

  /// Invoked when the user taps the reauth state's sign-in-again control
  /// (see [AsyncStateScaffold]).
  final VoidCallback onSignInAgain;

  const MenstrualScreen({
    super.key,
    required this.controller,
    required this.idToken,
    this.clock = DateTime.now,
    required this.onSignInAgain,
  });

  @override
  State<MenstrualScreen> createState() => _MenstrualScreenState();
}

class _MenstrualScreenState extends State<MenstrualScreen> {
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

  /// True from the moment a mutation starts until it settles. Set
  /// **synchronously**, before the `await widget.idToken()` inside [action]:
  /// the controller only flips to `saving` once the token has resolved, so
  /// without this flag the controls stay enabled and silent for the whole
  /// token round trip and a second submission starts a second write.
  bool _mutating = false;

  /// Awaits [action] (a controller mutation) then, if the controller ended in
  /// an error state, surfaces a transient save-failed SnackBar. `needsReauth`
  /// routes to the reauth screen via [build] instead, so it is left alone.
  /// Re-entrant calls (a second submission while one is in flight) are dropped.
  ///
  /// Returns whether [action] actually ran. A dropped call leaves the
  /// controller untouched — and, crucially, leaves its status on `loaded`, so
  /// a caller cannot tell from the status alone that nothing happened.
  /// Callers with post-mutation work (a success message, an undo prompt) MUST
  /// bail out on `false`, or they report a write that never happened.
  Future<bool> _runMutation(Future<void> Function() action) async {
    if (_mutating) return false;
    setState(() => _mutating = true);
    try {
      await action();
      if (!mounted) return true;
      if (widget.controller.status == MenstrualStatus.error) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.menstrualSaveFailed)));
      }
      return true;
    } finally {
      _mutating = false;
      if (mounted) setState(() {});
    }
  }

  /// Deletes [period], then — on success — surfaces a SnackBar with an Undo
  /// action that re-adds it (a fresh POST; the backend assigns a new id, which
  /// is acceptable). Mirrors the exercise tracker's delete-with-undo.
  Future<void> _deletePeriod(MenstrualPeriod period) async {
    final ran = await _runMutation(
      () async => widget.controller.deletePeriod(await widget.idToken(), period.id),
    );
    // A dropped call never issued the delete, and the status is still
    // `loaded` — without this the screen would claim the period was deleted
    // and offer an Undo that would re-add a still-present period. Reachable:
    // the undo prompt is a SnackBar, which sits outside `busy` gating, so a
    // tap on it and a tap on a day cell in the SAME frame start the undo's
    // write first and then open the dialog whose delete lands mid-flight.
    if (!ran) return;
    if (!mounted) return;
    if (widget.controller.status != MenstrualStatus.loaded) return;
    _showUndoPrompt(period, AppLocalizations.of(context)!.menstrualPeriodDeleted);
  }

  /// Shows the delete-undo prompt for [period] with [message] as its text.
  ///
  /// A `SnackBarAction` latches and hides its SnackBar the instant it is
  /// pressed — before [_runMutation] can refuse — so a refused undo must put
  /// the prompt *back*, action and all, rather than replace it with a message.
  /// Replacing it leaves the period deleted with nothing left to undo it with,
  /// which is worse than the silent drop it was meant to fix.
  void _showUndoPrompt(MenstrualPeriod period, String message) {
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: loc.menstrualUndo,
          onPressed: () => _undoDelete(period),
        ),
      ),
    );
  }

  /// Re-adds a deleted [period]. Refused while another write is in flight —
  /// and a refusal re-shows the prompt (so "try again in a moment" is true of
  /// what is on screen: the Undo action is still there to try again on).
  Future<void> _undoDelete(MenstrualPeriod period) async {
    final ran = await _runMutation(
      () async => widget.controller.addPeriod(
        await widget.idToken(),
        startDate: period.startDate,
        endDate: period.endDate,
      ),
    );
    if (ran || !mounted) return;
    _showUndoPrompt(period, AppLocalizations.of(context)!.trackerStillSaving);
  }

  Future<void> _openDialog({
    MenstrualPeriod? existing,
    DateTime? initialStart,
  }) async {
    final result = await showDialog<_PeriodDialogResult>(
      context: context,
      builder: (_) => _PeriodDialog(
        existing: existing,
        initialStart: initialStart,
        today: menstrualDateOnly(widget.clock()),
      ),
    );
    if (result == null) return;

    if (result.delete) {
      if (existing != null) await _deletePeriod(existing);
      return;
    }

    if (existing == null) {
      await _runMutation(
        () async => widget.controller.addPeriod(
          await widget.idToken(),
          startDate: result.start!,
          endDate: result.end,
        ),
      );
      return;
    }

    // Edit: send only the fields that changed (partial update).
    final newStart = result.start!;
    final newEnd = result.end;
    DateTime? startArg = newStart != existing.startDate ? newStart : null;
    DateTime? endArg;
    var clearEnd = false;
    if (existing.endDate != null && newEnd == null) {
      clearEnd = true;
    } else if (newEnd != null && newEnd != existing.endDate) {
      endArg = newEnd;
    }
    if (startArg == null && endArg == null && !clearEnd) return;

    await _runMutation(
      () async => widget.controller.updatePeriod(
        await widget.idToken(),
        existing.id,
        startDate: startArg,
        endDate: endArg,
        clearEndDate: clearEnd,
      ),
    );
  }

  void _onDayTap(DateTime day) {
    final overview = widget.controller.overview;
    if (overview == null) return;
    final today = menstrualDateOnly(widget.clock());
    MenstrualPeriod? match;
    for (final period in overview.periods) {
      if (isMenstrualPeriodDay(day, [period], today)) {
        match = period;
        break;
      }
    }
    _openDialog(existing: match, initialStart: match == null ? day : null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;

    final busy =
        _mutating ||
        controller.status == MenstrualStatus.loading ||
        controller.status == MenstrualStatus.saving;

    final appBar = AppBar(title: Text(loc.menstrualTitle));

    return AsyncStateScaffold(
      isLoading: busy && controller.overview == null,
      isReauth: controller.status == MenstrualStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: widget.onSignInAgain,
      appBar: appBar,
      builder: (context) {
        if (controller.overview == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                loc.errorMenstrualLoadFailed,
                key: const Key('menstrual-error'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final overview = controller.overview!;

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Column(
              children: [
                TrackerBusyBar(
                  busy: busy,
                  indicatorKey: const Key('menstrual-busy'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      LedgeCard(
                        padding: const EdgeInsets.all(12),
                        child: MenstrualCalendar(
                          overview: overview,
                          clock: widget.clock,
                          // Gated like every other control, so a tap during a
                          // write is refused up front (alongside the busy bar)
                          // rather than opening a dialog whose save is then
                          // dropped. Two cells tapped in the SAME frame cannot
                          // stack two dialogs regardless of this gating:
                          // pushing the first dialog's route runs
                          // `Navigator._cancelActivePointers`, which cancels
                          // every other in-flight pointer and absorbs the rest
                          // of the frame's — so the second tap never fires.
                          onDayTap: busy ? null : _onDayTap,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StatsCard(overview: overview),
                      if (overview.periods.isEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          loc.menstrualEmptyHint,
                          key: const Key('menstrual-empty-hint'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('menstrual-add-button'),
                        onPressed: busy ? null : () => _openDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(loc.menstrualAddButton),
                      ),
                    ],
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

/// The cycle-statistics card: average cycle length, average period length, the
/// predicted next start, and the most recent period. Each value shows a
/// placeholder ("—") when it is null (not enough data). Colors from [Theme].
class _StatsCard extends StatelessWidget {
  final MenstrualOverview overview;

  const _StatsCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = overview.stats;
    final placeholder = loc.menstrualStatPlaceholder;

    final cycle = stats.averageCycleDays == null
        ? placeholder
        : loc.menstrualDaysValue(stats.averageCycleDays!);
    final period = stats.averagePeriodDays == null
        ? placeholder
        : loc.menstrualDaysValue(stats.averagePeriodDays!);
    final predicted = stats.predictedNextStart == null
        ? placeholder
        : mediumDateLabel(context, stats.predictedNextStart!);

    final last = overview.lastPeriod;
    final String lastText;
    if (last == null) {
      lastText = placeholder;
    } else {
      final start = mediumDateLabel(context, last.startDate);
      final end = last.endDate == null
          ? loc.menstrualOngoingLabel
          : mediumDateLabel(context, last.endDate!);
      lastText = '$start – $end';
    }

    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatRow(
            rowKey: const Key('menstrual-avg-cycle'),
            label: loc.menstrualAverageCycleLabel,
            value: cycle,
          ),
          const SizedBox(height: 8),
          _StatRow(
            rowKey: const Key('menstrual-avg-period'),
            label: loc.menstrualAveragePeriodLabel,
            value: period,
          ),
          const SizedBox(height: 8),
          _StatRow(
            rowKey: const Key('menstrual-predicted-next'),
            label: loc.menstrualPredictedNextLabel,
            value: predicted,
          ),
          const Divider(height: 24),
          // The last period is a date RANGE (long, especially localized), so it
          // gets its own full-width line below the label rather than sharing a
          // row — otherwise it truncates with an ellipsis.
          Column(
            key: const Key('menstrual-last-period'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.menstrualLastPeriodLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(lastText, style: theme.textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

/// One label/value row in the statistics card.
class _StatRow extends StatelessWidget {
  final Key rowKey;
  final String label;
  final String value;

  const _StatRow({
    required this.rowKey,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The result of the add/edit dialog: either a save (a start date and an
/// optional end date) or a delete.
class _PeriodDialogResult {
  final bool delete;
  final DateTime? start;
  final DateTime? end;

  const _PeriodDialogResult.save(this.start, this.end) : delete = false;
  const _PeriodDialogResult.delete()
    : delete = true,
      start = null,
      end = null;
}

/// The add/edit period dialog: a required start date, an optional end date
/// (clearable in edit mode to reopen a completed period), and — in edit mode —
/// a delete action. The save control is disabled until a start date is chosen
/// and the end date (if any) is not before it. Dates are date-only.
class _PeriodDialog extends StatefulWidget {
  final MenstrualPeriod? existing;
  final DateTime? initialStart;
  final DateTime today;

  const _PeriodDialog({
    required this.existing,
    required this.initialStart,
    required this.today,
  });

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.existing?.startDate ?? widget.initialStart;
    _end = widget.existing?.endDate;
  }

  bool get _endBeforeStart =>
      _start != null && _end != null && _end!.isBefore(_start!);

  bool get _canSubmit => _start != null && !_endBeforeStart;

  /// Clamps a desired [initial] date to [widget.today] so it never exceeds the
  /// picker's `lastDate` (which would trip the framework's
  /// `initialDate <= lastDate` assert when a future day was prefilled).
  DateTime _clampToToday(DateTime initial) =>
      initial.isAfter(widget.today) ? widget.today : initial;

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampToToday(_start ?? widget.today),
      firstDate: DateTime(2000),
      lastDate: widget.today,
    );
    if (picked != null) {
      setState(() => _start = menstrualDateOnly(picked));
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampToToday(_end ?? _start ?? widget.today),
      firstDate: DateTime(2000),
      lastDate: widget.today,
    );
    if (picked != null) {
      setState(() => _end = menstrualDateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(
        isEdit ? loc.menstrualEditDialogTitle : loc.menstrualAddDialogTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateField(
            fieldKey: const Key('menstrual-start-date'),
            label: loc.menstrualStartDateLabel,
            value: _start,
            placeholder: loc.menstrualSelectDate,
            onTap: _pickStart,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DateField(
                  fieldKey: const Key('menstrual-end-date'),
                  label: loc.menstrualEndDateLabel,
                  value: _end,
                  placeholder: loc.menstrualSelectDate,
                  onTap: _pickEnd,
                ),
              ),
              if (_end != null)
                IconButton(
                  key: const Key('menstrual-clear-end'),
                  tooltip: loc.menstrualClearEndDate,
                  onPressed: () => setState(() => _end = null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (_endBeforeStart) ...[
            const SizedBox(height: 8),
            Text(
              loc.menstrualEndBeforeStartError,
              key: const Key('menstrual-end-before-start-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (isEdit)
          TextButton(
            key: const Key('menstrual-delete-period'),
            onPressed: () => Navigator.of(
              context,
            ).pop(const _PeriodDialogResult.delete()),
            child: Text(loc.menstrualDeletePeriod),
          ),
        FilledButton(
          key: const Key('menstrual-save-period'),
          onPressed: _canSubmit
              ? () => Navigator.of(
                  context,
                ).pop(_PeriodDialogResult.save(_start, _end))
              : null,
          child: Text(loc.menstrualSavePeriod),
        ),
      ],
    );
  }
}
