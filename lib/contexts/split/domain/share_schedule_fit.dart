import 'split_input.dart';
import 'split_share.dart';

/// Making a share divide by its period count.
///
/// The server takes a schedule only when `periods * per_period_amount`
/// equals the share exactly (`parseShareSchedule`, backend). There is no
/// remainder to spread, so 6,100 over 12 periods is not a schedule the
/// server will accept in any spelling — something has to give, and the only
/// two candidates are the share and the period count.
///
/// This picks the share, rounds it **down** to the nearest divisible amount,
/// and moves the difference onto another participant so the expense total
/// still adds up. It reports what it moved: a figure silently different from
/// what the user typed is the failure this whole function exists to avoid.

/// The outcome of fitting a share to a period count.
sealed class ScheduleFitResult {
  const ScheduleFitResult();
}

/// The schedule fits, with [adjustment] describing the difference that had to
/// move — **null when the share divided exactly**, which is a different
/// sentence from "moved 0" and has to stay tellable apart.
class ScheduleFitApplied extends ScheduleFitResult {
  final List<ExactShareInput> shares;
  final ShareAdjustment? adjustment;

  const ScheduleFitApplied({required this.shares, this.adjustment});
}

/// Nobody could absorb the difference. [workablePeriods] are period counts
/// that would divide the share as it stands, so the user has something to
/// choose instead of only being told no.
class ScheduleFitImpossible extends ScheduleFitResult {
  final List<int> workablePeriods;

  const ScheduleFitImpossible({required this.workablePeriods});
}

/// One share moved from [from] to [to], with [absorbedBy] taking the
/// difference. Both figures are kept so the form can show the change rather
/// than just the result.
class ShareAdjustment {
  final String userId;
  final int from;
  final int to;
  final String absorbedBy;

  const ShareAdjustment({
    required this.userId,
    required this.from,
    required this.to,
    required this.absorbedBy,
  });

  int get delta => from - to;
}

/// At most this many suggestions, and never a schedule longer than this many
/// months — the divisors of a number like 6,100 include 1,220 and 3,050,
/// which are arithmetically correct and useless as repayment plans.
const _maxSuggestions = 4;
const _maxSuggestedPeriods = 60;

/// Puts [scheduledUserId]'s share on a [periods]-month schedule, adjusting it
/// and one other share if the division leaves a remainder.
///
/// The absorber is chosen in a defined order — the payer's own share first,
/// then any participant not themselves on a schedule. Never somebody who is
/// on one: their periods multiply back to their own amount, and adding to it
/// breaks that invariant, which the server then rejects by naming a share the
/// user never touched.
ScheduleFitResult fitShareToSchedule({
  required List<ExactShareInput> shares,
  required String scheduledUserId,
  required int periods,
  required String payerUserId,
}) {
  final target = shares.firstWhere((share) => share.userId == scheduledUserId);
  final perPeriod = target.amount ~/ periods;
  // A schedule of zeroes is not a schedule; the server rejects a
  // non-positive per-period amount outright.
  if (perPeriod <= 0) {
    return ScheduleFitImpossible(workablePeriods: _workablePeriods(target.amount));
  }
  final fitted = perPeriod * periods;
  final difference = target.amount - fitted;

  ExactShareInput scheduled(int amount) => ExactShareInput(
    userId: scheduledUserId,
    amount: amount,
    schedule: ShareSchedule(periods: periods, perPeriodAmount: amount ~/ periods),
  );

  if (difference == 0) {
    return ScheduleFitApplied(
      shares: [
        for (final share in shares) share.userId == scheduledUserId ? scheduled(share.amount) : share,
      ],
    );
  }

  final absorber = _absorber(shares, scheduledUserId, payerUserId);
  if (absorber == null) {
    return ScheduleFitImpossible(workablePeriods: _workablePeriods(target.amount));
  }

  return ScheduleFitApplied(
    shares: [
      for (final share in shares)
        if (share.userId == scheduledUserId)
          scheduled(fitted)
        else if (share.userId == absorber)
          ExactShareInput(userId: share.userId, amount: share.amount + difference, schedule: share.schedule)
        else
          share,
    ],
    adjustment: ShareAdjustment(
      userId: scheduledUserId,
      from: target.amount,
      to: fitted,
      absorbedBy: absorber,
    ),
  );
}

/// The payer's own share first, then any participant not on a schedule.
String? _absorber(List<ExactShareInput> shares, String scheduledUserId, String payerUserId) {
  final candidates = shares.where((share) => share.userId != scheduledUserId && share.schedule == null);
  for (final share in candidates) {
    if (share.userId == payerUserId) return share.userId;
  }
  return candidates.isEmpty ? null : candidates.first.userId;
}

/// Period counts that divide [amount] exactly, smallest first, capped so the
/// list stays a set of choices rather than a factorisation.
List<int> _workablePeriods(int amount) {
  final periods = <int>[];
  for (var candidate = 2; candidate <= _maxSuggestedPeriods && periods.length < _maxSuggestions; candidate++) {
    if (amount % candidate == 0 && amount ~/ candidate > 0) periods.add(candidate);
  }
  return periods;
}
