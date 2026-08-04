import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/care_history.dart';
import '../domain/care_today.dart';
import 'care_history_controller.dart';

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

/// The next longer period in the 7→30→90 progression used by the empty
/// state's "see a longer period" action (follow-up 5). Only called when
/// [spanDays] < 90.
int _nextSpanDays(int spanDays) => spanDays < 30 ? 30 : 90;

/// The care history screen (route `/care-history`): a pure record list +
/// edit screen — a 7/30/90-day period picker (design mirrors [TrendCard])
/// above a list of the period's slots grouped by day (newest first,
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
  String _idToken = '';

  /// Whether *this* instance holds a usable `_idToken`. [widget.controller]
  /// is a main.dart singleton that outlives the screen, so re-entering can
  /// start with `firstLoadSettled == true` from an earlier instance — which
  /// makes [AsyncStateScaffold] skip the full-page spinner and render the
  /// period selector / widen button on the very first frame, before this
  /// instance's own [_load] has resolved a real `_idToken` (still `''`).
  /// Gates those controls so a tap in that window can't send an
  /// unauthenticated GET and drop the user into a spurious 401 reauth exit
  /// (task 4.7).
  ///
  /// Derived from `_idToken` rather than tracked as a separate "the await
  /// finished" flag: `idToken()` resolving to `null` leaves `_idToken` empty
  /// too, and a request carrying no bearer is exactly what this gate exists
  /// to prevent — whether the token hasn't arrived yet or never will.
  bool get _tokenReady => _idToken.isNotEmpty;

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
    _idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    setState(() {});
    await _reload();
  }

  Future<void> _reload() => widget.controller.load(_idToken);

  void _setSpan(int spanDays) => widget.controller.setSpan(_idToken, spanDays);

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
      _idToken,
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
      isLoading: controller.status == CareHistoryLoadStatus.loading &&
          !controller.firstLoadSettled,
      isReauth: controller.status == CareHistoryLoadStatus.reauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        final reloading = controller.status == CareHistoryLoadStatus.loading;
        final empty = careHistoryIsEmpty(controller.days);
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
                loc.careErrorForPeriod(controller.spanDays),
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
          // `controller.spanDays` — `setSpan` writes that before awaiting
          // the reload, so reading it here mid-reload would flip the
          // wording/buttons to the just-selected, still-unconfirmed period
          // (task 4.1). Falls back to `spanDays` only before any load has
          // ever settled, which the empty state can't reach anyway.
          final displaySpanDays = controller.daysSpanDays ?? controller.spanDays;
          content = _EmptyState(
            spanDays: displaySpanDays,
            onWiden: _tokenReady && displaySpanDays < 90 && !reloading
                ? () => _setSpan(_nextSpanDays(displaySpanDays))
                : null,
            onOpenCareItems: () => context.push('/care-items'),
          );
        } else {
          content = _HistoryList(
            days: controller.days,
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
                  child: SegmentedButton<int>(
                    key: const Key('care-history-range-selector'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 7, label: Text(loc.trendRange7)),
                      ButtonSegment(value: 30, label: Text(loc.trendRange30)),
                      ButtonSegment(value: 90, label: Text(loc.trendRange90)),
                    ],
                    selected: {controller.spanDays},
                    onSelectionChanged: _tokenReady
                        ? (selection) => _setSpan(selection.first)
                        : null,
                  ),
                ),
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
    final theme = Theme.of(context);
    final atLongest = spanDays >= 90;
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
            Text(
              atLongest ? loc.careHistoryNoCareItemsTitle : loc.careHistoryEmptyTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              atLongest ? loc.careHistoryNoCareItemsBody : loc.careHistoryEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!atLongest) ...[
              FilledButton(
                key: const Key('care-history-widen-button'),
                onPressed: onWiden,
                child: Text(loc.careHistoryWidenPeriodButton),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('care-history-empty-manage-button'),
                onPressed: onOpenCareItems,
                child: Text(loc.careHistoryEmptyManageButton),
              ),
            ] else
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
    final header = isToday ? loc.dietDayToday : mediumDateLabelOrDash(context, day.date);
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
