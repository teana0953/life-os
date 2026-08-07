import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/presentation/add_transaction_sheet.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';
import '../finance_test_support.dart';

/// A mirrored row and the self-recorded one it has to be told apart from.
/// Both are needed in the same fixture wherever "the mirror is locked" is
/// asserted — a sheet that locks *every* transaction passes half of these
/// on its own.
const _mirror = FinanceTransaction(
  id: 'mirror-1',
  type: FinanceType.expense,
  amount: 900,
  currency: 'TWD',
  categoryId: 'cat-food',
  date: '2026-07-15',
  note: '晚餐',
  splitExpenseId: 'exp-1',
);

const _selfRecorded = FinanceTransaction(
  id: 'own-1',
  type: FinanceType.expense,
  amount: 300,
  currency: 'TWD',
  categoryId: 'cat-food',
  date: '2026-07-10',
  note: 'lunch',
);

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

/// Returns the controller the sheet was given, so a test can assert on the
/// month it reloaded (the 409 path) as well as on the sheet.
Future<FinanceController> pumpSheet(
  WidgetTester tester, {
  required FakeFinanceRepository repo,
  FinanceTransaction? editing,
  String today = '2026-07-15',
  Future<String> Function()? idToken,
  VoidCallback? onGoToSplit,
  FinanceController? withController,
}) async {
  final controller = withController ?? testFinanceController(repo);
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
                onGoToSplit: onGoToSplit ?? () {},
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
  return controller;
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

  group('AddTransactionSheet — a mirrored transaction', () {
    // Growable, never `const`: `FakeFinanceRepository` mutates these lists in
    // place on every write, and a const list makes `removeWhere` throw into a
    // swallowed catch — leaving the month exactly as seeded and every write
    // assertion vacuously true.
    FakeFinanceRepository seeded() =>
        FakeFinanceRepository()..byMonth['2026-07'] = [_mirror, _selfRecorded];

    testWidgets(
      'shows the amount, date, currency and type as facts — not as inputs',
      (tester) async {
        await pumpSheet(tester, repo: seeded(), editing: _mirror);

        // `findsNothing` on the fields themselves, not "a read-only Text is
        // present": a disabled input satisfies the latter, and a disabled
        // input is exactly what this must not be.
        expect(find.byKey(const Key('amount-field')), findsNothing);
        expect(find.byKey(const Key('finance-date-field')), findsNothing);
        expect(find.byKey(const Key('finance-currency-field')), findsNothing);
        expect(find.byKey(const Key('finance-type-toggle')), findsNothing);

        final facts = tester.widget<Text>(
          find.byKey(const Key('finance-mirror-facts')),
        );
        expect(facts.data, contains('900'));
        expect(facts.data, contains('TWD'));
        expect(facts.data, contains(_en.financeTypeExpense));
      },
    );

    testWidgets('offers no delete control at all', (tester) async {
      await pumpSheet(tester, repo: seeded(), editing: _mirror);

      expect(find.byKey(const Key('finance-delete-button')), findsNothing);
      expect(find.text(_en.financeDeleteButton), findsNothing);
      expect(find.text(_en.financeSplitMirrorLockedNote), findsOneWidget);
    });

    testWidgets('keeps the category and note editable, and saves them', (
      tester,
    ) async {
      final repo = seeded();
      await pumpSheet(tester, repo: repo, editing: _mirror);

      await tester.tap(find.byKey(const Key('finance-category-cat-transport')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('finance-note-field')), 'shared taxi');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-transaction-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('save-transaction-button')), findsNothing);
      final saved = repo.byMonth['2026-07']!.firstWhere((t) => t.id == 'mirror-1');
      expect(saved.categoryId, 'cat-transport');
      expect(saved.note, 'shared taxi');
      // Task 2.4: the row is still a mirror after the save. Asserted here
      // rather than left to the fake's own faithfulness — a fake that drops
      // the link turns every later mirror guard into a test of nothing.
      expect(saved.splitExpenseId, 'exp-1');
      // The facts the server owns went back unchanged.
      expect(saved.amount, 900);
      expect(saved.type, FinanceType.expense);
      expect(saved.date, '2026-07-15');
    });

    testWidgets('takes the offered exit to the split records', (tester) async {
      var wentToSplit = 0;
      await pumpSheet(
        tester,
        repo: seeded(),
        editing: _mirror,
        onGoToSplit: () => wentToSplit++,
      );

      await tester.tap(find.byKey(const Key('finance-go-to-split')));
      await tester.pumpAndSettle();

      expect(wentToSplit, 1);

      // The second one, beside the sentence that tells you to go. Without it
      // the explanation and the way to act on it are at opposite ends of the
      // sheet — ~240dp apart at textScale 1.0, and the header one is scrolled
      // off entirely at 2.0.
      await tester.ensureVisible(
        find.byKey(const Key('finance-go-to-split-footer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finance-go-to-split-footer')));
      await tester.pumpAndSettle();

      expect(wentToSplit, 2);
    });

    testWidgets('a long note does not push the sheet\'s inputs off screen', (
      tester,
    ) async {
      // The note is free text with no length limit and the title renders it at
      // `titleLarge`; uncapped, a 55-character one was a 728dp headline at
      // 320dp / textScale 2.0, with the category picker the user came for
      // below the fold.
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // textScale 2.0 is where it bites: at 1.0 the same note is ~196dp, just
      // inside any plausible height threshold, so a test that skipped this
      // would pass with the cap removed.
      useTextScaleFactor(tester, 2.0);

      await pumpSheet(
        tester,
        repo: seeded(),
        editing: const FinanceTransaction(
          id: 'mirror-1',
          type: FinanceType.expense,
          amount: 900,
          currency: 'TWD',
          categoryId: 'cat-food',
          date: '2026-07-15',
          note: 'A dinner with a very long description that someone typed out',
          splitExpenseId: 'exp-1',
        ),
      );

      // The line count, not the height: `maxLines: 2` is exactly what this
      // pins, and a height threshold has to be guessed against a font.
      expect(
        paintedTextLineCount(
          tester,
          find.byKey(const Key('finance-mirror-title')),
        ),
        2,
      );
    });

    testWidgets(
      "a self-recorded transaction's sheet is completely unchanged",
      (tester) async {
        await pumpSheet(tester, repo: seeded(), editing: _selfRecorded);

        expect(find.byKey(const Key('amount-field')), findsOneWidget);
        expect(find.byKey(const Key('finance-date-field')), findsOneWidget);
        expect(find.byKey(const Key('finance-currency-field')), findsOneWidget);
        expect(find.byKey(const Key('finance-type-toggle')), findsOneWidget);
        expect(find.byKey(const Key('finance-delete-button')), findsOneWidget);
        expect(find.byKey(const Key('finance-mirror-facts')), findsNothing);
        expect(find.byKey(const Key('finance-go-to-split')), findsNothing);
      },
    );
  });

  group('AddTransactionSheet — the split moved on underneath', () {
    FakeFinanceRepository seeded() =>
        FakeFinanceRepository()..byMonth['2026-07'] = [_mirror];

    testWidgets(
      'a 409 reloads the current facts and keeps the unsaved category and note',
      (tester) async {
        final repo = seeded();
        await pumpSheet(tester, repo: repo, editing: _mirror);

        // The user's unsaved edits, made before the refusal.
        await tester.tap(find.byKey(const Key('finance-category-cat-transport')));
        await tester.pump();
        await tester.enterText(find.byKey(const Key('finance-note-field')), 'my own note');
        await tester.pump();

        // The payer raised the split while this sheet was open: the write is
        // refused wholesale, and the reload behind it finds the new amount.
        repo.failNext = const FinanceConflict();
        repo.byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 'mirror-1',
            type: FinanceType.expense,
            amount: 1200,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-15',
            note: '晚餐',
            splitExpenseId: 'exp-1',
          ),
        ];
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        // Still open, and told what actually happened — not "save failed",
        // which points at a retry that would be refused identically.
        expect(find.byKey(const Key('save-transaction-button')), findsOneWidget);
        expect(find.text(_en.financeSplitChangedReloaded), findsOneWidget);
        expect(find.text(_en.financeSaveFailed), findsNothing);

        // (1) the facts on screen are the server's current ones,
        final facts = tester.widget<Text>(
          find.byKey(const Key('finance-mirror-facts')),
        );
        expect(facts.data, contains('1,200'));
        // (2) the category they picked is still selected, and
        final chip = tester.widget<ChoiceChip>(
          find.byKey(const Key('finance-category-cat-transport')),
        );
        expect(chip.selected, isTrue);
        // (3) the note they typed is still there.
        expect(find.text('my own note'), findsOneWidget);
      },
    );

    testWidgets('a 400 still reports a plain save failure', (tester) async {
      final repo = seeded();
      await pumpSheet(tester, repo: repo, editing: _mirror);

      repo.failNext = const FinanceValidationFailure();
      await tester.tap(find.byKey(const Key('save-transaction-button')));
      await tester.pumpAndSettle();

      expect(find.text(_en.financeSaveFailed), findsOneWidget);
      expect(find.text(_en.financeSplitChangedReloaded), findsNothing);
    });

    testWidgets(
      'a 404 says the split is gone, closes the sheet, and the phantom row '
      'leaves the list',
      (tester) async {
        final repo = seeded();
        final controller = await pumpSheet(tester, repo: repo, editing: _mirror);

        // The payer deleted the split; the cascade took the mirror with it.
        repo.failNext = const FinanceNotFound();
        repo.byMonth['2026-07'] = [];
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('save-transaction-button')), findsNothing);
        expect(find.text(_en.financeSplitDeletedElsewhere), findsOneWidget);
        // Not just the message: the month behind the sheet refreshed, so the
        // row the user was editing is really gone rather than still listed.
        expect(controller.transactions, isEmpty);
      },
    );

    testWidgets(
      'a 404 on a row the user recorded also closes the sheet, with its own '
      'message',
      (tester) async {
        // `_mutate` reloads on every not-found, not just a mirror's. Gating the
        // explanation on `_isMirror` would have moved the dead end this branch
        // exists to close onto self-recorded rows instead: the list refreshes
        // behind the sheet, the row is gone, and the user is told only "save
        // failed" while still editing it.
        final repo = seeded();
        final controller = await pumpSheet(
          tester,
          repo: repo,
          editing: _selfRecorded,
        );

        repo.failNext = const FinanceNotFound();
        repo.byMonth['2026-07'] = [];
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('save-transaction-button')), findsNothing);
        expect(find.text(_en.financeTransactionGoneElsewhere), findsOneWidget);
        // Not the split copy: nobody else deleted this one.
        expect(find.text(_en.financeSplitDeletedElsewhere), findsNothing);
        expect(controller.transactions, isEmpty);
      },
    );

    testWidgets(
      'a reload that lands in another month closes the sheet with its own '
      'message',
      (tester) async {
        final repo = seeded();
        await pumpSheet(tester, repo: repo, editing: _mirror);

        // The payer moved the split's day into August: the reload of July
        // finds nothing to re-read.
        repo.failNext = const FinanceConflict();
        repo.byMonth['2026-07'] = [];
        repo.byMonth['2026-08'] = [
          const FinanceTransaction(
            id: 'mirror-1',
            type: FinanceType.expense,
            amount: 900,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-08-02',
            note: '晚餐',
            splitExpenseId: 'exp-1',
          ),
        ];
        await tester.tap(find.byKey(const Key('save-transaction-button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('save-transaction-button')), findsNothing);
        expect(find.text(_en.financeSplitMovedOutOfMonth), findsOneWidget);
      },
    );
  });
}
