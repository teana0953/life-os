import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/presentation/split_activity_direction.dart';

/// A group repayment recorded by Amy (`u-amy`) with Ben (`u-ben`) as the
/// counterpart. `actorIsPayer` is stored **relative to Amy**.
SplitActivity _repayment({required bool actorIsPayer}) => SplitActivity(
  id: 'a1',
  type: SplitActivityType.settlementCreated,
  actorUserId: 'u-amy',
  actorDisplayName: 'Amy',
  groupId: 'g1',
  groupName: 'Trip',
  subjectId: 's1',
  counterpartUserId: 'u-ben',
  counterpartDisplayName: 'Ben',
  amount: 2000,
  previousAmount: null,
  actorIsPayer: actorIsPayer,
  currency: 'TWD',
  description: null,
  createdAt: '2026-08-01T10:30:00.000Z',
);

typedef _Row = ({
  String name,
  String? reader,
  bool actorIsPayer,
  RepaymentViewpoint viewpoint,
  String payer,
  String payee,
});

void main() {
  group('resolveRepaymentDirection', () {
    // The six reader×direction combinations from design.md D2. Getting one
    // wrong renders a perfectly normal-looking row that states the opposite
    // of what happened, so every row is pinned separately.
    //
    // Rows 5 and 6 are the **group** case specifically: a repayment with no
    // group is only ever visible to {creator, payer, payee}, so a third-party
    // reader cannot exist outside a group.
    const rows = <_Row>[
      (
        name: 'the actor read their own outgoing repayment',
        reader: 'u-amy',
        actorIsPayer: true,
        viewpoint: RepaymentViewpoint.readerPaid,
        payer: 'u-amy',
        payee: 'u-ben',
      ),
      (
        name: 'the actor recorded a repayment made to them',
        reader: 'u-amy',
        actorIsPayer: false,
        viewpoint: RepaymentViewpoint.readerWasPaid,
        payer: 'u-ben',
        payee: 'u-amy',
      ),
      (
        name: 'the counterpart was paid by the actor',
        reader: 'u-ben',
        actorIsPayer: true,
        viewpoint: RepaymentViewpoint.readerWasPaid,
        payer: 'u-amy',
        payee: 'u-ben',
      ),
      (
        name: 'the counterpart is the one who paid',
        reader: 'u-ben',
        actorIsPayer: false,
        viewpoint: RepaymentViewpoint.readerPaid,
        payer: 'u-ben',
        payee: 'u-amy',
      ),
      (
        name: 'a third party in the group, actor paid',
        reader: 'u-cara',
        actorIsPayer: true,
        viewpoint: RepaymentViewpoint.betweenOthers,
        payer: 'u-amy',
        payee: 'u-ben',
      ),
      (
        name: 'a third party in the group, counterpart paid',
        reader: 'u-cara',
        actorIsPayer: false,
        viewpoint: RepaymentViewpoint.betweenOthers,
        payer: 'u-ben',
        payee: 'u-amy',
      ),
    ];

    for (final row in rows) {
      test(row.name, () {
        final direction = resolveRepaymentDirection(
          _repayment(actorIsPayer: row.actorIsPayer),
          row.reader,
        )!;

        expect(direction.viewpoint, row.viewpoint);
        expect(direction.payer.userId, row.payer);
        expect(direction.payee.userId, row.payee);
      });
    }

    test('carries each party\'s display name alongside their id', () {
      final direction = resolveRepaymentDirection(
        _repayment(actorIsPayer: true),
        'u-cara',
      )!;
      expect(direction.payer.displayName, 'Amy');
      expect(direction.payee.displayName, 'Ben');
    });

    test('an unknown reader is treated as a third party, not as the actor', () {
      // `selfUserId` is null until the profile resolves; rendering that as
      // "you paid Ben" would be a lie about the reader.
      final direction = resolveRepaymentDirection(
        _repayment(actorIsPayer: true),
        null,
      )!;
      expect(direction.viewpoint, RepaymentViewpoint.betweenOthers);
    });

    test('a non-repayment entry has no direction at all', () {
      const expense = SplitActivity(
        id: 'a2',
        type: SplitActivityType.expenseCreated,
        actorUserId: 'u-amy',
        actorDisplayName: 'Amy',
        groupId: null,
        groupName: null,
        subjectId: 'e1',
        counterpartUserId: null,
        counterpartDisplayName: null,
        amount: 900,
        previousAmount: null,
        actorIsPayer: null,
        currency: 'TWD',
        description: 'Dinner',
        createdAt: '2026-08-01T10:30:00.000Z',
      );
      expect(resolveRepaymentDirection(expense, 'u-amy'), isNull);
    });
  });
}
