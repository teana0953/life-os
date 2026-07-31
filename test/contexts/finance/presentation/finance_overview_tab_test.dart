import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/presentation/finance_overview_tab.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

Future<void> pumpOverview(
  WidgetTester tester,
  FakeFinanceRepository repo, {
  String month = '2026-07',
}) async {
  final controller = testFinanceController(repo);
  await controller.load('tok', month);

  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: FinanceOverviewTab(
          controller: controller,
          onSwitchMonth: (m) async {},
          onAdd: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FinanceOverviewTab', () {
    testWidgets('empty month shows the empty-state CTA', (tester) async {
      await pumpOverview(tester, FakeFinanceRepository());

      expect(find.byKey(const Key('finance-empty-title')), findsOneWidget);
      expect(find.byKey(const Key('finance-empty-cta')), findsOneWidget);
    });

    testWidgets('tapping the empty-state CTA opens the record sheet', (
      tester,
    ) async {
      var tapped = false;
      final controller = testFinanceController(FakeFinanceRepository());
      await controller.load('tok', '2026-07');
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: FinanceOverviewTab(
              controller: controller,
              onSwitchMonth: (m) async {},
              onAdd: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-empty-cta')));
      expect(tapped, isTrue);
    });

    testWidgets(
      'shows expense/income/net totals per currency, one row per currency',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..byMonth['2026-07'] = [
            const FinanceTransaction(
              id: 't1',
              type: FinanceType.expense,
              amount: 300,
              currency: 'TWD',
              categoryId: 'cat-food',
              date: '2026-07-05',
            ),
            const FinanceTransaction(
              id: 't2',
              type: FinanceType.income,
              amount: 50000,
              currency: 'TWD',
              categoryId: 'cat-salary',
              date: '2026-07-01',
            ),
            const FinanceTransaction(
              id: 't3',
              type: FinanceType.expense,
              amount: 1000,
              currency: 'USD',
              categoryId: 'cat-food',
              date: '2026-07-10',
            ),
          ];
        await pumpOverview(tester, repo);

        // Two currency cards — TWD and USD — never merged.
        expect(find.text('TWD'), findsOneWidget);
        expect(find.text('USD'), findsOneWidget);
        expect(find.text('300'), findsWidgets); // TWD expense (card + breakdown/recent)
        expect(find.text('50000'), findsOneWidget); // TWD income
        expect(find.text('10.00'), findsWidgets); // USD expense
      },
    );

    testWidgets('shows the month label from the controller', (tester) async {
      await pumpOverview(tester, FakeFinanceRepository(), month: '2026-09');

      expect(find.text('2026-09'), findsOneWidget);
    });
  });
}
