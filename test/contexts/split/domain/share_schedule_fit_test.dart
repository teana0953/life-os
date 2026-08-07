import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/share_schedule_fit.dart';
import 'package:life_os/contexts/split/domain/split_input.dart';
import 'package:life_os/contexts/split/domain/split_share.dart';

/// The server takes a schedule only when `periods * per_period_amount`
/// equals the share exactly — there is no remainder to spread. So the form
/// has to make them agree first, and the only honest way to do that is to
/// move the difference onto somebody else and say so.
void main() {
  const payer = 'payer';
  const holder = 'holder';
  const other = 'other';

  ExactShareInput share(String userId, int amount, {ShareSchedule? schedule}) =>
      ExactShareInput(userId: userId, amount: amount, schedule: schedule);

  group('a share that divides exactly', () {
    test('is left alone — not "adjusted by zero"', () {
      final result = fitShareToSchedule(
        shares: [share(payer, 1000), share(holder, 6000)],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      // `adjustment == null` and `adjustment.delta == 0` would render as two
      // different sentences, and only one of them is true here: nothing was
      // moved, so nothing should be announced.
      expect(result, isA<ScheduleFitApplied>());
      final applied = result as ScheduleFitApplied;
      expect(applied.adjustment, isNull);
      expect(applied.shares.map((s) => s.amount), [1000, 6000]);
      expect(applied.shares[1].schedule, const ShareSchedule(periods: 12, perPeriodAmount: 500));
    });
  });

  group('a share that does not divide', () {
    test('rounds down and moves the difference to the payer', () {
      final result = fitShareToSchedule(
        shares: [share(payer, 1000), share(holder, 6100)],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      final applied = result as ScheduleFitApplied;
      // 6100 -> 6096 (12 x 508), the 4 going to the payer. Both figures are
      // reported so the form can show "6,100 -> 6,096" rather than silently
      // replacing what the user typed.
      expect(applied.adjustment, isNotNull);
      expect(applied.adjustment!.userId, holder);
      expect(applied.adjustment!.from, 6100);
      expect(applied.adjustment!.to, 6096);
      expect(applied.adjustment!.absorbedBy, payer);
      expect(applied.shares.firstWhere((s) => s.userId == holder).amount, 6096);
      expect(applied.shares.firstWhere((s) => s.userId == payer).amount, 1004);
      expect(
        applied.shares.firstWhere((s) => s.userId == holder).schedule,
        const ShareSchedule(periods: 12, perPeriodAmount: 508),
      );
    });

    test('the total is unchanged — the expense amount did not move', () {
      final result = fitShareToSchedule(
        shares: [share(payer, 1000), share(holder, 6100)],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      final applied = result as ScheduleFitApplied;
      expect(applied.shares.fold<int>(0, (sum, s) => sum + s.amount), 7100);
    });

    test('falls to an unscheduled participant when the payer holds no share', () {
      final result = fitShareToSchedule(
        shares: [share(holder, 6100), share(other, 900)],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      final applied = result as ScheduleFitApplied;
      expect(applied.adjustment!.absorbedBy, other);
      expect(applied.shares.firstWhere((s) => s.userId == other).amount, 904);
    });

    test('never lands the difference on somebody else who is on a schedule', () {
      // Their own periods multiply back to their own amount; adding 4 to it
      // breaks that, and the server rejects the whole save with a 400 naming
      // a share the user never touched.
      final result = fitShareToSchedule(
        shares: [
          share(holder, 6100),
          share(other, 900, schedule: const ShareSchedule(periods: 3, perPeriodAmount: 300)),
        ],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      expect(result, isA<ScheduleFitImpossible>());
      expect(
        (result as ScheduleFitImpossible).workablePeriods,
        isNot(contains(12)),
      );
    });

    test('is blocked when there is nobody to absorb it, and names what would work', () {
      final result = fitShareToSchedule(
        shares: [share(holder, 6100)],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      final blocked = result as ScheduleFitImpossible;
      // 6100 = 2^2 x 5^2 x 61. Every suggestion must actually divide, and
      // every one must be a plausible number of months.
      expect(blocked.workablePeriods, isNotEmpty);
      for (final periods in blocked.workablePeriods) {
        expect(6100 % periods, 0, reason: '$periods does not divide 6100');
        expect(periods, greaterThan(1));
      }
    });
  });

  group('rejected outright', () {
    test('a period count that would make a period worth nothing', () {
      // 12 periods of a 5-dollar share rounds to 0 per period, and a schedule
      // of twelve zeroes is not a schedule the server will take.
      final result = fitShareToSchedule(
        shares: [share(payer, 1000), share(holder, 5)],
        scheduledUserId: holder,
        periods: 12,
        payerUserId: payer,
      );

      expect(result, isA<ScheduleFitImpossible>());
    });
  });
}
