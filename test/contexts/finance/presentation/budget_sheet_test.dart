import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/presentation/budget_sheet.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

/// Opens [BudgetSheet] over a button so it rides in a real modal route
/// (matching production and letting a save close it). The controller is loaded
/// for 2026-07 first so its categories/budgets seed the sheet's rows.
Future<FinanceController> pumpSheet(
  WidgetTester tester, {
  required FakeFinanceRepository repo,
}) async {
  final controller = testFinanceController(repo);
  await controller.load('tok', '2026-07');

  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BudgetSheet(controller: controller, idToken: 'tok'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  testWidgets('batch save sends only the diff (1 upsert + 1 delete)', (
    tester,
  ) async {
    // Start with an overall budget and a 餐飲 (cat-food) budget already set.
    final repo = FakeFinanceRepository()
      ..seedBudget(amount: 10000)
      ..seedBudget(categoryId: 'cat-food', amount: 3000);
    final controller = await pumpSheet(tester, repo: repo);

    // Change the overall budget (upsert) and clear the 餐飲 budget (delete);
    // leave 交通 (cat-transport, never set) untouched — sends nothing.
    await tester.enterText(find.byKey(const Key('budget-field-total')), '12000');
    await tester.enterText(find.byKey(const Key('budget-field-cat-food')), '');
    await tester.pump();

    repo.budgetCalls.clear();
    await tester.tap(find.byKey(const Key('budget-sheet-save')));
    await tester.pumpAndSettle();

    // Exactly one upsert (overall → 12000) and one delete (cat-food's budget).
    expect(repo.budgetCalls.where((c) => c.startsWith('upsert:')), hasLength(1));
    expect(repo.budgetCalls.where((c) => c.startsWith('delete:')), hasLength(1));
    expect(repo.budgetCalls, contains('upsert:null:12000'));
    // The sheet closed on success.
    expect(find.byKey(const Key('budget-sheet-save')), findsNothing);
    expect(controller.status, FinanceStatus.loaded);
  });

  testWidgets(
    'partial failure reloads, keeps the sheet open with entered values, and a '
    'retry does not re-send the already-applied change',
    (tester) async {
      final repo = FakeFinanceRepository()
        ..seedBudget(amount: 10000)
        ..seedBudget(categoryId: 'cat-food', amount: 3000);
      final controller = await pumpSheet(tester, repo: repo);

      // Change overall (upsert) and clear cat-food (delete). Rows are built
      // overall-first, so the diff is applied in that order: upsert = call #1,
      // delete = call #2. Fail on the 2nd write (the delete) — so the upsert
      // applies and the delete is the step left pending.
      await tester.enterText(
        find.byKey(const Key('budget-field-total')),
        '12000',
      );
      await tester.enterText(find.byKey(const Key('budget-field-cat-food')), '');
      await tester.pump();

      repo.budgetCalls.clear();
      repo.failOnBudgetCallNumber = 2;
      await tester.tap(find.byKey(const Key('budget-sheet-save')));
      await tester.pumpAndSettle();

      // The upsert applied, the delete failed → both were attempted once.
      expect(
        repo.budgetCalls.where((c) => c.startsWith('upsert:')),
        hasLength(1),
      );
      expect(
        repo.budgetCalls.where((c) => c.startsWith('delete:')),
        hasLength(1),
      );

      // Sheet stayed open; the entered values are preserved.
      expect(find.byKey(const Key('budget-sheet-save')), findsOneWidget);
      expect(find.text(loc.financeSaveFailed), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('budget-field-total')))
            .controller!
            .text,
        '12000',
      );

      // The upsert already applied to the reloaded state — overall is 12000.
      final overall =
          controller.budgets.firstWhere((b) => b.categoryId == null);
      expect(overall.amount, 12000);
      // The delete didn't apply — cat-food is still there.
      expect(controller.budgets.any((b) => b.categoryId == 'cat-food'), isTrue);

      // Retry: only the still-pending delete should go out — the applied
      // upsert must not be re-sent (design.md: retry never re-sends, diff
      // baseline reset to the reloaded state).
      repo.budgetCalls.clear();
      await tester.tap(find.byKey(const Key('budget-sheet-save')));
      await tester.pumpAndSettle();

      expect(repo.budgetCalls.where((c) => c.startsWith('upsert:')), isEmpty);
      expect(repo.budgetCalls.where((c) => c.startsWith('delete:')), hasLength(1));
      // Now succeeds and closes.
      expect(find.byKey(const Key('budget-sheet-save')), findsNothing);
      expect(controller.budgets.any((b) => b.categoryId == 'cat-food'), isFalse);
    },
  );
}
