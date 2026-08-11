import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/installment_plan.dart';
import 'package:life_os/contexts/finance/domain/monthly_summary.dart';
import 'package:life_os/contexts/finance/presentation/finance_transactions_tab.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';
import '../finance_test_support.dart';

void main() {
  group('FinanceTransactionsTab', () {
    testWidgets('a failed WRITE does not raise the reload notice — the rows '
        'on screen are not stale', (tester) async {
      // A rejected write leaves `status == error` with the list untouched.
      // Keying the notice off that pair leaves a permanent "could not
      // refresh" row over rows that are perfectly current.
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

      repo.failNext = const FinanceValidationFailure();
      await controller.addTransaction(
        'tok',
        type: FinanceType.expense,
        amount: 0,
        currency: 'TWD',
        categoryId: 'cat-food',
        date: '2026-07-06',
      );
      expect(controller.error, isNotNull, reason: 'the write did fail');

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

      expect(find.byKey(const Key('stale-notice-row')), findsNothing);
    });

    testWidgets(
      'stays visible after the reader scrolls the list away from the top '
      '— pinned above the ListView, not row 0 of it',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // 40 rows so the list is genuinely scrollable and, were the notice
        // ever back to being row 0 of a lazily-built `ListView`, off-screen
        // once scrolled far enough that Flutter has no reason to keep it
        // built at all.
        final repo = FakeFinanceRepository()
          ..byMonth['2026-07'] = [
            for (var i = 0; i < 40; i++)
              FinanceTransaction(
                id: 't$i',
                type: FinanceType.expense,
                amount: 100 + i,
                currency: 'TWD',
                categoryId: 'cat-food',
                date: '2026-07-${(i % 27 + 1).toString().padLeft(2, '0')}',
              ),
          ];
        final controller = testFinanceController(repo);
        await controller.load('tok', '2026-07');
        controller.markReloadFailed();

        await tester.binding.setSurfaceSize(const Size(390, 640));
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
        expect(find.byKey(const Key('stale-notice-row')), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, -1200));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stale-notice-row')), findsOneWidget);
        final rect = tester.getRect(find.byKey(const Key('stale-notice-row')));
        final viewport = tester.getRect(find.byType(Scaffold));
        expect(
          rect.overlaps(viewport),
          isTrue,
          reason: 'the notice must stay pinned in view after a scroll, not '
              'ride away with row 0 of the list',
        );
      },
    );

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

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('finance-transactions-empty')),
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

    testWidgets(
      "a stale notice's own retry, while its reload is still in flight, keeps "
      'the row mounted with a disabled spinner — StaleNotice must not read as '
      '"refreshed" mid-flight (see its class doc)',
      (tester) async {
        final repo = _GatedFinanceRepository()
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
        // The background reload that put the notice up in the first place
        // already failed and settled — only the retry itself is gated.
        controller.markReloadFailed();

        await tester.pumpWidget(
          l10nTestApp(
            home: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Scaffold(
                body: FinanceTransactionsTab(
                  controller: controller,
                  onEdit: (_) {},
                  onSwitchMonth: (m) => controller.load('tok', m),
                  onSignInAgain: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('stale-notice-row')), findsOneWidget);

        repo.gate = Completer<void>();
        await tester.tap(find.byKey(const Key('stale-notice-retry')));
        await tester.pump();

        // Still mounted, and the button reads as an in-flight spinner, not
        // a pressable "Retry" — a `loading: false` wiring would already show
        // the row as gone or the button as pressable again here.
        expect(find.byKey(const Key('stale-notice-row')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('stale-notice-retry')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        repo.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('stale-notice-row')), findsNothing);
      },
    );

    testWidgets('a mirrored row is marked and a self-recorded one is not', (tester) async {
      final repo = FakeFinanceRepository()..byMonth['2026-07'] = _mixedMonth;
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

      // Both rows are seeded, not just the mirrored one: with a mirror-only
      // fixture "every row is marked" and "the right row is marked" are the
      // same result.
      expect(find.byKey(const Key('finance-transaction-mirror-t-mirror')), findsOneWidget);
      expect(find.byKey(const Key('finance-transaction-mirror-t-own')), findsNothing);
      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.financeSplitMirrorBadge), findsOneWidget);
    });

    testWidgets('an instalment row is marked and an ordinary one is not', (tester) async {
      // Both rows are seeded, not just the instalment (tasks 4.2): against
      // an instalment-only fixture, "mark every row" and "mark the right
      // row" are the same result.
      final repo = FakeFinanceRepository()
        ..byMonth['2026-07'] = _installmentMixedMonth
        ..plansById['plan-1'] = _seededPlan;
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

      expect(
        find.byKey(const Key('finance-transaction-installment-t-inst')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('finance-transaction-installment-t-own')),
        findsNothing,
      );
    });

    testWidgets('saving an edit to a mirrored row keeps its marker', (tester) async {
      final repo = FakeFinanceRepository()..byMonth['2026-07'] = _mixedMonth;
      final controller = testFinanceController(repo);
      await controller.load('tok', '2026-07');

      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => FinanceTransactionsTab(
                controller: controller,
                onEdit: (_) {},
                onSwitchMonth: (m) async {},
                onSignInAgain: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Recategorising is the one edit a mirrored row accepts, and the update
      // path rebuilds the row from what the caller sent — which does not
      // include the split link. Dropping it there makes the mirror silently
      // become a row the user recorded themselves: still undeletable by the
      // server, but no longer marked as such anywhere.
      await controller.updateTransaction(
        'tok',
        't-mirror',
        type: FinanceType.expense,
        amount: 450,
        currency: 'TWD',
        categoryId: 'cat-transport',
        date: '2026-07-10',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance-transaction-mirror-t-mirror')), findsOneWidget);
    });
  });

  // Narrow screen (task 4). Re-derived after the change: the guide replaced
  // a bare `Text`, but it is still inside a `Center` — a *bounded* box — so
  // an overflow here really does throw and `expectNoLayoutErrors` is not a
  // guard that cannot fail. (Deliberately left unwrapped for that reason;
  // see the note at the call site.) The measurement below covers the other
  // half: fitting the box is not the same as painting every glyph.
  group('the empty guide at 320dp, textScale 2.0', () {
    for (final locale in testSupportedLocales) {
      testWidgets('shows its title in full, locale=$locale', (tester) async {
        useTextScaleFactor(tester, 2.0);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = testFinanceController(FakeFinanceRepository());
        await controller.load('tok', '2026-07');
        await expectNoLayoutErrors(() async {
          await tester.pumpWidget(
            l10nTestApp(
              locale: locale,
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
        });

        final loc = lookupAppLocalizations(locale);
        final finder = find.text(loc.financeEmptyTitle);
        expect(finder, findsOneWidget);
        // Measured, not read off `didExceedMaxLines`: that flag is only ever
        // true when `maxLines` is set, and the guide's title sets neither
        // `maxLines` nor `overflow`, so it was an assertion that could not
        // fail. Every glyph painted is what "not cut off" actually means.
        expectPaintedInFull(
          tester,
          finder,
          reason: 'the empty-month title was cut off at 320dp × 2.0',
        );
        // Inside the surface, not merely laid out somewhere.
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640));
      });
    }
  });
}

/// A month holding one row the server mirrored from a split expense and one
/// the user recorded themselves. Both are needed: against a mirror-only
/// fixture, "mark everything" passes every assertion the real behaviour does.
///
/// A fresh growable list each time, not a `const` one: `FakeFinanceRepository`
/// edits `byMonth` in place, and a const list makes every write throw an
/// `UnsupportedError` the controller swallows — which leaves the month exactly
/// as seeded and quietly turns any after-the-edit assertion into an
/// assertion about the seed.
/// A month holding one instalment period and one ordinary row — the same
/// tell-them-apart shape as [_mixedMonth], for the instalment mark. The
/// plan behind `t-inst` is [_seededPlan] so the row can render the period
/// count once the implementation fetches it.
List<FinanceTransaction> get _installmentMixedMonth => [
  const FinanceTransaction(
    id: 't-inst',
    type: FinanceType.expense,
    amount: 5000,
    currency: 'TWD',
    categoryId: 'cat-food',
    date: '2026-07-10',
    planId: 'plan-1',
    installmentNo: 3,
  ),
  const FinanceTransaction(
    id: 't-own',
    type: FinanceType.expense,
    amount: 200,
    currency: 'TWD',
    categoryId: 'cat-food',
    date: '2026-07-10',
  ),
];

const _seededPlan = InstallmentPlan(
  id: 'plan-1',
  mode: InstallmentMode.total,
  periods: 12,
  startDay: '2026-05-10',
  amount: 60000,
  currency: 'TWD',
  categoryId: 'cat-food',
);

List<FinanceTransaction> get _mixedMonth => [
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
    date: '2026-07-10',
  ),
];

/// A [FakeFinanceRepository] whose `getSummary` awaits [gate] (once set)
/// before resolving — lets a test hold a reload open to observe the
/// in-flight `loading: true` state of [StaleNotice]'s retry, which
/// [FakeFinanceRepository] alone has no way to pause mid-flight for.
class _GatedFinanceRepository extends FakeFinanceRepository {
  Completer<void>? gate;

  @override
  Future<MonthlySummary> getSummary(String idToken, String month) async {
    final g = gate;
    if (g != null) await g.future;
    return super.getSummary(idToken, month);
  }
}
