import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/next_period_status.dart';
import 'menstrual_controller.dart';

/// The overview's next-period card: driven by [MenstrualController], it says
/// where today sits relative to the next predicted period (or reports the
/// ongoing one), and opens the menstrual tracker via [onOpen] when tapped —
/// in every state, including when there is nothing recorded yet.
///
/// It only listens: the loading is the [HealthScaffold]'s job (design D4), so
/// it never calls `load` itself. Loading and error render inside the card;
/// `needsReauth` is left to the scaffold. [clock] is injectable so the day
/// counts can be pinned in tests.
class NextPeriodCard extends StatefulWidget {
  final MenstrualController controller;
  final VoidCallback onOpen;
  final DateTime Function() clock;

  const NextPeriodCard({
    super.key,
    required this.controller,
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

    // A load/reload failure → an error message inside the card, whether or not
    // there is already an overview to fall back on (mirrors `GoalCard`).
    if (controller.status == MenstrualStatus.error) {
      return LedgeCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          loc.errorMenstrualLoadFailed,
          key: const Key('next-period-error'),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error),
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
    // ongoing — and only when there is one. Someone recording for the first
    // time has an ongoing period and no prediction at all, so this line has to
    // disappear rather than stand in a placeholder.
    final secondary = status.state == NextPeriodState.ongoing && predicted != null
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
