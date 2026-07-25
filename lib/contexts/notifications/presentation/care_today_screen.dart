import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/mascot.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';
import 'care_today_controller.dart';

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

/// The Done-group row subtitle: done shows its recorded time, skipped/missed
/// show the slot's time plus a status word so the two aren't visually
/// identical (FIX 5 — previously both were bare strikethrough text with no
/// way to tell a deliberate skip from a miss).
String _doneRowSubtitle(AppLocalizations loc, CareTodaySlot slot) =>
    switch (slot.status) {
      CareTodayStatus.done => slot.doneTime != null
          ? loc.careTodayDoneAtLabel(slot.doneTime!)
          : slot.timeOfDay,
      CareTodayStatus.skipped =>
        '${slot.timeOfDay} · ${loc.careTodayStatusSkipped}',
      CareTodayStatus.missed =>
        '${slot.timeOfDay} · ${loc.careTodayStatusMissed}',
      _ => slot.timeOfDay,
    };

DateTime _parseDate(String s) {
  final parts = s.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
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

  const CareTodayScreen({
    super.key,
    required this.controller,
    required this.authRepository,
    required this.onOpenCareItems,
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
                      mediumDateLabel(context, _parseDate(controller.date)),
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
                          markingAction: controller.markingAction,
                          onDone: _markDone,
                          onSkip: _markSkipped,
                        ),
                      if (groups.later.isNotEmpty)
                        _SlotGroup(
                          titleKey: const Key('care-today-later-section'),
                          title: loc.careTodayLaterSection,
                          slots: groups.later,
                          markingAction: controller.markingAction,
                          onDone: _markDone,
                          onSkip: _markSkipped,
                        ),
                      if (groups.done.isNotEmpty)
                        _DoneGroup(slots: groups.done),
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

  /// The action ([CareLogStatus.done]/[CareLogStatus.skipped]) currently in
  /// flight for [slot], or `null` if it isn't being marked right now (FIX
  /// 8) — disables the row's buttons and shows a spinner on the pressed one
  /// instead of a screen-wide disable.
  final CareLogStatus? markingAction;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _FocusCard({
    required this.slot,
    required this.markingAction,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isOverdue = slot.status == CareTodayStatus.overdue;
    final marking = markingAction != null;
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

  /// Per-slot marking lookup (FIX 8) — see [_FocusCard.markingAction].
  final CareLogStatus? Function(CareTodaySlot slot) markingAction;
  final ValueChanged<CareTodaySlot> onDone;
  final ValueChanged<CareTodaySlot> onSkip;

  const _SlotGroup({
    required this.titleKey,
    required this.title,
    required this.slots,
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
/// Done-then-Skip, matching the focus card (FIX 4), and only this row's
/// buttons disable/spin while it's mid-mark (FIX 8).
class _SlotRow extends StatelessWidget {
  final CareTodaySlot slot;
  final CareLogStatus? markingAction;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const _SlotRow({
    required this.slot,
    required this.markingAction,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final marking = markingAction != null;
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

  const _DoneGroup({required this.slots});

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
                    key: Key('care-today-row-${slot.careScheduleId}'),
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
                    subtitle: Text(_doneRowSubtitle(loc, slot)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
