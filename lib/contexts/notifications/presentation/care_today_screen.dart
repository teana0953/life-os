import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/mascot.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';
import 'care_today_controller.dart';

/// Converts a slot's (UTC) `doneTime` to local before formatting as `HH:mm`
/// — the default [CareTodayScreen.toLocalTime]. Overridden in tests so the
/// conversion can be verified deterministically regardless of the host
/// machine's timezone (mirrors `today_screen.dart`'s `_defaultToLocal`).
DateTime _defaultToLocal(DateTime dt) => dt.toLocal();

/// Parses a slot's `timeOfDay` ("HH:mm") into a [TimeOfDay] — used to seed
/// the completion-time picker when a slot has no recorded `doneTime` yet.
/// A private copy, matching the same parsing already duplicated privately in
/// `care_item_form.dart`/`vitals_screen.dart`/`trend_card.dart` (design §C —
/// not worth a cross-file refactor for a single new use site).
TimeOfDay _parseTimeOfDayString(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Combines the *slot's own* local date (design §C — never "today", so a
/// correction made either side of midnight lands on the right day) with
/// [time], as the UTC instant to send as `done_time`.
DateTime _doneInstantOn(String localDate, TimeOfDay time) {
  final date = parseDayString(localDate);
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc();
}

/// The completion time [_EditSheet] opens with: the slot's recorded
/// `doneTime` if it has a parseable one, else its *scheduled* time on its own
/// local date. The fallback is not cosmetic — a `missed` slot has no
/// `doneTime`, and `/care-history`'s past rows are read-only, so this sheet is
/// the main back-fill entry point (design §D). Leaving it unset while the row
/// still displayed `slot.timeOfDay` meant submitting `done_time: null`, which
/// the backend reads as "leave this field alone": the time the user was shown
/// was never written. What is displayed is now what is sent.
DateTime _initialDoneTime(CareTodaySlot slot) {
  final recorded = slot.doneTime == null ? null : parseInstant(slot.doneTime!);
  return recorded ??
      _doneInstantOn(slot.localDate, _parseTimeOfDayString(slot.timeOfDay));
}

/// Picks a new completion time for [slot], returning the UTC [DateTime] to
/// send (or `null` if the user cancels) — the default
/// [CareTodayScreen.pickDoneTime]. The picker is seeded from [current] (the
/// instant the sheet currently holds, converted via [toLocalTime]) rather
/// than from the slot, so re-opening it after a pick starts from what the
/// user just chose instead of snapping back to the stored value; the picked
/// time is combined with the slot's own local date via [_doneInstantOn].
/// Overridden in tests to bypass the real time picker entirely.
Future<DateTime?> _defaultPickDoneTime(
  BuildContext context,
  CareTodaySlot slot,
  DateTime current,
  DateTime Function(DateTime) toLocalTime,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(toLocalTime(current)),
    // Always 24h, regardless of locale — mirrors `care_item_form.dart`, and
    // required here because both the row and the sheet render the time with
    // `DateFormat('HH:mm')`: a 12-hour picker would have an English-locale
    // user choose "9:30 PM" and then read it back as "21:30".
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (picked == null) return null;
  return _doneInstantOn(slot.localDate, picked);
}

String _categoryLabel(AppLocalizations loc, CareCategory category) =>
    switch (category) {
      CareCategory.medication => loc.careCategoryMedication,
      CareCategory.rehab => loc.careCategoryRehab,
      CareCategory.radiotherapyCare => loc.careCategoryRadiotherapyCare,
      CareCategory.custom => loc.careCategoryCustom,
    };

IconData _categoryIcon(CareCategory category) => switch (category) {
  CareCategory.medication => Icons.medication_outlined,
  CareCategory.rehab => Icons.fitness_center,
  CareCategory.radiotherapyCare => Icons.healing,
  CareCategory.custom => Icons.category_outlined,
};

/// The Done-group row icon, distinguishing a deliberate skip from a never-
/// acted miss (FIX 5) rather than showing the same category icon for both.
IconData _doneRowIcon(CareTodaySlot slot) => switch (slot.status) {
  CareTodayStatus.done => Icons.check_circle_outline,
  CareTodayStatus.skipped => Icons.remove_circle_outline,
  CareTodayStatus.missed => Icons.error_outline,
  _ => _categoryIcon(slot.category),
};

/// The Done-group row subtitle: done shows its recorded time — converted to
/// local via [toLocalTime] (issue #90 point 4: the backend sends a UTC
/// instant, so without this conversion the row would show e.g. "04:58"
/// instead of the viewer's local "12:58") — falling back to the slot's
/// scheduled time when there is no `doneTime` or it can't be parsed;
/// skipped/missed show the slot's time plus a status word so the two aren't
/// visually identical (FIX 5 — previously both were bare strikethrough text
/// with no way to tell a deliberate skip from a miss).
String _doneRowSubtitle(
  AppLocalizations loc,
  CareTodaySlot slot,
  DateTime Function(DateTime) toLocalTime,
) {
  switch (slot.status) {
    case CareTodayStatus.done:
      final raw = slot.doneTime;
      final parsed = raw == null ? null : parseInstant(raw);
      if (parsed == null) return slot.timeOfDay;
      return loc.careTodayDoneAtLabel(
        DateFormat('HH:mm').format(toLocalTime(parsed)),
      );
    case CareTodayStatus.skipped:
      return '${slot.timeOfDay} · ${loc.careTodayStatusSkipped}';
    case CareTodayStatus.missed:
      return '${slot.timeOfDay} · ${loc.careTodayStatusMissed}';
    default:
      return slot.timeOfDay;
  }
}

/// The Today care checklist: a focus card for the most-urgent slot (earliest
/// overdue, else earliest pending), then Overdue / Later / collapsible Done
/// groups, or an all-done celebration when nothing is pending/overdue, or an
/// empty-state guide when there are no schedules today (design D3). Inline
/// Done/Skip on pending/overdue rows POST then quietly reload (design D2 —
/// the list stays visible throughout; only the acted-on row disables/spins,
/// via [CareTodayController.markingAction], rather than dropping to a
/// full-screen spinner). A mark failure shows a SnackBar (with a Retry
/// action) and keeps the list.
class CareTodayScreen extends StatefulWidget {
  final CareTodayController controller;
  final AuthRepository authRepository;

  /// Opens the care reminders management screen (Slice-D) — offered from the
  /// empty state so a user with no schedules today can add one.
  final VoidCallback onOpenCareItems;

  /// Converts a slot's (UTC) `doneTime` to local before formatting as
  /// `HH:mm`. Defaults to [DateTime.toLocal]; injectable so tests can verify
  /// the conversion deterministically regardless of the host machine's
  /// timezone (mirrors `TodayScreen.toLocalTime`).
  final DateTime Function(DateTime) toLocalTime;

  /// Picks a new completion time for a Done-group slot, seeded from the
  /// instant the sheet currently holds, and returning the UTC [DateTime] to
  /// send (or `null` if the user cancels). Defaults to a real
  /// [showTimePicker] combined with [toLocalTime]; tests inject a fake that
  /// returns a fixed time directly, bypassing the real picker UI.
  final Future<DateTime?> Function(
    BuildContext context,
    CareTodaySlot slot,
    DateTime current,
    DateTime Function(DateTime) toLocalTime,
  )
  pickDoneTime;

  const CareTodayScreen({
    super.key,
    required this.controller,
    required this.authRepository,
    required this.onOpenCareItems,
    this.toLocalTime = _defaultToLocal,
    this.pickDoneTime = _defaultPickDoneTime,
  });

  @override
  State<CareTodayScreen> createState() => _CareTodayScreenState();
}

class _CareTodayScreenState extends State<CareTodayScreen> {
  String _idToken = '';

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
    await widget.controller.load(_idToken);
  }

  Future<void> _mark(
    CareTodaySlot slot,
    Future<void> Function(
      String idToken, {
      required String careScheduleId,
      required String localDate,
      required String timeOfDay,
    })
    action,
  ) async {
    await action(
      _idToken,
      careScheduleId: slot.careScheduleId,
      localDate: slot.localDate,
      timeOfDay: slot.timeOfDay,
    );
    if (!mounted) return;
    if (widget.controller.markError != null) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.careErrorGeneric),
          action: SnackBarAction(
            label: loc.retry,
            onPressed: () => _mark(slot, action),
          ),
        ),
      );
    }
  }

  Future<void> _markDone(CareTodaySlot slot) =>
      _mark(slot, widget.controller.markDone);

  Future<void> _markSkipped(CareTodaySlot slot) =>
      _mark(slot, widget.controller.markSkipped);

  /// Opens the Done-group correction sheet for [slot], then applies the
  /// chosen outcome via [CareTodayController.edit] (design §B). Gated
  /// against re-entrancy both before opening the sheet and again after its
  /// `await` — a fast double-tap can open two sheets before either reaches
  /// the first gate — and the message shown afterwards always comes from the
  /// returned [CareTodayEditOutcome], never from re-reading the controller's
  /// mutable fields (which a concurrent load/edit can clear out from under
  /// this call).
  Future<void> _openEditSheet(CareTodaySlot slot) async {
    if (widget.controller.marking) return;
    final result = await showModalBottomSheet<_EditSheetResult>(
      context: context,
      // Without `isScrollControlled` the sheet is capped at 9/16 of the
      // screen height — 360dp on a 640dp-tall phone, less than this sheet's
      // natural height, which clipped the submit button clean off the bottom.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _EditSheet(
        slot: slot,
        toLocalTime: widget.toLocalTime,
        pickDoneTime: widget.pickDoneTime,
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    if (widget.controller.marking) {
      // Dropped right here, consistent with the guard above, rather than
      // silently swallowed by the controller's own re-entrancy guard — but
      // still not silent to the user (design §B point 3).
      _showEditOutcomeMessage(CareTodayEditOutcome.skipped);
      return;
    }
    final outcome = await widget.controller.edit(
      _idToken,
      careScheduleId: slot.careScheduleId,
      localDate: slot.localDate,
      timeOfDay: slot.timeOfDay,
      status: result.status,
      doneTime: result.doneTime,
    );
    if (!mounted) return;
    _showEditOutcomeMessage(outcome);
  }

  void _showEditOutcomeMessage(CareTodayEditOutcome outcome) {
    final loc = AppLocalizations.of(context)!;
    final message = switch (outcome) {
      // The PUT never landed, or was dropped before it was attempted —
      // either way nothing was written, so "try again" is the truth.
      CareTodayEditOutcome.failed ||
      CareTodayEditOutcome.skipped => loc.careErrorGeneric,
      // Saved; only the list is stale. Reusing `/care-history`'s existing
      // copy rather than adding a duplicate string.
      CareTodayEditOutcome.refreshFailed =>
        loc.careHistoryEditRefreshErrorMessage,
      // A reauth outcome shows its own full-screen exit; a saved edit is
      // already reflected by the quiet reload — neither needs a SnackBar.
      CareTodayEditOutcome.reauth || CareTodayEditOutcome.saved => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final appBar = AppBar(
      title: Text(loc.careTodayTitle),
      actions: [
        IconButton(
          key: const Key('care-today-history-button'),
          tooltip: loc.careHistoryEntryTooltip,
          onPressed: () => context.push('/care-history'),
          icon: const Icon(Icons.history),
        ),
      ],
    );

    return AsyncStateScaffold(
      isLoading: controller.status == CareTodayLoadStatus.loading,
      isReauth: controller.status == CareTodayLoadStatus.reauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        if (controller.status == CareTodayLoadStatus.error) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.careErrorGeneric,
                    key: const Key('care-today-load-error'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('care-today-retry-button'),
                    onPressed: () => controller.load(_idToken),
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final focus = controller.focusSlot;
        final groups = controller.groups;

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      mediumDateLabel(context, parseDayString(controller.date)),
                      key: const Key('care-today-date'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (controller.slots.isEmpty)
                      _EmptyState(onAdd: widget.onOpenCareItems)
                    else ...[
                      if (focus != null)
                        _FocusCard(
                          slot: focus,
                          marking: controller.marking,
                          markingAction: controller.markingAction(focus),
                          onDone: () => _markDone(focus),
                          onSkip: () => _markSkipped(focus),
                        )
                      else
                        const _CelebrationCard(),
                      if (groups.overdue.isNotEmpty)
                        _SlotGroup(
                          titleKey: const Key('care-today-overdue-section'),
                          title: loc.careTodayOverdueSection,
                          slots: groups.overdue,
                          marking: controller.marking,
                          markingAction: controller.markingAction,
                          onDone: _markDone,
                          onSkip: _markSkipped,
                        ),
                      if (groups.later.isNotEmpty)
                        _SlotGroup(
                          titleKey: const Key('care-today-later-section'),
                          title: loc.careTodayLaterSection,
                          slots: groups.later,
                          marking: controller.marking,
                          markingAction: controller.markingAction,
                          onDone: _markDone,
                          onSkip: _markSkipped,
                        ),
                      if (groups.done.isNotEmpty)
                        _DoneGroup(
                          slots: groups.done,
                          toLocalTime: widget.toLocalTime,
                          marking: controller.marking,
                          markingAction: controller.markingAction,
                          onEdit: _openEditSheet,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusCard extends StatelessWidget {
  final CareTodaySlot slot;

  /// Whether *any* mark/edit is in flight — see [_SlotRow.marking].
  final bool marking;

  /// The action ([CareLogStatus.done]/[CareLogStatus.skipped]) currently in
  /// flight for [slot], or `null` if it isn't the one being acted on (FIX
  /// 8) — decides which button shows the spinner, while [marking] decides
  /// whether they are enabled at all.
  final CareLogStatus? markingAction;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _FocusCard({
    required this.slot,
    required this.marking,
    required this.markingAction,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isOverdue = slot.status == CareTodayStatus.overdue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          key: const Key('care-today-focus-card'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _categoryIcon(slot.category),
                  color: isOverdue ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(slot.title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isOverdue
                  ? '${slot.timeOfDay} · ${loc.careTodayOverdueSection}'
                  : '${slot.timeOfDay} · ${loc.careTodayUpNext}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isOverdue
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(_categoryLabel(loc, slot.category)),
            if (slot.note != null && slot.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(slot.note!),
              ),
            if (slot.dose != null && slot.dose!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(slot.dose!),
              ),
            const SizedBox(height: 16),
            // OverflowBar, not a plain Row (FIX 9) — stacks the two buttons
            // vertically instead of overflowing when the card is too narrow
            // for both side by side.
            OverflowBar(
              spacing: 12,
              overflowSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('care-today-focus-done'),
                  onPressed: marking ? null : onDone,
                  child: markingAction == CareLogStatus.done
                      ? const _ButtonSpinner()
                      : Text(loc.careTodayMarkDoneButton),
                ),
                OutlinedButton(
                  key: const Key('care-today-focus-skip'),
                  onPressed: marking ? null : onSkip,
                  child: markingAction == CareLogStatus.skipped
                      ? const _ButtonSpinner()
                      : Text(loc.careTodaySkipButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small inline spinner sized to sit inside a [FilledButton]/
/// [OutlinedButton] in place of its label while that button's action is in
/// flight (FIX 8).
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 16,
    width: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          key: const Key('care-today-celebration'),
          children: [
            const Mascot(size: 64),
            const SizedBox(height: 12),
            Text(
              loc.careTodayCelebrationTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              loc.careTodayCelebrationBody,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        key: const Key('care-today-empty-state'),
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(loc.careTodayEmptyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            loc.careTodayEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('care-today-empty-manage-button'),
            onPressed: onAdd,
            child: Text(loc.careRemindersAddButton),
          ),
        ],
      ),
    );
  }
}

class _SlotGroup extends StatelessWidget {
  final Key titleKey;
  final String title;
  final List<CareTodaySlot> slots;

  /// Whether *any* mark/edit is in flight — see [_SlotRow.marking].
  final bool marking;

  /// Per-slot marking lookup (FIX 8) — see [_FocusCard.markingAction].
  final CareLogStatus? Function(CareTodaySlot slot) markingAction;
  final ValueChanged<CareTodaySlot> onDone;
  final ValueChanged<CareTodaySlot> onSkip;

  const _SlotGroup({
    required this.titleKey,
    required this.title,
    required this.slots,
    required this.marking,
    required this.markingAction,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, key: titleKey, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final slot in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SlotRow(
                slot: slot,
                marking: marking,
                markingAction: markingAction(slot),
                onDone: () => onDone(slot),
                onSkip: () => onSkip(slot),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single Overdue/Later row: icon + title/time above, Done/Skip actions
/// below (FIX 9 — stacking the actions under the title instead of a
/// ListTile's fixed leading/title/trailing row avoids a narrow-phone
/// RenderFlex overflow when a custom title is long). Actions are ordered
/// Done-then-Skip, matching the focus card (FIX 4), and only this row shows
/// the spinner while it's the one mid-mark (FIX 8).
class _SlotRow extends StatelessWidget {
  final CareTodaySlot slot;

  /// Whether *any* mark/edit is in flight. The controller's re-entrancy gate
  /// is a single global flag, not per row (design §B), so every row's
  /// buttons must disable — not just the one being acted on. Leaving them
  /// live let a tap made during a Done-row edit (the longest-running kind,
  /// since the user spends time in the sheet first) reach the controller
  /// only to be dropped by `if (marking) return;` with no feedback at all.
  final bool marking;

  /// Which of this row's two buttons shows the in-flight spinner, or `null`
  /// when this row isn't the one being acted on (FIX 8).
  final CareLogStatus? markingAction;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _SlotRow({
    required this.slot,
    required this.marking,
    required this.markingAction,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        key: Key('care-today-row-${slot.careScheduleId}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(slot.category)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      slot.timeOfDay,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // OverflowBar (not a plain Row) — on a narrow phone with a long
          // custom title squeezing the card, two full-size buttons side by
          // side can be wider than the available space; OverflowBar stacks
          // them vertically instead of letting the Row overflow (FIX 9).
          OverflowBar(
            spacing: 12,
            overflowSpacing: 8,
            children: [
              FilledButton(
                key: Key('care-today-row-done-${slot.careScheduleId}'),
                onPressed: marking ? null : onDone,
                child: markingAction == CareLogStatus.done
                    ? const _ButtonSpinner()
                    : Text(loc.careTodayMarkDoneButton),
              ),
              OutlinedButton(
                key: Key('care-today-row-skip-${slot.careScheduleId}'),
                onPressed: marking ? null : onSkip,
                child: markingAction == CareLogStatus.skipped
                    ? const _ButtonSpinner()
                    : Text(loc.careTodaySkipButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneGroup extends StatefulWidget {
  final List<CareTodaySlot> slots;
  final DateTime Function(DateTime) toLocalTime;

  /// Per-slot marking lookup (FIX 8) — also true while a Done-group row's
  /// own edit is in flight, since [CareTodayController.edit] sets the same
  /// tracking fields as a mark. Shows an in-flight indicator in place of the
  /// edit icon and disables the row so a second tap can't open another sheet
  /// mid-edit.
  final CareLogStatus? Function(CareTodaySlot slot) markingAction;

  /// Whether *any* mark/edit is in flight. The controller's re-entrancy gate
  /// is a single global flag, not per row (design §B), so a row other than
  /// the one being acted on must be disabled too — leaving its edit icon
  /// live would let a tap open a sheet whose submit the gate then drops with
  /// no feedback at all.
  final bool marking;
  final ValueChanged<CareTodaySlot> onEdit;

  const _DoneGroup({
    required this.slots,
    required this.toLocalTime,
    required this.marking,
    required this.markingAction,
    required this.onEdit,
  });

  @override
  State<_DoneGroup> createState() => _DoneGroupState();
}

class _DoneGroupState extends State<_DoneGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('care-today-done-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  loc.careTodayDoneSection(widget.slots.length),
                  style: theme.textTheme.titleMedium,
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            for (final slot in widget.slots)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgeCard(
                  child: ListTile(
                    // A composite key (design §B) — the plain
                    // `careScheduleId` key a schedule that fires twice a day
                    // would collide on, leaving no way to address a specific
                    // row.
                    key: Key(
                      'care-today-row-${slot.careScheduleId}-${slot.localDate}-${slot.timeOfDay}',
                    ),
                    leading: Icon(
                      _doneRowIcon(slot),
                      color: slot.status == CareTodayStatus.done
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      slot.title,
                      style: slot.status == CareTodayStatus.done
                          ? null
                          : const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            ),
                    ),
                    subtitle: Text(
                      _doneRowSubtitle(loc, slot, widget.toLocalTime),
                    ),
                    // Greyed out (and untappable) whenever anything is in
                    // flight, not just this row — see [_DoneGroup.marking].
                    enabled: !widget.marking,
                    trailing: widget.markingAction(slot) != null
                        ? SizedBox(
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
                            // An explicit colour overrides the disabled
                            // IconTheme `enabled: false` installs, so the
                            // affordance has to be greyed here too —
                            // otherwise the row's text dims while its edit
                            // icon keeps looking tappable.
                            color: widget.marking
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.38,
                                  )
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                    onTap: widget.marking ? null : () => widget.onEdit(slot),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One of [_EditSheet]'s two mutually exclusive outcome choices — a
/// [ListTile] whose `selected` both tints it and exposes the choice as
/// `Semantics(selected: …)`, with a filled/outline circle in the leading
/// slot. Mirrors `settings_screen.dart`'s `_OptionRow` (and, like it, avoids
/// the deprecated `RadioListTile.groupValue`/`onChanged` API).
class _StatusOptionRow extends StatelessWidget {
  final Key rowKey;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _StatusOptionRow({
    required this.rowKey,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: rowKey,
      selected: selected,
      onTap: onSelected,
      title: Text(label),
      leading: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
    );
  }
}

/// The Done-group row's status label, used only in [_EditSheet]'s header
/// subtitle — reuses the existing today/skipped/missed copy rather than
/// introducing a redundant ARB key.
String _editSheetStatusLabel(AppLocalizations loc, CareTodayStatus status) =>
    switch (status) {
      CareTodayStatus.skipped => loc.careTodayStatusSkipped,
      CareTodayStatus.missed => loc.careTodayStatusMissed,
      _ => loc.careTodayMarkDoneButton,
    };

/// The outcome of [_EditSheet]: the chosen status, and — unless [status] is
/// [CareLogStatus.skipped] — the chosen completion time (in UTC, ready to
/// send straight to [CareTodayController.edit]).
class _EditSheetResult {
  final CareLogStatus status;
  final DateTime? doneTime;

  const _EditSheetResult({required this.status, this.doneTime});
}

/// The Done-group correction sheet (design §B): unlike `/care-history`'s
/// tap-to-pop sheet, this one collects two things (outcome + completion
/// time) before submitting, so it needs its own in-sheet state and a
/// confirm button rather than popping on the first tap.
class _EditSheet extends StatefulWidget {
  final CareTodaySlot slot;
  final DateTime Function(DateTime) toLocalTime;
  final Future<DateTime?> Function(
    BuildContext context,
    CareTodaySlot slot,
    DateTime current,
    DateTime Function(DateTime) toLocalTime,
  )
  pickDoneTime;

  const _EditSheet({
    required this.slot,
    required this.toLocalTime,
    required this.pickDoneTime,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late CareLogStatus _status = widget.slot.status == CareTodayStatus.skipped
      ? CareLogStatus.skipped
      : CareLogStatus.done;
  late DateTime _doneTime = _initialDoneTime(widget.slot);

  Future<void> _pickTime() async {
    final picked = await widget.pickDoneTime(
      context,
      widget.slot,
      _doneTime,
      widget.toLocalTime,
    );
    // The sheet can be dismissed while the picker is still open, so this
    // State may already be gone by the time the pick lands.
    if (!mounted) return;
    if (picked == null) return;
    setState(() => _doneTime = picked);
  }

  void _submit() {
    Navigator.of(context).pop(
      _EditSheetResult(
        status: _status,
        doneTime: _status == CareLogStatus.skipped ? null : _doneTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final slot = widget.slot;
    final skipped = _status == CareLogStatus.skipped;
    final dateLabel = mediumDateLabel(context, parseDayString(slot.localDate));
    final timeLabel = DateFormat('HH:mm').format(widget.toLocalTime(_doneTime));

    return Padding(
      // Lift the sheet above the on-screen keyboard — the project's
      // bottom-sheet convention (see `exercise_screen.dart`,
      // `goal_card.dart`) — *and* above the bottom safe-area inset:
      // `showModalBottomSheet(useSafeArea: true)` applies `SafeArea(bottom:
      // false)`, leaving the bottom edge to the sheet, so on a
      // gesture-navigation phone the submit button otherwise sat 16dp from
      // the screen edge, inside the home-indicator strip.
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              loc.careTodayEditSheetTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            title: Text(
              slot.title,
              key: const Key('care-today-edit-sheet-title'),
            ),
            subtitle: Text(
              '$dateLabel · ${slot.timeOfDay} · ${_editSheetStatusLabel(loc, slot.status)}',
              key: const Key('care-today-edit-sheet-subtitle'),
            ),
          ),
          // The two outcome choices, built like `settings_screen.dart`'s
          // `_OptionRow`: `selected:` is what puts the choice in the
          // semantics tree (`Semantics(selected: true)`), where the previous
          // bare trailing `Icon(Icons.check)` was invisible to a screen
          // reader — it heard two identical tappable rows and no way to tell
          // which one was about to be submitted. The leading circle also
          // replaces the old `check_circle_outline`/`remove_circle_outline`
          // pair, which came from the *status* icon set and so left the Done
          // row permanently wearing a tick that fought the selection tick.
          _StatusOptionRow(
            rowKey: const Key('care-today-edit-status-done'),
            label: loc.careTodayMarkDoneButton,
            selected: !skipped,
            onSelected: () => setState(() => _status = CareLogStatus.done),
          ),
          _StatusOptionRow(
            rowKey: const Key('care-today-edit-status-skipped'),
            label: loc.careTodaySkipButton,
            selected: skipped,
            onSelected: () => setState(() => _status = CareLogStatus.skipped),
          ),
          ListTile(
            key: const Key('care-today-edit-time'),
            enabled: !skipped,
            leading: const Icon(Icons.schedule),
            title: Text(loc.careTodayEditTimeLabel),
            subtitle: Text(timeLabel),
            onTap: skipped ? null : _pickTime,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('care-today-edit-submit'),
                onPressed: _submit,
                child: Text(loc.careTodayEditSubmitButton),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
