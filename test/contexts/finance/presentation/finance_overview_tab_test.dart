import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/split_spending.dart';
import 'package:life_os/contexts/finance/presentation/finance_overview_tab.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/empty_state.dart';
import 'package:life_os/shared/widgets/ledge_card.dart';

import 'package:intl/intl.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/month_label.dart';
import '../finance_test_support.dart';

/// The locale-aware month header text for a month, in the test locale.
String _monthLabel(int year, int month) =>
    DateFormat.yMMM('en').format(DateTime(year, month));

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
          onEditBudgets: () {},
          onSignInAgain: () {},
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

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('finance-empty-title')),
          matching: find.byType(EmptyStateGuide),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byIcon(Icons.receipt_long_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('finance-empty-cta')), findsOneWidget);
    });

    testWidgets('the month guide and the budget note are different tiers '
        'because only one of the two regions is named by a header', (
      tester,
    ) async {
      await pumpOverview(tester, FakeFinanceRepository());
      final loc = lookupAppLocalizations(const Locale('en'));

      // Both regions are empty for the same reason (a brand-new account) and
      // they render 16dp apart, which is what makes the two tiers look
      // inconsistent here. The discriminator is design D1b, not looks:
      //
      // Tier 2 — the budget rows. The card's own header stays on screen and
      // names the region, so one muted line finishes the sentence.
      expect(find.text(loc.financeBudgetCardTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('budget-card')),
          matching: find.byType(EmptyStateNote),
        ),
        findsOneWidget,
      );

      // Tier 1 — the month's transactions. Nothing left on the tab names
      // that region: the month header names the *month*, the budget card
      // names *budgets*. So the guide has to introduce the region itself,
      // and it is not inside any titled card or section.
      final guide = find.byType(EmptyStateGuide);
      expect(guide, findsOneWidget);
      expect(
        find.ancestor(of: guide, matching: find.byType(LedgeCard)),
        findsNothing,
        reason: 'the month guide sits inside a titled card — under D1b that '
            'card names the region and the guide should be a note',
      );
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
              onEditBudgets: () {},
              onSignInAgain: () {},
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
        // Grouped: displayed amounts carry thousands separators.
        expect(find.text('50,000'), findsOneWidget); // TWD income
        expect(find.text('10.00'), findsWidgets); // USD expense
      },
    );

    testWidgets('shows the month label from the controller, localized', (
      tester,
    ) async {
      await pumpOverview(tester, FakeFinanceRepository(), month: '2026-09');

      // The locale-aware label the rest of the app uses, not the raw
      // `2026-09` wire format.
      expect(find.text(_monthLabel(2026, 9)), findsOneWidget);
      expect(find.text('2026-09'), findsNothing);
    });

    testWidgets(
      'the previous-month arrow steps the ledger back a month, end to end',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..byMonth['2026-06'] = [
            const FinanceTransaction(
              id: 't-june',
              type: FinanceType.expense,
              amount: 600,
              currency: 'TWD',
              categoryId: 'cat-food',
              date: '2026-06-05',
            ),
          ];
        final controller = testFinanceController(repo);
        await controller.load('tok', '2026-07');
        await tester.pumpWidget(
          l10nTestApp(
            home: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Scaffold(
                body: FinanceOverviewTab(
                  controller: controller,
                  onSwitchMonth: (m) => controller.load('tok', m),
                  onAdd: () {},
                  onEditBudgets: () {},
                  onSignInAgain: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('finance-month-previous')));
        await tester.pumpAndSettle();

        // Backwards, never forwards — the direction is pinned here so the
        // shared header refactor can't quietly flip it.
        expect(controller.selectedMonth, '2026-06');
        expect(find.text(_monthLabel(2026, 6)), findsOneWidget);
        expect(find.text('600'), findsWidgets);
      },
    );

    testWidgets(
      'a failed month switch shows the error screen with retry — never the '
      'old month\'s data under the new month\'s label',
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
          ];
        final controller = testFinanceController(repo);
        await controller.load('tok', '2026-07');

        repo.failNext = const FinanceFetchFailure('boom');
        var switchedTo = '';
        await tester.pumpWidget(
          l10nTestApp(
            home: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Scaffold(
                body: FinanceOverviewTab(
                  controller: controller,
                  onSwitchMonth: (m) async {
                    switchedTo = m;
                    await controller.load('tok', m);
                  },
                  onAdd: () {},
                  onEditBudgets: () {},
                  onSignInAgain: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await controller.load('tok', '2026-08');
        await tester.pumpAndSettle();

        // July's stale content must be gone — no "300" total, no month
        // label showing July.
        expect(find.text('300'), findsNothing);
        expect(find.text('2026-07'), findsNothing);
        expect(find.byKey(const Key('finance-overview-retry')), findsOneWidget);

        await tester.tap(find.byKey(const Key('finance-overview-retry')));
        await tester.pump();
        expect(switchedTo, '2026-08');
      },
    );

    testWidgets(
      'tapping the month label jumps to a month picked two years back, '
      'through the same month-change path the arrows use',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..byMonth['2024-03'] = [
            const FinanceTransaction(
              id: 't-old',
              type: FinanceType.expense,
              amount: 900,
              currency: 'TWD',
              categoryId: 'cat-food',
              date: '2024-03-05',
            ),
          ];
        final controller = testFinanceController(repo);
        await controller.load('tok', '2026-07');
        var switchedTo = '';
        await tester.pumpWidget(
          l10nTestApp(
            home: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Scaffold(
                body: FinanceOverviewTab(
                  controller: controller,
                  onSwitchMonth: (m) async {
                    switchedTo = m;
                    await controller.load('tok', m);
                  },
                  onAdd: () {},
                  onEditBudgets: () {},
                  onSignInAgain: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('finance-month-label')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-year-previous')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-year-previous')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-month-3')));
        await tester.pumpAndSettle();

        // Routed through onSwitchMonth (the controller's guarded path), not
        // straight at the controller.
        expect(switchedTo, '2024-03');
        expect(controller.selectedMonth, '2024-03');
        expect(find.text(_monthLabel(2024, 3)), findsOneWidget);
        expect(find.text('900'), findsWidgets);
      },
    );

    testWidgets('dismissing the month picker leaves the month alone', (
      tester,
    ) async {
      final repo = FakeFinanceRepository();
      final controller = testFinanceController(repo);
      await controller.load('tok', '2026-07');
      var switches = 0;
      await tester.pumpWidget(
        l10nTestApp(
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Scaffold(
              body: FinanceOverviewTab(
                controller: controller,
                onSwitchMonth: (m) async {
                  switches++;
                  await controller.load('tok', m);
                },
                onAdd: () {},
                onEditBudgets: () {},
                onSignInAgain: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance-month-label')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(switches, 0);
      expect(controller.selectedMonth, '2026-07');
    });

    // Regression: the month label's `▾` affordance added padding + an icon to
    // a centred, non-shrinkable Row. Widget tests default to an 800x600
    // surface, so nothing else in this mobile-first PWA's suite caught it.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the month header does not overflow at ${width.toInt()}dp, '
          'locale=$locale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            final controller = testFinanceController(FakeFinanceRepository());
            await controller.load('tok', '2026-07');
            await tester.pumpWidget(
              l10nTestApp(
                locale: locale,
                home: Scaffold(
                  body: FinanceOverviewTab(
                    controller: controller,
                    onSwitchMonth: (m) async {},
                    onAdd: () {},
                    onEditBudgets: () {},
                    onSignInAgain: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expectMonthLabelFullyVisible(
              tester,
              const Key('finance-month-label'),
            );
            expectMonthLabelReadable(tester, const Key('finance-month-label'));
          },
        );
      }
    }
  });

  group('mirrored rows in the recent-transactions list', () {
    testWidgets('a mirrored row is marked and a self-recorded one is not', (tester) async {
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 't-mirror',
            type: FinanceType.expense,
            amount: 450,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-10',
            splitExpenseId: 'se-1',
          ),
          const FinanceTransaction(
            id: 't-own',
            type: FinanceType.expense,
            amount: 200,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-11',
          ),
        ];

      await pumpOverview(tester, repo);

      // The recent-transactions list is the last thing on the tab and starts
      // below the fold, outside the `ListView`'s cache extent — without this
      // its rows are never built and every assertion below would be about a
      // list that is not in the tree.
      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.scrollUntilVisible(find.text(loc.financeRecentTransactions), 200);
      await tester.pumpAndSettle();

      // A guard of this list's own, separate from 明細's: both lists show the
      // same transactions, so marking only one of them teaches the user that
      // the mark means nothing — and a single shared assertion would let
      // "drop the mark from the overview" survive.
      //
      // Both a mirrored and a self-recorded row are seeded because with only
      // mirrors, "mark every row" and "mark the right row" are the same
      // result.
      expect(find.byKey(const Key('finance-recent-mirror-t-mirror')), findsOneWidget);
      expect(find.byKey(const Key('finance-recent-mirror-t-own')), findsNothing);
      expect(find.text(loc.financeSplitMirrorBadge), findsOneWidget);
    });
  });

  group('the split-spending line (design D6, task 6)', () {
    testWidgets('a month with split shares shows its own line, per currency', (tester) async {
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
        ]
        ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 450, countedInTransactions: true)];

      await pumpOverview(tester, repo);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.financeSplitSpendingTitle), findsOneWidget);
      expect(find.text('450'), findsOneWidget);
    });

    testWidgets('the recorded expense total is unaffected by split spending', (tester) async {
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
        ]
        ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 450, countedInTransactions: true)];

      await pumpOverview(tester, repo);

      // 300 (the expense total) is unchanged — never 750 (300 + 450).
      //
      // Deliberately NOT inverted now that TWD shares are counted: what this
      // pins is that the *frontend* does not add `splitSpending` locally, and
      // that matters more than it used to. The server already folded the 450
      // into the totals it sends; adding it here again is a double-count, and
      // the 750 below is what that would look like.
      expect(find.text('300'), findsWidgets);
      expect(find.text('750'), findsNothing);
    });

    testWidgets('a counted share reaches the expense total exactly once', (tester) async {
      // The stronger shape of the test above. There the transaction is one the
      // user recorded, so "don't add `splitSpending`" is the whole story. Here
      // the transaction *is* the mirror the server wrote for that same share —
      // the realistic month — so the 450 is present in both figures the tab
      // holds, and counting it twice is a mistake nothing else would catch.
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = [
          const FinanceTransaction(
            id: 't-mirror',
            type: FinanceType.expense,
            amount: 450,
            currency: 'TWD',
            categoryId: 'cat-food',
            date: '2026-07-05',
            splitExpenseId: 'e1',
          ),
        ]
        ..splitSpendingByMonth['2026-07'] = const [
          SplitSpending(currency: 'TWD', amount: 450, countedInTransactions: true),
        ];

      await pumpOverview(tester, repo);

      // The expense total is exactly 450 — `findsNothing` on '900' alone
      // falsifies only that one wrong answer, and any other arithmetic slip
      // would pass it.
      expect(find.text('450'), findsWidgets);
      expect(find.text('900'), findsNothing);
    });

    testWidgets('the budget card is unaffected by split spending', (tester) async {
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
        ]
        ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 100000, countedInTransactions: true)]
        ..seedBudget(amount: 1000);

      await pumpOverview(tester, repo);

      // The budget's spent/percent come from the backend `FinanceBudget` and
      // are shown exactly as sent. Also deliberately not inverted: a counted
      // currency's share now *does* consume the budget, but it does so on the
      // server, inside the figure below — the frontend adding
      // `splitSpending` on top is the double-count this pins against.
      final loc = lookupAppLocalizations(const Locale('en'));
      // The absence of the over-label alone would also hold if the budget
      // card rendered nothing at all — pin the row and the consumed figure,
      // which must be exactly the recorded 300, not 300 + 100000.
      expect(find.byKey(const Key('budget-row-total')), findsOneWidget);
      expect(find.text('300 / 1,000'), findsOneWidget);
      expect(find.text(loc.financeBudgetOverLabel), findsNothing);
    });

    testWidgets('a month with no split shares omits the line, rather than showing a zero', (
      tester,
    ) async {
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
        ];

      await pumpOverview(tester, repo);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.financeSplitSpendingTitle), findsNothing);
    });

    testWidgets(
      'a month with split shares but no recorded transactions still shows the line, '
      'despite the empty-month call-to-action',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 450, countedInTransactions: true)];

        await pumpOverview(tester, repo);

        // The empty-month CTA is still there (no transactions)...
        expect(find.byKey(const Key('finance-empty-title')), findsOneWidget);
        // ...but the split-spending line survives it.
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.financeSplitSpendingTitle), findsOneWidget);
        expect(find.text('450'), findsOneWidget);
      },
    );

    testWidgets(
      'a counted and an uncounted currency are stated separately, each beside its own '
      'amount',
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
          ]
          // Both kinds in one month, which is what makes this falsifiable: a
          // card that keeps saying one thing about everything renders exactly
          // the same as the right one when only one kind is present.
          ..splitSpendingByMonth['2026-07'] = const [
            SplitSpending(currency: 'TWD', amount: 450, countedInTransactions: true),
            SplitSpending(currency: 'THB', amount: 700, countedInTransactions: false),
          ]
          ..seedBudget(amount: 1000);

        await pumpOverview(tester, repo);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.financeSplitSpendingCountedHeading), findsOneWidget);
        expect(find.text(loc.financeSplitSpendingCountedNote), findsOneWidget);
        expect(find.text(loc.financeSplitSpendingUncountedHeading), findsOneWidget);
        expect(find.text(loc.financeSplitSpendingUncountedNote), findsOneWidget);

        // Each sentence beside its own amounts, not one sentence at the top
        // covering both: TWD's row falls between the counted sentence and the
        // uncounted heading, and THB's below the uncounted sentence. Ordering
        // is the assertion because "both sentences are somewhere on the card"
        // is also true of a card that prints them as a preamble to a single
        // undivided list.
        final countedNoteY = tester.getTopLeft(
          find.byKey(const Key('finance-split-spending-counted-note')),
        ).dy;
        final twdY = tester.getTopLeft(
          find.byKey(const Key('finance-split-spending-TWD')),
        ).dy;
        final uncountedHeadingY = tester.getTopLeft(
          find.byKey(const Key('finance-split-spending-uncounted-heading')),
        ).dy;
        final thbY = tester.getTopLeft(
          find.byKey(const Key('finance-split-spending-THB')),
        ).dy;
        expect(countedNoteY, lessThan(twdY));
        expect(twdY, lessThan(uncountedHeadingY));
        expect(uncountedHeadingY, lessThan(thbY));

        // THB is outside `finance_money.dart`'s zero-decimal set *and* outside
        // its whitelist, so `decimalDigitsFor` gives it 2 and 700 renders as
        // `7.00`. That is the pre-existing bug tasks 8.4/8.5 hold as an
        // explicit non-goal of this change (a zero-decimal code like VND shows
        // as 1/100) — the expectation is written to today's behaviour so this
        // test does not silently become the thing that has to change when it
        // is fixed.
        expect(find.text('7.00'), findsOneWidget);

        // …and the card still sits below the recorded totals rather than
        // between the budget card and them (design D6).
        final splitTop = tester.getTopLeft(find.text(loc.financeSplitSpendingTitle)).dy;
        final expenseTotalTop = tester.getTopLeft(find.text(loc.financeExpenseTotal)).dy;
        final budgetTop = tester.getTopLeft(find.text(loc.financeBudgetCardTitle)).dy;
        expect(budgetTop, lessThan(expenseTotalTop));
        expect(expenseTotalTop, lessThan(splitTop));
      },
    );

    testWidgets(
      'a month with only counted currencies makes no claim about uncounted ones',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [
            SplitSpending(currency: 'TWD', amount: 450, countedInTransactions: true),
          ];

        await pumpOverview(tester, repo);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.financeSplitSpendingCountedHeading), findsOneWidget);
        // Heading *and* sentence: an empty group under a heading reads as
        // "you owe nothing in an uncounted currency", which is a claim about
        // money that is not there.
        expect(find.text(loc.financeSplitSpendingUncountedHeading), findsNothing);
        expect(find.text(loc.financeSplitSpendingUncountedNote), findsNothing);
      },
    );

    testWidgets(
      'a same-month reload never paints the previous load\'s figure while the new one is '
      'still in flight',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..splitSpendingByMonth['2026-07'] = const [SplitSpending(currency: 'TWD', amount: 987654, countedInTransactions: true)];
        final controller = testFinanceController(repo);
        await controller.load('tokA', '2026-07');

        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => FinanceOverviewTab(
                  controller: controller,
                  onSwitchMonth: (m) async {},
                  onAdd: () {},
                  onEditBudgets: () {},
                  onSignInAgain: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('987,654'), findsOneWidget);

        // A second account, same calendar month: the main fetch resolves
        // (and notifies) while the independent split leg is still in
        // flight. Whatever is on the controller in that window is what the
        // overview paints — and it must not be the first account's money.
        repo.splitSpendingByMonth['2026-07'] = const [];
        repo.splitSpendingGates['2026-07'] = Completer<void>();
        final reload = controller.load('tokB', '2026-07');
        await tester.pumpAndSettle();

        expect(find.text('987,654'), findsNothing);

        repo.splitSpendingGates['2026-07']!.complete();
        await reload;
        await tester.pumpAndSettle();
        expect(find.text('987,654'), findsNothing);
      },
    );

    testWidgets(
      'a split-spending load failure reports its own error; the rest of the overview stays fine',
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
          ]
          ..splitSpendingFailNext = const FinanceFetchFailure('boom');

        await pumpOverview(tester, repo);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.byKey(const Key('finance-split-spending-error')), findsOneWidget);
        expect(find.text(loc.financeSplitSpendingLoadFailed), findsOneWidget);
        // The recorded total still shows normally.
        expect(find.text('300'), findsWidgets);
      },
    );
  });

  // Regression: the readable floor was computed from the **authored** font
  // size while the `FittedBox` scales `textScaler`-sized glyphs, so the width
  // cap bit `textScaler`× too early — a user on a large system font size got
  // the month digits ellipsized away (`2026年7月` → `202…`): the exact failure
  // the floor was added to prevent, reintroduced by the fix for it. Nothing in
  // this suite set a text scale at all before this.
  group('month label at a large system text scale', () {
    for (final locale in testSupportedLocales) {
      testWidgets(
        'the month label stays whole at 320dp/textScale=2, locale=$locale',
        (tester) async {
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(const Size(320, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final controller = testFinanceController(FakeFinanceRepository());
          await controller.load('tok', '2026-07');
          await tester.pumpWidget(
            l10nTestApp(
              locale: locale,
              home: Scaffold(
                body: FinanceOverviewTab(
                  controller: controller,
                  onSwitchMonth: (m) async {},
                  onAdd: () {},
                  onEditBudgets: () {},
                  onSignInAgain: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expectMonthLabelFullyVisible(
            tester,
            const Key('finance-month-label'),
          );
          expectMonthLabelPaintedReadable(
            tester,
            const Key('finance-month-label'),
          );
        },
      );
    }
  });
}
