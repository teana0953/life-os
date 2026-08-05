import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/presentation/add_transaction_sheet.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeFinanceRepository repo,
  FinanceTransaction? editing,
  String today = '2026-07-15',
  Future<String> Function()? idToken,
}) async {
  final controller = testFinanceController(repo);
  // The controller needs categories loaded so the sheet's grid has options.
  await controller.load('tok', '2026-07');

  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => AddTransactionSheet(
                controller: controller,
                idToken: idToken ?? () async => 'tok',
                categories: controller.categories,
                today: today,
                editing: editing,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('AddTransactionSheet', () {
    testWidgets('save is disabled while the amount is empty', (tester) async {
      await pumpSheet(tester, repo: FakeFinanceRepository());

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('save-transaction-button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'save is disabled with an amount but no category chosen',
      (tester) async {
        await pumpSheet(tester, repo: FakeFinanceRepository());

        await tester.enterText(find.byKey(const Key('amount-field')), '120');
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const Key('save-transaction-button')),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'save is enabled once amount and category are both set',
      (tester) async {
        await pumpSheet(tester, repo: FakeFinanceRepository());

        await tester.enterText(find.byKey(const Key('amount-field')), '120');
        await tester.pump();
        await tester.tap(find.byKey(const Key('finance-category-cat-food')));
        await tester.pump();

        final button = tester.widget<FilledButton>(
          find.byKey(const Key('save-transaction-button')),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'a token renewal that throws leaves the sheet usable — the Save button '
      'must not latch off with the typed transaction stranded',
      (tester) async {
        // `getIdToken()` reaches the network once the token nears expiry and
        // throws when that fails. `_save` sets `_saving = true` before the
        // first await, so an escaping throw used to leave `onPressed: null`
        // for good: no write, no message, the typed amount still on screen,
        // and the only way out was to dismiss the sheet and lose it.
        await pumpSheet(
          tester,
          repo: FakeFinanceRepository(),
          idToken: () async => throw Exception('token renewal failed'),
        );

        await tester.enterText(find.byKey(const Key('amount-field')), '250');
        await tester.pump();
        await tester.tap(find.byKey(const Key('finance-category-cat-food')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        // No escaping async error, and the user is told the save failed
        // rather than left staring at an unchanged sheet.
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsOneWidget);
        // The sheet is still there and the button is usable again, so the
        // typed transaction is not stranded.
        expect(find.byKey(const Key('amount-field')), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.byKey(const Key('save-transaction-button')),
        );
        expect(
          button.onPressed,
          isNotNull,
          reason: 'a failed save must not latch the submit button off',
        );
      },
    );

    testWidgets(
      'saving records the fast-default-path transaction (TWD expense, today) and closes',
      (tester) async {
        final repo = FakeFinanceRepository();
        await pumpSheet(tester, repo: repo, today: '2026-07-15');

        await tester.enterText(find.byKey(const Key('amount-field')), '250');
        await tester.pump();
        await tester.tap(find.byKey(const Key('finance-category-cat-food')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        // Sheet closed on success.
        expect(find.byKey(const Key('save-transaction-button')), findsNothing);

        final saved = repo.byMonth['2026-07']!.single;
        expect(saved.type, FinanceType.expense);
        expect(saved.amount, 250);
        expect(saved.currency, 'TWD');
        expect(saved.categoryId, 'cat-food');
        expect(saved.date, '2026-07-15');
      },
    );

    testWidgets(
      'a save failure keeps the sheet open with the entered content and shows an error',
      (tester) async {
        final repo = FakeFinanceRepository();
        await pumpSheet(tester, repo: repo);

        await tester.enterText(find.byKey(const Key('amount-field')), '250');
        await tester.pump();
        await tester.tap(find.byKey(const Key('finance-category-cat-food')));
        await tester.pump();
        repo.failNext = const FinanceFetchFailure('boom');
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        // Sheet stays open — the amount typed is still there.
        expect(find.byKey(const Key('save-transaction-button')), findsOneWidget);
        expect(find.text('250'), findsOneWidget);
        expect(repo.byMonth['2026-07'], isNull);
        // A snackbar surfaces the failure.
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'editing an existing transaction pre-fills its fields and shows delete',
      (tester) async {
        final repo = FakeFinanceRepository();
        const editing = FinanceTransaction(
          id: 'seed-1',
          type: FinanceType.expense,
          amount: 300,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-10',
          note: 'lunch',
        );
        await pumpSheet(tester, repo: repo, editing: editing);

        expect(find.text('300'), findsOneWidget);
        expect(find.text('lunch'), findsOneWidget);
        expect(find.byKey(const Key('finance-delete-button')), findsOneWidget);
      },
    );

    testWidgets('deleting an existing transaction removes it and closes', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 'seed-1',
            type: FinanceType.expense,
            amount: 300,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-10',
          ),
        ];
      const editing = FinanceTransaction(
        id: 'seed-1',
        type: FinanceType.expense,
        amount: 300,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-10',
      );
      await pumpSheet(tester, repo: repo, editing: editing);

      await tester.tap(find.byKey(const Key('finance-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finance-delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('save-transaction-button')), findsNothing);
      expect(repo.byMonth['2026-07'], isEmpty);
    });
  });
}
