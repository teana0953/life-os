import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

Map<String, dynamic> _json({
  Object? type = 'expense_created',
  Object? actorDisplayName = 'Amy',
  Object? counterpartDisplayName = 'Ben',
  Object? amount = 2000,
  Object? previousAmount,
  Object? actorIsPayer,
}) => {
  'id': 'a1',
  'type': type,
  'actor_user_id': 'u-actor',
  'actor_display_name': actorDisplayName,
  'group_id': null,
  'group_name': null,
  'subject_id': 'e1',
  'counterpart_user_id': 'u-counterpart',
  'counterpart_display_name': counterpartDisplayName,
  'amount': amount,
  'previous_amount': previousAmount,
  'actor_is_payer': actorIsPayer,
  'currency': 'TWD',
  'description': 'Dinner',
  'created_at': '2026-08-01T10:30:00.000Z',
};

void main() {
  group('SplitActivity.fromJson', () {
    test('reads every field of the backend contract', () {
      final activity = SplitActivity.fromJson(
        _json(previousAmount: 1500, actorIsPayer: true),
      );

      expect(activity.id, 'a1');
      expect(activity.type, SplitActivityType.expenseCreated);
      expect(activity.actorUserId, 'u-actor');
      expect(activity.actorDisplayName, 'Amy');
      expect(activity.counterpartUserId, 'u-counterpart');
      expect(activity.counterpartDisplayName, 'Ben');
      expect(activity.amount, 2000);
      expect(activity.previousAmount, 1500);
      expect(activity.actorIsPayer, true);
      expect(activity.currency, 'TWD');
      expect(activity.description, 'Dinner');
      expect(activity.subjectId, 'e1');
      expect(activity.createdAt, '2026-08-01T10:30:00.000Z');
    });

    test('maps all eight wire type strings', () {
      const wire = {
        'expense_created': SplitActivityType.expenseCreated,
        'expense_updated': SplitActivityType.expenseUpdated,
        'expense_deleted': SplitActivityType.expenseDeleted,
        'settlement_created': SplitActivityType.settlementCreated,
        'settlement_deleted': SplitActivityType.settlementDeleted,
        'group_created': SplitActivityType.groupCreated,
        'group_member_added': SplitActivityType.groupMemberAdded,
        'group_archived': SplitActivityType.groupArchived,
      };
      for (final entry in wire.entries) {
        expect(
          SplitActivity.fromJson(_json(type: entry.key)).type,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('an unrecognised type degrades to unknown instead of failing the page', () {
      // The backend ships independently of this app: a ninth write use case
      // arrives here as a string nothing maps. Rejecting it took the whole
      // page down — the entry, every other entry beside it, and the cursor
      // that would have reached the rest of the timeline.
      final activity = SplitActivity.fromJson(_json(type: 'expense_uncategorised'));

      expect(activity.type, SplitActivityType.unknown);
      // Everything else is still read, so the row can say who and when.
      expect(activity.actorDisplayName, 'Amy');
      expect(activity.amount, 2000);
      expect(activity.createdAt, '2026-08-01T10:30:00.000Z');
    });

    test('nullable fields come through as null', () {
      final activity = SplitActivity.fromJson(
        _json(counterpartDisplayName: null, amount: null),
      );
      expect(activity.counterpartDisplayName, isNull);
      expect(activity.amount, isNull);
      expect(activity.previousAmount, isNull);
      expect(activity.actorIsPayer, isNull);
    });

    test('a malformed entry throws SplitFetchFailure, not a cast error', () {
      expect(
        () => SplitActivity.fromJson(_json(actorDisplayName: 42)),
        throwsA(isA<SplitFetchFailure>()),
      );
      // A *missing* type is still malformed — unlike an unrecognised one,
      // which is a newer backend and degrades (see below).
      expect(
        () => SplitActivity.fromJson(_json(type: null)),
        throwsA(isA<SplitFetchFailure>()),
      );
      // `actor_display_name` is contractually non-nullable — the backend
      // substitutes the raw user id rather than omitting it. A null here
      // means the contract broke, which is a fetch failure, not an empty
      // name quietly rendered as a blank subject.
      expect(
        () => SplitActivity.fromJson(_json(actorDisplayName: null)),
        throwsA(isA<SplitFetchFailure>()),
      );
    });
  });
}
