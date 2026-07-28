import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/next_period_status.dart';
import 'menstrual_controller.dart';

/// The overview's next-period card: driven by [MenstrualController], it says
/// where today sits relative to the next predicted period (or reports the
/// ongoing one), and opens the menstrual tracker via [onOpen] when tapped —
/// in every state it has data for, including when there is nothing recorded
/// yet. While loading or after a failure the card shows that instead, and the
/// failure carries its own retry (as the other overview cards do).
///
/// It never loads on its own: the first load is the [HealthScaffold]'s job
/// (design D4). Retry is the one exception — that one is the user asking.
/// `needsReauth` is left to the scaffold. [clock] is injectable so the day
/// counts can be pinned in tests.
class NextPeriodCard extends StatefulWidget {
  final MenstrualController controller;
  final String idToken;
  final VoidCallback onOpen;
  final DateTime Function() clock;

  const NextPeriodCard({
    super.key,
    required this.controller,
    required this.idToken,
    required this.onOpen,
    this.clock = DateTime.now,
  });

  @override
  State<NextPeriodCard> createState() => _NextPeriodCardState();
}

/// The date part of [value], so a prediction is compared against today's
/// calendar day rather than the current instant.
DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _NextPeriodCardState extends State<NextPeriodCard> {
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
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;

    // A load/reload failure → an error message inside the card, whether or not
    // there is already an overview to fall back on (mirrors `GoalCard`).
    if (controller.status == MenstrualStatus.error) {
      // With a retry, like every other overview card: telling someone to try
      // again while giving them nothing to try again with is a dead end.
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.errorMenstrualLoadFailed,
              key: const Key('next-period-error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('next-period-retry'),
              onPressed: () => controller.load(widget.idToken),
              child: Text(loc.retry),
            ),
          ],
        ),
      );
    }

    // Only the *first* load gets a spinner. A reload keeps the content it
    // already has, so an automatic refresh can't blank the overview (#82).
    final overview = controller.overview;
    if (overview == null) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(key: Key('next-period-loading')),
          ),
        ),
      );
    }

    final status = computeNextPeriodStatus(overview, widget.clock());
    final days = status.days;
    final predicted = status.predictedNextStart;

    // Matched on (state, date, day count) together so the date and the count
    // arrive already non-null where the copy needs them — no `!` on a
    // prediction that legitimately is null while a period is ongoing. The
    // final case is the "we know nothing" copy, which is also the right
    // degradation for any state whose data didn't come with it.
    final primary = switch ((status.state, predicted, days)) {
      (NextPeriodState.ongoing, _, final int day) => loc.nextPeriodOngoing(day),
      (NextPeriodState.upcoming, final DateTime date, final int n) =>
        loc.nextPeriodUpcoming(mediumDateLabel(context, date), n),
      (NextPeriodState.overdue, final DateTime date, final int n) =>
        loc.nextPeriodOverdue(mediumDateLabel(context, date), n),
      (NextPeriodState.today, _, _) => loc.nextPeriodToday,
      (NextPeriodState.needsOneMore, _, _) => loc.nextPeriodNeedsOneMore,
      _ => loc.nextPeriodNoRecords,
    };

    // The prediction rides along as a second line only while a period is
    // ongoing, and only when there is one to show. Two ways there isn't:
    // someone recording for the first time has an ongoing period and no
    // prediction at all; and a period left open past a whole average cycle has
    // a prediction that has already gone by — calling a past date "next
    // expected" is the thing the overdue copy exists to avoid. Either way the
    // line disappears rather than standing in a placeholder; the day count
    // above it already says what is going on.
    final showsPrediction =
        status.state == NextPeriodState.ongoing &&
        predicted != null &&
        !predicted.isBefore(_dateOnly(widget.clock()));
    final secondary = showsPrediction
        ? loc.nextPeriodOngoingNext(mediumDateLabel(context, predicted))
        : null;

    return LedgeCard(
      child: InkWell(
        key: const Key('next-period-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.nextPeriodTitle, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      primary,
                      key: const Key('next-period-primary'),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        secondary,
                        key: const Key('next-period-secondary'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // A hint that tapping the card opens the tracker.
              Icon(
                Icons.chevron_right,
                key: const Key('next-period-open-icon'),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
