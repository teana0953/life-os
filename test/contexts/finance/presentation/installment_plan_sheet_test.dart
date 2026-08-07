import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/installment_plan.dart';
import 'package:life_os/contexts/finance/presentation/installment_plan_sheet.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

/// The 定期扣款 create entry (installments-ui tasks 3.x). The two modes'
/// **inputs mean different things** (tasks 3.2): total mode asks "how much
/// altogether", per-instalment mode asks "how much per period". A form that
/// only swaps a label reuses one field's meaning for both, and the user who
/// picks the wrong one gets a plan 12× or 1/12 off with no error anywhere —
/// which is why both directions below pin the `(mode, amount)` PAIR that
/// reaches the repository, not either half alone.
Future<void> pumpPlanSheet(
  WidgetTester tester,
  FakeFinanceRepository repo,
) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: InstallmentPlanSheet(
          repository: repo,
          idToken: () async => 'tok',
          categories: repo.categoriesToReturn,
          today: '2026-07-15',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('InstallmentPlanSheet', () {
    testWidgets(
      'per-instalment mode submits the per-period amount — not the total '
      '(tasks 3.3)',
      (tester) async {
        final repo = FakeFinanceRepository();
        await pumpPlanSheet(tester, repo);

        // 房貸: 每期 32,148 × 240 期. What is typed is the per-period figure.
        expect(find.byKey(const Key('installment-mode-per')), findsOneWidget);
        await tester.tap(find.byKey(const Key('installment-mode-per')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('installment-amount-field')),
          '32148',
        );
        await tester.enterText(
          find.byKey(const Key('installment-periods-field')),
          '240',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('finance-category-cat-transport')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('installment-save-button')));
        await tester.pumpAndSettle();

        final sent = repo.installmentPlanCreates.single;
        expect(sent.mode, InstallmentMode.perInstallment);
        expect(
          sent.amount,
          32148,
          reason:
              'per-instalment mode sends the per-period amount; sending '
              'amount × periods (7,715,520) or the total-mode meaning would '
              'create a silently wrong plan',
        );
        expect(sent.periods, 240);
      },
    );

    testWidgets(
      'total mode submits the total amount under mode total (tasks 3.3, the '
      'other direction of the pair)',
      (tester) async {
        // Without this companion, hard-coding `mode: per_installment`
        // everywhere would pass the test above.
        final repo = FakeFinanceRepository();
        await pumpPlanSheet(tester, repo);

        // 信用卡分期: 總共 60,000 分 12 期. What is typed is the whole sum.
        expect(find.byKey(const Key('installment-mode-total')), findsOneWidget);
        await tester.tap(find.byKey(const Key('installment-mode-total')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('installment-amount-field')),
          '60000',
        );
        await tester.enterText(
          find.byKey(const Key('installment-periods-field')),
          '12',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('finance-category-cat-food')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('installment-save-button')));
        await tester.pumpAndSettle();

        final sent = repo.installmentPlanCreates.single;
        expect(sent.mode, InstallmentMode.total);
        expect(sent.amount, 60000);
        expect(sent.periods, 12);
      },
    );
  });
}
