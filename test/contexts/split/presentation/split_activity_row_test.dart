import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/split_activity.dart';
import 'package:life_os/contexts/split/presentation/split_activity_row.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';

import '../../../support/l10n_test_app.dart';

const _self = 'u-self';

SplitActivity _entry({
  required SplitActivityType type,
  String actorUserId = 'u-amy',
  String actorDisplayName = 'Amy',
  String? counterpartUserId = 'u-ben',
  String? counterpartDisplayName = 'Ben',
  String? groupName = 'Trip',
  int? amount = 2000,
  int? previousAmount,
  bool? actorIsPayer,
  String? description = 'Dinner',
}) => SplitActivity(
  id: 'a1',
  type: type,
  actorUserId: actorUserId,
  actorDisplayName: actorDisplayName,
  groupId: 'g1',
  groupName: groupName,
  subjectId: 's1',
  counterpartUserId: counterpartUserId,
  counterpartDisplayName: counterpartDisplayName,
  amount: amount,
  previousAmount: previousAmount,
  actorIsPayer: actorIsPayer,
  currency: 'TWD',
  description: description,
  createdAt: '2026-08-01T10:30:00.000Z',
);

Widget _row(SplitActivity entry, {String? selfUserId = _self}) => l10nTestApp(
  home: Scaffold(
    body: SplitActivityRow(
      entry: entry,
      selfUserId: selfUserId,
      // Pinned to UTC so the rendered time is the same under TZ=UTC (CI) and
      // UTC+8 (this machine).
      toLocalTime: (instant) => instant.toUtc(),
    ),
  ),
);

final _loc = lookupAppLocalizations(const Locale('en'));

void main() {
  group('SplitActivityRow — the subject of each event type', () {
    // Each type gets its own wording; none may fall through to a generic
    // "someone changed something", which is the whole point of a change log.
    final cases = <({
      String name,
      SplitActivity entry,
      String asReader,
      String asOther,
    })>[
      (
        name: 'expense created',
        entry: _entry(type: SplitActivityType.expenseCreated),
        asReader: _loc.splitActivityExpenseCreatedYou('Dinner'),
        asOther: _loc.splitActivityExpenseCreatedOther('Amy', 'Dinner'),
      ),
      (
        name: 'expense updated',
        entry: _entry(type: SplitActivityType.expenseUpdated),
        asReader: _loc.splitActivityExpenseUpdatedYou('Dinner'),
        asOther: _loc.splitActivityExpenseUpdatedOther('Amy', 'Dinner'),
      ),
      (
        name: 'expense deleted',
        entry: _entry(type: SplitActivityType.expenseDeleted),
        asReader: _loc.splitActivityExpenseDeletedYou('Dinner'),
        asOther: _loc.splitActivityExpenseDeletedOther('Amy', 'Dinner'),
      ),
      (
        name: 'settlement created',
        entry: _entry(type: SplitActivityType.settlementCreated, actorIsPayer: true),
        asReader: _loc.splitActivitySettlementCreatedYou,
        asOther: _loc.splitActivitySettlementCreatedOther('Amy'),
      ),
      (
        name: 'settlement deleted',
        entry: _entry(type: SplitActivityType.settlementDeleted, actorIsPayer: true),
        asReader: _loc.splitActivitySettlementDeletedYou,
        asOther: _loc.splitActivitySettlementDeletedOther('Amy'),
      ),
      (
        name: 'group created',
        entry: _entry(type: SplitActivityType.groupCreated, amount: null),
        asReader: _loc.splitActivityGroupCreatedYou('Trip'),
        asOther: _loc.splitActivityGroupCreatedOther('Amy', 'Trip'),
      ),
      (
        name: 'group member added',
        entry: _entry(type: SplitActivityType.groupMemberAdded, amount: null),
        asReader: _loc.splitActivityGroupMemberAddedYou('Ben', 'Trip'),
        asOther: _loc.splitActivityGroupMemberAddedOther('Amy', 'Ben', 'Trip'),
      ),
      (
        name: 'group archived',
        entry: _entry(type: SplitActivityType.groupArchived, amount: null),
        asReader: _loc.splitActivityGroupArchivedYou('Trip'),
        asOther: _loc.splitActivityGroupArchivedOther('Amy', 'Trip'),
      ),
      (
        // The ninth: a type this build does not know, from a backend that
        // ships on its own schedule. Neutral wording, but still a row —
        // and still the actor and the time.
        name: 'an unrecognised type',
        entry: _entry(type: SplitActivityType.unknown, amount: null),
        asReader: _loc.splitActivityUnknownYou,
        asOther: _loc.splitActivityUnknownOther('Amy'),
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.name}: the actor is "you" when it is the reader', (tester) async {
        await tester.pumpWidget(_row(c.entry, selfUserId: 'u-amy'));
        expect(find.text(c.asReader), findsOneWidget);
        expect(find.text(c.asOther), findsNothing);
      });

      testWidgets('${c.name}: the actor is named when it is not the reader', (tester) async {
        await tester.pumpWidget(_row(c.entry, selfUserId: _self));
        expect(find.text(c.asOther), findsOneWidget);
        expect(find.text(c.asReader), findsNothing);
      });
    }
  });

  group('SplitActivityRow — the reader as the second person', () {
    // The actor is not the only person a row names. Repayments were given
    // "you" already; `group_member_added` is the other type the backend
    // fills a counterpart on, and it had the identical bug — the reader's
    // own display name, in the third person, on the row that tells them they
    // were added to a group.
    testWidgets('being added to a group reads as "you", not as your own name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _row(
          _entry(
            type: SplitActivityType.groupMemberAdded,
            amount: null,
            counterpartUserId: _self,
            counterpartDisplayName: 'Self',
          ),
          selfUserId: _self,
        ),
      );

      expect(find.text(_loc.splitActivityGroupMemberAddedYouWere('Amy', 'Trip')), findsOneWidget);
      expect(
        find.text(_loc.splitActivityGroupMemberAddedOther('Amy', 'Self', 'Trip')),
        findsNothing,
      );
    });

    testWidgets('someone else being added still names them', (tester) async {
      await tester.pumpWidget(
        _row(_entry(type: SplitActivityType.groupMemberAdded, amount: null), selfUserId: _self),
      );
      expect(
        find.text(_loc.splitActivityGroupMemberAddedOther('Amy', 'Ben', 'Trip')),
        findsOneWidget,
      );
    });
  });

  group('SplitActivityRow — an unresolved reader is nobody', () {
    testWidgets('a null self id never renders the actor as "you"', (tester) async {
      // `selfUserId` is null until the profile resolves. Treating that as a
      // match would tell every reader they made the change themselves.
      await tester.pumpWidget(
        _row(_entry(type: SplitActivityType.expenseCreated), selfUserId: null),
      );
      expect(
        find.text(_loc.splitActivityExpenseCreatedOther('Amy', 'Dinner')),
        findsOneWidget,
      );
      expect(find.text(_loc.splitActivityExpenseCreatedYou('Dinner')), findsNothing);
    });
  });

  group('SplitActivityRow — repayment direction', () {
    testWidgets('the reader who paid reads that they paid', (tester) async {
      await tester.pumpWidget(
        _row(
          _entry(type: SplitActivityType.settlementCreated, actorIsPayer: true),
          selfUserId: 'u-amy',
        ),
      );
      expect(find.text(_loc.splitActivityRepaymentYouPaid('Ben')), findsOneWidget);
    });

    testWidgets('the reader who was paid reads that the other paid them', (tester) async {
      await tester.pumpWidget(
        _row(
          _entry(type: SplitActivityType.settlementCreated, actorIsPayer: true),
          selfUserId: 'u-ben',
        ),
      );
      expect(find.text(_loc.splitActivityRepaymentPaidYou('Amy')), findsOneWidget);
    });

    testWidgets('a group third party reads both names and which paid', (tester) async {
      await tester.pumpWidget(
        _row(
          _entry(type: SplitActivityType.settlementCreated, actorIsPayer: false),
          selfUserId: 'u-cara',
        ),
      );
      expect(find.text(_loc.splitActivityRepaymentBetween('Ben', 'Amy')), findsOneWidget);
    });

    testWidgets('a deleted repayment still states its direction and amount', (tester) async {
      await tester.pumpWidget(
        _row(
          _entry(type: SplitActivityType.settlementDeleted, actorIsPayer: true, description: null),
          selfUserId: 'u-amy',
        ),
      );
      expect(find.text(_loc.splitActivitySettlementDeletedYou), findsOneWidget);
      expect(find.text(_loc.splitActivityRepaymentYouPaid('Ben')), findsOneWidget);
      expect(find.text('2,000'), findsOneWidget);
    });

    testWidgets('an expense entry carries no direction line', (tester) async {
      await tester.pumpWidget(_row(_entry(type: SplitActivityType.expenseCreated)));
      expect(find.text(_loc.splitActivityRepaymentYouPaid('Ben')), findsNothing);
      expect(find.text(_loc.splitActivityRepaymentBetween('Amy', 'Ben')), findsNothing);
    });
  });

  group('SplitActivityRow — amounts', () {
    testWidgets('an edit that moved the amount shows what it was and what it became', (
      tester,
    ) async {
      await tester.pumpWidget(
        _row(_entry(type: SplitActivityType.expenseUpdated, amount: 2000, previousAmount: 1500)),
      );
      expect(
        find.text(_loc.splitActivityAmountChange('1,500', '2,000')),
        findsOneWidget,
      );
    });

    testWidgets('an edit that left the amount alone shows no arrow', (tester) async {
      // `previous_amount` is written by *every* edit, so `!= null` would
      // render "NT$20 → NT$20" on an edit that only touched the description.
      await tester.pumpWidget(
        _row(_entry(type: SplitActivityType.expenseUpdated, amount: 2000, previousAmount: 2000)),
      );
      expect(
        find.text(_loc.splitActivityAmountChange('2,000', '2,000')),
        findsNothing,
      );
      expect(find.text('2,000'), findsOneWidget);
    });

    testWidgets('a deleted expense still shows its amount and description', (tester) async {
      await tester.pumpWidget(
        _row(_entry(type: SplitActivityType.expenseDeleted), selfUserId: _self),
      );
      expect(
        find.text(_loc.splitActivityExpenseDeletedOther('Amy', 'Dinner')),
        findsOneWidget,
      );
      expect(find.text('2,000'), findsOneWidget);
    });
  });

  group('SplitActivityRow — names are never raw ids', () {
    testWidgets('an actor with no name renders the placeholder, not their user id', (
      tester,
    ) async {
      // The backend fills `actor_display_name` with the raw user id when it
      // has nothing better, so `?? placeholder` can never fire and the id
      // reaches the screen. The test is `actorDisplayName == actorUserId`.
      await tester.pumpWidget(
        _row(
          _entry(
            type: SplitActivityType.expenseCreated,
            actorUserId: 'u-amy',
            actorDisplayName: 'u-amy',
          ),
          selfUserId: _self,
        ),
      );
      expect(
        find.text(_loc.splitActivityExpenseCreatedOther(_loc.splitUnknownMember, 'Dinner')),
        findsOneWidget,
      );
      expect(find.textContaining('u-amy'), findsNothing);
    });

    testWidgets('a counterpart with no name renders the placeholder', (tester) async {
      await tester.pumpWidget(
        _row(
          _entry(
            type: SplitActivityType.settlementCreated,
            actorIsPayer: true,
            counterpartDisplayName: null,
          ),
          selfUserId: 'u-amy',
        ),
      );
      expect(
        find.text(_loc.splitActivityRepaymentYouPaid(_loc.splitUnknownMember)),
        findsOneWidget,
      );
      expect(find.textContaining('u-ben'), findsNothing);
    });
  });

  group('SplitActivityRow — not an editable row', () {
    testWidgets('the row offers no tap target', (tester) async {
      await tester.pumpWidget(_row(_entry(type: SplitActivityType.expenseDeleted)));
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.onTap, isNull);
      expect(tile.trailing, isNull);
    });
  });

  group('SplitActivityRow — time and screen readers', () {
    testWidgets('shows the local date and time the change was recorded', (tester) async {
      await tester.pumpWidget(_row(_entry(type: SplitActivityType.expenseCreated)));
      final context = tester.element(find.byType(SplitActivityRow));
      expect(
        find.text('${mediumDateLabelOrDash(context, '2026-08-01')} 10:30'),
        findsOneWidget,
      );
    });

    testWidgets('the whole row is offered to a screen reader as one sentence', (tester) async {
      final entry = _entry(type: SplitActivityType.settlementCreated, actorIsPayer: true);
      await tester.pumpWidget(_row(entry, selfUserId: 'u-amy'));
      final context = tester.element(find.byType(SplitActivityRow));
      final time = '${mediumDateLabelOrDash(context, '2026-08-01')} 10:30';

      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('split-activity-semantics-a1')),
      );
      expect(
        semantics.properties.label,
        _loc.splitActivityRowSemantics(
          _loc.splitActivityRowDetail(
            _loc.splitActivitySettlementCreatedYou,
            _loc.splitActivityRepaymentYouPaid('Ben'),
          ),
          '2,000',
          time,
        ),
      );
      expect(semantics.excludeSemantics, isTrue);
    });

    testWidgets('an edit is spoken as "from X to Y", not as the painted arrow', (tester) async {
      // "1,500 → 2,000" reaches a screen reader as two numbers with the
      // arrow named as a glyph or dropped entirely — either way the listener
      // is told both amounts and never which one is now true.
      final entry = _entry(
        type: SplitActivityType.expenseUpdated,
        amount: 2000,
        previousAmount: 1500,
      );
      await tester.pumpWidget(_row(entry, selfUserId: 'u-amy'));
      final context = tester.element(find.byType(SplitActivityRow));

      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('split-activity-semantics-a1')),
      );
      expect(
        semantics.properties.label,
        _loc.splitActivityRowSemantics(
          _loc.splitActivityExpenseUpdatedYou('Dinner'),
          _loc.splitActivityAmountChangeSpoken('1,500', '2,000'),
          '${mediumDateLabelOrDash(context, '2026-08-01')} 10:30',
        ),
      );
      // The painted row keeps the arrow — this is a wording for speech, not
      // a replacement of the visual form.
      expect(find.text(_loc.splitActivityAmountChange('1,500', '2,000')), findsOneWidget);
    });

    testWidgets('an entry with no amount is not read with an empty amount slot', (tester) async {
      final entry = _entry(type: SplitActivityType.groupArchived, amount: null);
      await tester.pumpWidget(_row(entry, selfUserId: 'u-amy'));
      final context = tester.element(find.byType(SplitActivityRow));
      final semantics = tester.widget<Semantics>(
        find.byKey(const Key('split-activity-semantics-a1')),
      );
      expect(
        semantics.properties.label,
        _loc.splitActivityRowSemanticsNoAmount(
          _loc.splitActivityGroupArchivedYou('Trip'),
          '${mediumDateLabelOrDash(context, '2026-08-01')} 10:30',
        ),
      );
    });
  });
}
