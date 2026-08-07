import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/installment_plan.dart';
import 'package:life_os/contexts/finance/presentation/installment_plan_screen.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

/// Settling hangs on `mode` (installments-ui tasks 5.2): only a total-mode
/// payoff is computable by the system (the remaining periods sum to it); a
/// per-instalment payoff must be copied from the bank, because remaining ×
/// per-period would wrongly include future interest.
///
/// **Both directions are pinned** (tasks 5.3/5.4): with only one of the two
/// tests, "always ask for an amount" or "never ask" each passes the
/// remaining test — the pair is what makes the mode branch unavoidable.
const _perInstallmentPlan = InstallmentPlan(
  id: 'plan-mortgage',
  mode: InstallmentMode.perInstallment,
  periods: 240,
  startDay: '2026-01-10',
  amount: 32148,
  currency: 'TWD',
  categoryId: 'cat-transport',
  note: '房貸',
);

const _totalPlan = InstallmentPlan(
  id: 'plan-card',
  mode: InstallmentMode.total,
  periods: 12,
  startDay: '2026-05-15',
  amount: 60000,
  currency: 'TWD',
  categoryId: 'cat-food',
);

Future<FakeFinanceRepository> pumpPlanScreen(
  WidgetTester tester,
  InstallmentPlan plan,
) async {
  final repo = FakeFinanceRepository()..plansById[plan.id] = plan;
  await tester.pumpWidget(
    l10nTestApp(
      home: InstallmentPlanScreen(
        plan: plan,
        repository: repo,
        idToken: () async => 'tok',
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('InstallmentPlanScreen — settling', () {
    testWidgets(
      'a per-instalment plan asks for the amount from the bank and sends it '
      '(tasks 5.3)',
      (tester) async {
        final repo = await pumpPlanScreen(tester, _perInstallmentPlan);

        expect(
          find.byKey(const Key('installment-settle-button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('installment-settle-button')));
        await tester.pumpAndSettle();

        // The ask: the system cannot compute this payoff, the bank's figure
        // is required.
        expect(
          find.byKey(const Key('installment-settle-amount-field')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('installment-settle-amount-field')),
          '500000',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('installment-settle-confirm')));
        await tester.pumpAndSettle();

        final call = repo.installmentSettleCalls.single;
        expect(call.planId, 'plan-mortgage');
        expect(
          call.amount,
          500000,
          reason:
              'the backend requires `amount` for a per_installment settle — '
              'sending none is a 400, computing one locally is wrong money',
        );
      },
    );

    testWidgets(
      'a total plan does not ask — the system computes it and no amount is '
      'sent (tasks 5.4)',
      (tester) async {
        final repo = await pumpPlanScreen(tester, _totalPlan);

        expect(
          find.byKey(const Key('installment-settle-button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('installment-settle-button')));
        await tester.pumpAndSettle();

        // No ask: the remaining periods sum to the payoff, and prompting the
        // user for a number the system already knows invites a wrong one.
        expect(
          find.byKey(const Key('installment-settle-amount-field')),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('installment-settle-confirm')));
        await tester.pumpAndSettle();

        final call = repo.installmentSettleCalls.single;
        expect(call.planId, 'plan-card');
        expect(
          call.amount,
          isNull,
          reason:
              'the backend ignores `amount` on a total-mode settle; sending '
              'one means the UI asked for it, which is the "always ask" '
              'mutation this test exists to block',
        );
      },
    );
  });
}
