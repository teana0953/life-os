import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/presentation/finance_transactions_tab.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

void main() {
  group('FinanceTransactionsTab', () {
    testWidgets('empty month shows the empty state', (tester) async {
      final controller = testFinanceController(FakeFinanceRepository());
      await controller.load('tok', '2026-07');

      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: FinanceTransactionsTab(
              controller: controller,
              onEdit: (_) {},
              onSwitchMonth: (m) async {},
              onSignInAgain: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance-transactions-empty')), findsOneWidget);
    });

    testWidgets('groups transactions by day, newest day first', (tester) async {
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 't-early',
            type: FinanceType.expense,
            amount: 100,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-05',
          ),
          const FinanceTransaction(
            id: 't-late',
            type: FinanceType.expense,
            amount: 200,
            currency: 'TWD',
            categoryId: 'cat-transport',
            date: '2026-07-20',
            note: 'taxi',
          ),
        ];
      final controller = testFinanceController(repo);
      await controller.load('tok', '2026-07');

      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: FinanceTransactionsTab(
              controller: controller,
              onEdit: (_) {},
              onSwitchMonth: (m) async {},
              onSignInAgain: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Day headers present, newest first.
      final dayHeaders = find.text('2026-07-20');
      final earlierHeader = find.text('2026-07-05');
      expect(dayHeaders, findsOneWidget);
      expect(earlierHeader, findsOneWidget);
      final laterY = tester.getTopLeft(dayHeaders).dy;
      final earlierY = tester.getTopLeft(earlierHeader).dy;
      expect(laterY, lessThan(earlierY));

      expect(find.text('taxi'), findsOneWidget);
      expect(find.text('-200'), findsOneWidget);
      expect(find.text('-100'), findsOneWidget);
    });

    testWidgets('tapping a row invokes onEdit with that transaction', (
      tester,
    ) async {
      const txn = FinanceTransaction(
        id: 'seed-1',
        type: FinanceType.expense,
        amount: 300,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-10',
      );
      final repo = FakeFinanceRepository()..byMonth['2026-07'] = [txn];
      final controller = testFinanceController(repo);
      await controller.load('tok', '2026-07');
      FinanceTransaction? edited;

      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: FinanceTransactionsTab(
              controller: controller,
              onEdit: (t) => edited = t,
              onSwitchMonth: (m) async {},
              onSignInAgain: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-transaction-seed-1')));
      await tester.pump();

      expect(edited?.id, 'seed-1');
    });
  });
}
