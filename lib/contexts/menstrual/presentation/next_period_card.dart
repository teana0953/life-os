import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/card_error_retry.dart';
import '../../../shared/widgets/card_loading.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/stale_notice.dart';
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

    // A failure with no overview to fall back on → an error message in place
    // of the content the card doesn't have. A failure *after* an overview has
    // been shown keeps it and appends a [StaleNotice] instead (below) —
    // mirrors `GoalCard`.
    if (controller.status == MenstrualStatus.error &&
        controller.overview == null) {
      // With a retry, like every other overview card: telling someone to try
      // again while giving them nothing to try again with is a dead end.
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: CardErrorRetry(
          message: loc.errorMenstrualLoadFailed,
          messageKey: const Key('next-period-error'),
          retryKey: const Key('next-period-retry'),
          onRetry: () => controller.load(widget.idToken),
        ),
      );
    }

    // Only the *first* load gets a spinner. A reload keeps the content it
    // already has, so an automatic refresh can't blank the overview (#82).
    final overview = controller.overview;
    if (overview == null) {
      return const LedgeCard(
        padding: EdgeInsets.all(24),
        child: CardLoading(indicatorKey: Key('next-period-loading')),
      );
    }

    // Sampled once: the day count and the guard below must agree even if the
    // build straddles midnight.
    final now = widget.clock();
    final status = computeNextPeriodStatus(overview, now);
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
    // ongoing, and only when there is one still ahead. Two ways there isn't:
    // someone recording for the first time has an ongoing period and no
    // prediction at all; and a period left open for a whole average cycle has
    // a prediction that has arrived or gone by — "next expected 28 Jul" on the
    // 28th contradicts itself, and a past date under an upcoming label is the
    // thing the overdue copy exists to avoid. Either way the line disappears
    // rather than standing in a placeholder; the day count above it already
    // says what is going on.
    final showsPrediction =
        status.state == NextPeriodState.ongoing &&
        predicted != null &&
        daysBetween(now, predicted) > 0;
    final secondary = showsPrediction
        ? loc.nextPeriodOngoingNext(mediumDateLabel(context, predicted))
        : null;

    // The marking goes inside the card but outside the [InkWell] — inside it,
    // tapping retry would open the tracker instead.
    return LedgeCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
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
                        Text(
                          loc.nextPeriodTitle,
                          style: theme.textTheme.titleLarge,
                        ),
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
          // Kept mounted through a reload as well as a failure: the marking
          // remembers whether the reload in flight is the one it started, and
          // unmounting it mid-retry would throw that away.
          if (controller.status == MenstrualStatus.error ||
              controller.status == MenstrualStatus.loading)
            StaleNotice(
              failed: controller.status == MenstrualStatus.error,
              loading: controller.status == MenstrualStatus.loading,
              subject: loc.nextPeriodTitle,
              onRetry: () => controller.load(widget.idToken),
            ),
        ],
      ),
    );
  }
}
