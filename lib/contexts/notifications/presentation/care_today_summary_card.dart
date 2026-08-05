import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/mascot.dart';
import '../../../shared/widgets/stale_notice.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';
import 'care_today_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

IconData _categoryIcon(CareCategory category) => switch (category) {
  CareCategory.medication => Icons.medication_outlined,
  CareCategory.rehab => Icons.fitness_center,
  CareCategory.radiotherapyCare => Icons.healing,
  CareCategory.custom => Icons.category_outlined,
};

/// A compact cousin of `CareTodayScreen`'s focus card, shown at the top of
/// the health overview so today's most-urgent care is visible without
/// opening the full checklist. A thin shell over [CareTodayController] — no
/// business logic of its own: urgency branching, the focus slot, and the
/// group counts are all derived state the controller already exposes.
///
/// Renders nothing while a first load is still in flight (so it never
/// disrupts the overview for a state that's about to resolve), and nothing on
/// a reauth before that first load — the [HealthScaffold] owns re-auth. A
/// first load that *fails* shows an error with a retry instead: this is the
/// top card of the overview, and rendering nothing there reads as "you have
/// no care today". A reload (e.g. after a chaodays import) keeps showing the
/// last loaded summary instead of disappearing, adding a [StaleNotice] when
/// that reload failed — mirrors the other overview cards.
/// Once loaded with no schedules today, renders a slim setup-prompt card
/// (tapping it calls [onSetup]) instead — the shortest path from the
/// overview to setting up care reminders for a new user. Once loaded with
/// schedules, the header carries a "manage" entry (tapping it calls
/// [onManage]) alongside the existing tap-to-open-Today body.
class CareTodaySummaryCard extends StatefulWidget {
  final CareTodayController controller;
  final IdTokenProvider idToken;

  /// Opens care reminders management (medication/rehab/radiotherapy care/
  /// custom schedules), from the header entry shown once there's a real
  /// summary to show.
  final VoidCallback onManage;

  /// Opens care reminders management from the no-schedule setup prompt.
  final VoidCallback onSetup;

  const CareTodaySummaryCard({
    super.key,
    required this.controller,
    required this.idToken,
    required this.onManage,
    required this.onSetup,
  });

  @override
  State<CareTodaySummaryCard> createState() => _CareTodaySummaryCardState();
}

class _CareTodaySummaryCardState extends State<CareTodaySummaryCard> {
  /// Whether the controller has completed at least one successful load —
  /// distinguishes "reloading, but there's content to keep" from "loading
  /// for the first time, nothing to show yet" (both look like `slots` being
  /// whatever they currently are, so `status` alone during a reload isn't
  /// enough: it's back to `loading` either way).
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _hasLoadedOnce = widget.controller.status == CareTodayLoadStatus.loaded;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // Listens to the controller itself (rather than relying solely on an
  // ancestor to rebuild it) so an in-flight mark's per-row spinner and the
  // post-mark state update immediately regardless of what ancestor owns it.
  void _onControllerChanged() {
    if (widget.controller.status == CareTodayLoadStatus.loaded) {
      _hasLoadedOnce = true;
    }
    setState(() {});
  }

  Future<void> _mark(
    BuildContext context,
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
      await widget.idToken(),
      careScheduleId: slot.careScheduleId,
      localDate: slot.localDate,
      timeOfDay: slot.timeOfDay,
    );
    if (!context.mounted) return;
    if (widget.controller.markError != null) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.careErrorGeneric),
          action: SnackBarAction(
            label: loc.retry,
            onPressed: () => _mark(context, slot, action),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _content(context);

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    final onManage = widget.onManage;
    // Whether a summary has ever loaded. `_hasLoadedOnce` alone isn't enough:
    // it only seeds from `status == loaded`, and the controller is an
    // app-level singleton, so re-entering the health module can build a fresh
    // card over a controller stuck in `error` that still holds today's slots.
    // `CareTodayController.date` is only ever written on a successful fetch
    // and never cleared, so it is the one signal that survives a remount.
    // Not `slots.isNotEmpty`: a day with nothing scheduled loads *successfully*
    // with no slots, and that is the existing setup-prompt branch, not an
    // absence of content.
    final hasLoaded = controller.date.isNotEmpty || _hasLoadedOnce;
    // Once a summary has loaded, keep showing it for any later non-loaded
    // status — a reload in flight, but also a reload that fails. Since imports
    // now trigger reloads on their own, a failed one must not make the top card
    // of the overview vanish and jump the layout.
    if (controller.status != CareTodayLoadStatus.loaded && !hasLoaded) {
      // Nothing has loaded, so there is nothing to keep. A first load still in
      // flight is about to resolve and renders nothing; one that *failed* has
      // to say so, because a missing top card reads as "you have no care
      // today" — no message, no retry, no way to tell.
      if (controller.status == CareTodayLoadStatus.error) {
        return _ErrorCard(onRetry: () async => controller.load(await widget.idToken()));
      }
      return const SizedBox.shrink();
    }
    final failed = controller.status == CareTodayLoadStatus.error;
    final reloading = controller.status == CareTodayLoadStatus.loading;
    void staleRetry() async => controller.load(await widget.idToken());
    final slots = controller.slots;
    if (slots.isEmpty) {
      return _SetupPrompt(
        onSetup: widget.onSetup,
        failed: failed,
        reloading: reloading,
        onRetry: staleRetry,
      );
    }

    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final focus = controller.focusSlot;
    final groups = controller.groups;
    final done = groups.done.length;
    final total = slots.length;
    final isOverdue = focus != null && focus.status == CareTodayStatus.overdue;
    final moreCount = groups.overdue.length + groups.later.length;

    return Padding(
      key: const Key('care-today-summary-card'),
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgeCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => context.push('/care-today'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.checklist_outlined,
                            color: isOverdue ? theme.colorScheme.error : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.careTodayTitle,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          _ProgressPill(loc: loc, done: done, total: total),
                          IconButton(
                            key: const Key('care-today-summary-manage'),
                            onPressed: onManage,
                            tooltip: loc.careTodaySummaryManage,
                            icon: Icon(
                              Icons.settings_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (focus == null)
                        _CelebrationRow(loc: loc, theme: theme)
                      else
                        _FocusRow(
                          focus: focus,
                          isOverdue: isOverdue,
                          markingAction: controller.markingAction(focus),
                          onDone: () =>
                              _mark(context, focus, controller.markDone),
                          onSkip: isOverdue
                              ? () =>
                                    _mark(context, focus, controller.markSkipped)
                              : null,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        key: const Key('care-today-summary-open'),
                        moreCount > 0
                            ? '${loc.careTodaySummaryMoreCount(moreCount)} · '
                                  '${loc.careTodaySummarySeeAll} →'
                            : '${loc.careTodaySummarySeeAll} →',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Outside the [InkWell]: inside it, tapping retry would open the
              // Today checklist instead. Kept mounted through a reload as well
              // as a failure: the marking remembers whether the reload in
              // flight is the one it started, and unmounting it mid-retry
              // would throw that away.
              if (failed || reloading)
                StaleNotice(
                  failed: failed,
                  loading: reloading,
                  subject: loc.careTodayTitle,
                  onRetry: staleRetry,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The slim no-schedule state: a one-line "set up care reminders" prompt in
/// place of the full summary card, so a new user without any care schedules
/// still has a one-tap path to setting one up from the overview (rather than
/// the card rendering nothing, per the surface-care-reminders change).
/// [failed] appends the "couldn't refresh" marking below it — a day with
/// nothing scheduled is loaded content, so a failed refresh marks it rather
/// than replacing it. [reloading] rides along so the marking can keep itself
/// on screen while the retry it started runs.
class _SetupPrompt extends StatelessWidget {
  final VoidCallback onSetup;
  final bool failed;
  final bool reloading;
  final VoidCallback onRetry;

  const _SetupPrompt({
    required this.onSetup,
    required this.failed,
    required this.reloading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      key: const Key('care-today-summary-setup'),
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgeCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onSetup,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.careTodaySummarySetupTitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${loc.careTodaySummarySetupCta} →',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (failed || reloading)
                StaleNotice(
                  failed: failed,
                  loading: reloading,
                  subject: loc.careTodaySummarySetupTitle,
                  onRetry: onRetry,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first-ever-load failure: the card has nothing to keep, so it says so
/// and offers a retry. Mirrors the other overview cards' error card — before
/// this, the card rendered nothing at all, which on the top of the overview
/// reads as "you have no care today". Its copy names today's care rather than
/// reusing `careErrorGeneric`: that string is written for the full care
/// screens, where the app bar already says what the user was looking at, and
/// the three cards below this one each name their own subject.
class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.errorCareTodayLoadFailed,
              key: const Key('care-today-summary-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('care-today-summary-retry'),
              onPressed: onRetry,
              child: Text(loc.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final AppLocalizations loc;
  final int done;
  final int total;

  const _ProgressPill({required this.loc, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        loc.careTodaySummaryProgress(done, total),
        style: theme.textTheme.labelMedium,
      ),
    );
  }
}

class _CelebrationRow extends StatelessWidget {
  final AppLocalizations loc;
  final ThemeData theme;

  const _CelebrationRow({required this.loc, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Mascot(size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            loc.careTodayCelebrationTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

/// A small error-tinted status chip flagging the focus row as overdue
/// before the user reads its title, so urgency isn't conveyed by color
/// alone (the chip carries its own text label too).
class _OverdueChip extends StatelessWidget {
  final ThemeData theme;
  final String label;

  const _OverdueChip({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('care-today-summary-overdue-chip'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: theme.colorScheme.error.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    ),
  );
}

/// A small inline spinner sized to sit inside a [FilledButton]/
/// [OutlinedButton] in place of its label while that button's action is in
/// flight (mirrors `CareTodayScreen`'s per-row marking spinner).
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 16,
    width: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _FocusRow extends StatelessWidget {
  final CareTodaySlot focus;
  final bool isOverdue;
  final CareLogStatus? markingAction;
  final VoidCallback onDone;
  final VoidCallback? onSkip;

  const _FocusRow({
    required this.focus,
    required this.isOverdue,
    required this.markingAction,
    required this.onDone,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final marking = markingAction != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _categoryIcon(focus.category),
              color: isOverdue ? theme.colorScheme.error : null,
            ),
            const SizedBox(width: 8),
            if (isOverdue) ...[
              _OverdueChip(theme: theme, label: loc.careTodayOverdueSection),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(focus.title, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isOverdue
              ? '${focus.timeOfDay} · ${loc.careTodayOverdueSection}'
              : '${focus.timeOfDay} · ${loc.careTodayUpNext}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isOverdue
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (focus.dose != null && focus.dose!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(focus.dose!),
          ),
        const SizedBox(height: 12),
        OverflowBar(
          spacing: 12,
          overflowSpacing: 8,
          children: [
            FilledButton(
              key: const Key('care-today-summary-done'),
              onPressed: marking ? null : onDone,
              child: markingAction == CareLogStatus.done
                  ? const _ButtonSpinner()
                  : Text(loc.careTodayMarkDoneButton),
            ),
            if (onSkip != null)
              OutlinedButton(
                key: const Key('care-today-summary-skip'),
                onPressed: marking ? null : onSkip,
                child: markingAction == CareLogStatus.skipped
                    ? const _ButtonSpinner()
                    : Text(loc.careTodaySkipButton),
              ),
          ],
        ),
      ],
    );
  }
}
