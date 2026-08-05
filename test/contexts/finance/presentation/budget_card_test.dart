import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/presentation/budget_card.dart';
import 'package:life_os/contexts/finance/presentation/budget_sheet.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

/// Pumps [BudgetCard] with [budgets] forced onto the loaded controller so the
/// three-tier color test can pin an exact backend `percent` regardless of the
/// spent/amount arithmetic (design.md: color follows the backend integer
/// percent, never a value recomputed on the frontend).
Future<FinanceController> pumpCard(
  WidgetTester tester, {
  required FakeFinanceRepository repo,
  List<FinanceBudget> budgets = const [],
  VoidCallback? onEdit,
}) async {
  final controller = testFinanceController(repo);
  await controller.load('tok', '2026-07');
  controller.budgets = budgets;

  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: Scaffold(
        body: BudgetCard(controller: controller, onEdit: onEdit ?? () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

FinanceBudget _budget({
  required String id,
  String? categoryId,
  required int amount,
  required int percent,
}) => FinanceBudget(
  id: id,
  categoryId: categoryId,
  amount: amount,
  spent: (amount * percent) ~/ 100,
  remaining: amount - (amount * percent) ~/ 100,
  percent: percent,
);

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));
  final scheme = lightTheme.colorScheme;

  Color colorOfPercentText(WidgetTester tester, String percentText) {
    final text = tester.widget<Text>(find.text(percentText));
    return text.style!.color!;
  }

  group('BudgetCard three-tier color (backend integer percent)', () {
    testWidgets('percent 79 is normal (primary)', (tester) async {
      await pumpCard(
        tester,
        repo: FakeFinanceRepository(),
        budgets: [_budget(id: 'b1', categoryId: 'cat-food', amount: 100, percent: 79)],
      );

      expect(colorOfPercentText(tester, '79%'), scheme.primary);
      expect(find.byKey(const Key('budget-over-label')), findsNothing);
    });

    testWidgets('percent 80 crosses into the warning color', (tester) async {
      await pumpCard(
        tester,
        repo: FakeFinanceRepository(),
        budgets: [_budget(id: 'b1', categoryId: 'cat-food', amount: 100, percent: 80)],
      );

      expect(
        colorOfPercentText(tester, '80%'),
        financeBudgetWarningColor(scheme),
      );
      expect(find.byKey(const Key('budget-over-label')), findsNothing);
    });

    testWidgets('percent 100 is error and carries the over-budget label', (
      tester,
    ) async {
      await pumpCard(
        tester,
        repo: FakeFinanceRepository(),
        budgets: [_budget(id: 'b1', categoryId: 'cat-food', amount: 100, percent: 100)],
      );

      expect(colorOfPercentText(tester, '100%'), scheme.error);
      expect(find.byKey(const Key('budget-over-label')), findsOneWidget);
      expect(find.text(loc.financeBudgetOverLabel), findsOneWidget);
    });
  });

  group('BudgetCard empty state', () {
    testWidgets('with no budgets shows the guide and CTA', (tester) async {
      await pumpCard(tester, repo: FakeFinanceRepository());

      expect(find.byKey(const Key('budget-empty-title')), findsOneWidget);
      expect(find.byKey(const Key('budget-empty-cta')), findsOneWidget);
      expect(find.text(loc.financeBudgetEmptyTitle), findsOneWidget);
    });

    testWidgets('tapping the empty-state CTA opens the budget sheet', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);
      await controller.load('tok', '2026-07');

      await tester.pumpWidget(
        l10nTestApp(
          theme: lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => BudgetCard(
                controller: controller,
                onEdit: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      BudgetSheet(controller: controller, idToken: () async => 'tok'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('budget-empty-cta')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('budget-sheet-save')), findsOneWidget);
    });
  });
}
