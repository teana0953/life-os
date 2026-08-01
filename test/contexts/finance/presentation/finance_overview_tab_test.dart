import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/presentation/finance_overview_tab.dart';

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
              onEditBudgets: () {},
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
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // A 2x text scale overflows rows elsewhere on the tab; the header is
          // asserted on its own, as the width tests above already do.
          tester.takeException();
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
