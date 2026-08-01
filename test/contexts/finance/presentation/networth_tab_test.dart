import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_tab.dart';
import 'package:life_os/shared/widgets/month_nav_header.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import 'package:intl/intl.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';
import '../finance_test_support.dart';

const _locale = Locale('en');
final _loc = lookupAppLocalizations(_locale);

/// What the shared month header should read for a `YYYY-MM` month in the
/// test locale — the same locale-aware label the rest of the app uses,
/// never the raw `2026-07`.
String _monthLabel(int year, int month) =>
    DateFormat.yMMM('en').format(DateTime(year, month));

Future<NetWorthController> _pumpTab(
  WidgetTester tester,
  FakeFinanceRepository repo, {
  String month = '2026-07',
  List<NetWorthAccount>? tapped,
}) async {
  // Tall enough that the whole tab — including the trend section at the
  // bottom — is laid out, since a ListView doesn't build off-screen children.
  await tester.binding.setSurfaceSize(const Size(600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = testNetWorthController(repo);
  await controller.load('token', month);
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => NetWorthTab(
            controller: controller,
            onSwitchMonth: (m) => controller.load('token', m),
            onEditAccountValue: (a) => tapped?.add(a),
            onManageAccounts: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('NetWorthTab', () {
    testWidgets('shows the net worth and a rising growth indicator', (tester) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 460181)
        ..seedSnapshot('acc-cash', '2026-07', 520000)
        ..seedSnapshot('acc-card', '2026-07', 41484);

      await _pumpTab(tester, repo);

      expect(find.byKey(const Key('networth-net-value')), findsOneWidget);
      expect(find.text('478516'), findsOneWidget);
      expect(find.byKey(const Key('networth-growth')), findsOneWidget);
      // Direction is carried by an arrow and a word, never color alone.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text(_loc.networthGrowthUp), findsOneWidget);
      expect(find.text('4.0%'), findsOneWidget);
    });

    testWidgets('shows a falling growth indicator when net worth dropped', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 1000)
        ..seedSnapshot('acc-cash', '2026-07', 900);

      await _pumpTab(tester, repo);

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.text(_loc.networthGrowthDown), findsOneWidget);
      expect(find.text('10.0%'), findsOneWidget);
    });

    testWidgets('unchanged net worth reads as flat, with no direction arrow', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 1000)
        ..seedSnapshot('acc-cash', '2026-07', 1000);

      await _pumpTab(tester, repo);

      expect(find.byKey(const Key('networth-growth')), findsOneWidget);
      // 0% is neither a rise nor a fall — no direction arrow, no "Up".
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(find.text(_loc.networthGrowthUp), findsNothing);
      expect(find.text(_loc.networthGrowthDown), findsNothing);
      expect(find.text(_loc.networthGrowthFlat), findsOneWidget);
      expect(find.text('0.0%'), findsOneWidget);
    });

    testWidgets('the first recorded month shows no growth figure', (tester) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 1000);

      await _pumpTab(tester, repo);

      expect(find.byKey(const Key('networth-net-value')), findsOneWidget);
      expect(find.byKey(const Key('networth-growth')), findsNothing);
    });

    testWidgets('groups accounts into assets and liabilities with totals', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-07', 520000)
        ..seedSnapshot('acc-card', '2026-07', 41484);

      await _pumpTab(tester, repo);

      expect(find.text(_loc.networthAssetsTitle), findsOneWidget);
      expect(find.text(_loc.networthLiabilitiesTitle), findsOneWidget);
      expect(find.byKey(const Key('account-row-acc-cash')), findsOneWidget);
      expect(find.byKey(const Key('account-row-acc-card')), findsOneWidget);
      expect(find.text('520000'), findsNWidgets(2)); // row value + assets total
      expect(find.text('41484'), findsNWidgets(2));
    });

    testWidgets('an account with no snapshot this month reads as not recorded', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 100);

      await _pumpTab(tester, repo);

      expect(find.text(_loc.networthNotRecorded), findsOneWidget);
    });

    testWidgets('an archived account leaves the entry list', (tester) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 100);
      final controller = await _pumpTab(tester, repo);

      await controller.updateAccount('token', 'acc-card', archived: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-row-acc-card')), findsNothing);
      expect(find.byKey(const Key('account-row-acc-cash')), findsOneWidget);
    });

    testWidgets(
      "an archived account's snapshot is explained, so the group total still "
      'adds up to what is on screen',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..seedSnapshot('acc-cash', '2026-07', 100)
          ..seedSnapshot('acc-card', '2026-07', 50);
        final controller = await _pumpTab(tester, repo);

        await controller.updateAccount('token', 'acc-card', archived: true);
        await tester.pumpAndSettle();

        // The row is gone, but its 50 still counts toward the backend's
        // liability total — so the difference is spelled out rather than
        // leaving an unexplained gap between the rows and the total.
        expect(find.byKey(const Key('account-row-acc-card')), findsNothing);
        final archivedRow = find.byKey(const Key('networth-archived-liability'));
        expect(archivedRow, findsOneWidget);
        expect(
          find.descendant(of: archivedRow, matching: find.text(_loc.networthArchivedSubtotal)),
          findsOneWidget,
        );
        // 0 listed rows + 50 archived = the 50 liability total on screen.
        expect(
          find.descendant(of: archivedRow, matching: find.text('50')),
          findsOneWidget,
        );
        // Assets hold no archived snapshot, so no such row there.
        expect(find.byKey(const Key('networth-archived-asset')), findsNothing);
      },
    );

    testWidgets('tapping an account row asks to edit that account', (tester) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 100);
      final tapped = <NetWorthAccount>[];

      await _pumpTab(tester, repo, tapped: tapped);
      await tester.tap(find.byKey(const Key('account-row-acc-cash')));

      expect(tapped.single.id, 'acc-cash');
    });

    testWidgets('a month with no snapshots shows the record-first guide', (
      tester,
    ) async {
      await _pumpTab(tester, FakeFinanceRepository());

      expect(find.byKey(const Key('networth-empty-title')), findsOneWidget);
      expect(find.byKey(const Key('networth-empty-cta')), findsOneWidget);
    });

    testWidgets(
      'with no accounts at all the empty-state CTA opens account management '
      'instead of being a dead button',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = FakeFinanceRepository()..accounts = const [];
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');
        var managed = false;
        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => NetWorthTab(
                  controller: controller,
                  onSwitchMonth: (m) => controller.load('token', m),
                  onEditAccountValue: (_) {},
                  onManageAccounts: () => managed = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cta = find.byKey(const Key('networth-empty-cta'));
        expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
        await tester.tap(cta);
        await tester.pump();

        expect(managed, isTrue);
      },
    );

    testWidgets('a trend with fewer than two points shows the shortfall note', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 100);

      await _pumpTab(tester, repo);

      expect(find.byKey(const Key('networth-trend-insufficient')), findsOneWidget);
      expect(find.byKey(const Key('networth-trend-chart')), findsNothing);
    });

    testWidgets('two or more points draw the trend chart', (tester) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 100)
        ..seedSnapshot('acc-cash', '2026-07', 200);

      await _pumpTab(tester, repo);

      expect(find.byKey(const Key('networth-trend-chart')), findsOneWidget);
      expect(find.byKey(const Key('networth-trend-insufficient')), findsNothing);
    });

    testWidgets('the month arrows switch months through the shared header', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 100)
        ..seedSnapshot('acc-cash', '2026-07', 200);
      final controller = await _pumpTab(tester, repo);

      expect(find.byKey(const Key('networth-month-label')), findsOneWidget);
      await tester.tap(find.byKey(const Key('networth-month-previous')));
      await tester.pumpAndSettle();

      expect(controller.selectedMonth, '2026-06');
      expect(find.text(_monthLabel(2026, 6)), findsOneWidget);
      expect(find.text('100'), findsWidgets);
    });

    testWidgets('a stale month response never renders under the current month', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 111)
        ..seedSnapshot('acc-cash', '2026-07', 222);
      final controller = await _pumpTab(tester, repo);

      final juneGate = Completer<void>();
      repo.monthlyGates['2026-06'] = juneGate;
      final june = controller.load('token', '2026-06', notifyOnStart: true);
      await controller.load('token', '2026-07', notifyOnStart: true);
      juneGate.complete();
      await june;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('networth-month-label')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('networth-month-label'))).data,
        _monthLabel(2026, 7),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('networth-net-value'))).data,
        '222',
      );
    });

    testWidgets('a load failure offers a retry', (tester) async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      repo.failNext = const FinanceFetchFailure('offline');
      await controller.load('token', '2026-07');
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => NetWorthTab(
                controller: controller,
                onSwitchMonth: (m) => controller.load('token', m),
                onEditAccountValue: (_) {},
                onManageAccounts: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('networth-retry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('networth-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('networth-net-value')), findsOneWidget);
    });

    testWidgets(
      'tapping the month label jumps to a picked month through onSwitchMonth',
      (tester) async {
        final repo = FakeFinanceRepository()
          ..seedSnapshot('acc-cash', '2026-07', 222)
          ..seedSnapshot('acc-cash', '2025-07', 111);
        final controller = await _pumpTab(tester, repo);

        await tester.tap(find.byKey(const Key('networth-month-label')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-year-previous')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-month-7')));
        await tester.pumpAndSettle();

        expect(controller.selectedMonth, '2025-07');
        expect(
          tester.widget<Text>(find.byKey(const Key('networth-month-label'))).data,
          _monthLabel(2025, 7),
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('networth-net-value'))).data,
          '111',
        );
      },
    );

    testWidgets('dismissing the month picker leaves the month alone', (
      tester,
    ) async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 222);
      final controller = await _pumpTab(tester, repo);

      await tester.tap(find.byKey(const Key('networth-month-label')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(controller.selectedMonth, '2026-07');
      expect(
        tester.widget<Text>(find.byKey(const Key('networth-month-label'))).data,
        _monthLabel(2026, 7),
      );
    });

    // Regression: the month label's `▾` affordance added padding + an icon to
    // a centred, non-shrinkable Row. Widget tests default to an 800x600
    // surface, so nothing else in this mobile-first PWA's suite caught it.
    // Pumped inline rather than through `_pumpTab`, which forces a 600dp-wide
    // surface for the trend section.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the month header does not overflow at ${width.toInt()}dp, '
          'locale=$locale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 2400));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            final controller = testNetWorthController(FakeFinanceRepository());
            await controller.load('token', '2026-07');
            await tester.pumpWidget(
              l10nTestApp(
                locale: locale,
                home: Scaffold(
                  body: NetWorthTab(
                    controller: controller,
                    onSwitchMonth: (m) async {},
                    onEditAccountValue: (a) {},
                    onManageAccounts: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expectMonthLabelFullyVisible(
              tester,
              const Key('networth-month-label'),
            );
            expectMonthLabelReadable(tester, const Key('networth-month-label'));
            final header = tester.getRect(find.byType(MonthNavHeader));
            final prev = tester.getRect(
              find.byKey(const Key('networth-month-previous')),
            );
            final next = tester.getRect(
              find.byKey(const Key('networth-month-next')),
            );
            expect(prev.left, greaterThanOrEqualTo(header.left));
            expect(next.right, lessThanOrEqualTo(header.right));
          },
        );
      }
    }
  });

  // The tab's own overflow guard, covering two independent failures: the
  // account-group subtotal Row (15px past 320dp/en at a 1x text scale) and
  // the account `ListTile`s, whose trailing amount could not be laid out at
  // a 2x text scale — the latter not a RenderFlex overflow at all, which is
  // why this asserts on *any* layout error. Pumped inline rather than
  // through `_pumpTab`, which forces a 600dp-wide surface.
  group('narrow-width layout guard', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the tab lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 2400));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repo = FakeFinanceRepository()
                ..seedSnapshot('acc-cash', '2026-07', 1234567);
              final controller = testNetWorthController(repo);
              await controller.load('token', '2026-07');

              await expectNoLayoutErrors(() async {
                await tester.pumpWidget(
                  l10nTestApp(
                    locale: locale,
                    home: Scaffold(
                      body: NetWorthTab(
                        controller: controller,
                        onSwitchMonth: (m) async {},
                        onEditAccountValue: (a) {},
                        onManageAccounts: () {},
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
              });

              // The account rows must also stay *queryable*: when a
              // `ListTile` fails to lay out, `evaluate()` itself throws.
              expect(
                find.byKey(const Key('account-row-acc-cash')).evaluate(),
                isNotEmpty,
              );
            },
          );
        }
      }
    }
  });

  // Right-alignment guard, the other half of the narrow-width work: making
  // the money column shrinkable must not stop it hugging the card edge. A
  // *loose* `Flexible` shrink-wraps the amount and leaves the slack after
  // it, so `TextAlign.end` aligns inside a too-narrow box and the column
  // drifts inward — 31px at 390dp and 136px at 800dp when that regressed,
  // i.e. worse the wider the screen. All three money rows of a group (an
  // account, the archived subtotal, the group total) must share one edge.
  group('money column alignment', () {
    for (final width in [390.0, 600.0, 800.0]) {
      testWidgets('every amount in a group ends at the card edge at ${width.toInt()}dp', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = FakeFinanceRepository()
          ..accounts = [
            ...FakeFinanceRepository().accounts,
            const NetWorthAccount(
              id: 'acc-old',
              kind: NetWorthKind.asset,
              name: 'Closed savings',
              sortOrder: 1,
              archived: true,
            ),
          ]
          ..seedSnapshot('acc-cash', '2026-07', 1234567)
          ..seedSnapshot('acc-old', '2026-07', 42)
          // A non-zero liability keeps the asset-group total (1234609)
          // different from the net worth headline, so the total below is
          // found by its text alone.
          ..seedSnapshot('acc-card', '2026-07', 9);
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');

        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: NetWorthTab(
                controller: controller,
                onSwitchMonth: (m) async {},
                onEditAccountValue: (a) {},
                onManageAccounts: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Each amount is measured against the right edge of its own row, so
        // no padding constant is baked into the test. (The `ListTile` rows
        // sit 8px further in than the two padded rows — its own content
        // inset, the same on main.)
        final archivedRow = find.byKey(const Key('networth-archived-asset'));
        expect(archivedRow, findsOneWidget);

        void expectFlushRight(Finder row, Finder amount, String what) {
          final rowRight = tester
              .getRect(find.descendant(of: row, matching: find.byType(Row)).first)
              .right;
          expect(
            paintedTextRight(tester, find.descendant(of: row, matching: amount)),
            closeTo(rowRight, 0.5),
            reason: '$what must hug its row\'s right edge',
          );
        }

        expectFlushRight(
          find.byKey(const Key('account-row-acc-cash')),
          find.text('1234567'),
          'the account amount',
        );
        expectFlushRight(archivedRow, find.text('42'), 'the archived subtotal');
        expectFlushRight(
          find.ancestor(of: find.text('1234609'), matching: find.byType(Padding)).first,
          find.text('1234609'),
          'the group total',
        );

        // The two rows that share a padding must also share one edge, so the
        // money column reads as a column.
        expect(
          paintedTextRight(
            tester,
            find.descendant(of: archivedRow, matching: find.text('42')),
          ),
          closeTo(paintedTextRight(tester, find.text('1234609')), 0.5),
        );
      });
    }

    // The degenerate half of the same guard, and the one the tests above
    // cannot see. While an amount fits on one line its box *is* its glyphs, so
    // `textAlign: TextAlign.end` changes nothing and dropping it from these
    // three rows leaves every alignment test green — QA deleted all four
    // `TextAlign.end` in the app and the suite stayed green. It only starts
    // mattering once the amount is too wide for the row and wraps: the row
    // caps it at the full width, and the alignment is then the only thing
    // holding the continuation lines against the edge (measured 200.0 with it
    // vs 193.4 without on a 200dp row). So this pins the wrapped case, on
    // every line, for all three money rows.
    testWidgets('an amount too wide for the row wraps right-aligned', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const accountAmount = '123456789012345678';
      const archivedAmount = '123456789012345679';
      const groupTotal = '246913578024691357'; // the two above, summed
      final repo = FakeFinanceRepository()
        ..accounts = [
          ...FakeFinanceRepository().accounts,
          const NetWorthAccount(
            id: 'acc-old',
            kind: NetWorthKind.asset,
            name: 'Closed savings',
            sortOrder: 1,
            archived: true,
          ),
        ]
        ..seedSnapshot('acc-cash', '2026-07', int.parse(accountAmount))
        ..seedSnapshot('acc-old', '2026-07', int.parse(archivedAmount))
        ..seedSnapshot('acc-card', '2026-07', 9);
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: NetWorthTab(
              controller: controller,
              onSwitchMonth: (m) async {},
              onEditAccountValue: (a) {},
              onManageAccounts: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectWrappedFlushRight(Finder row, Finder amount, String what) {
        final inRow = find.descendant(of: row, matching: amount);
        final rowRight = tester
            .getRect(find.descendant(of: row, matching: find.byType(Row)).first)
            .right;
        expect(
          paintedTextLineCount(tester, inRow),
          greaterThan(1),
          reason: '$what must be wide enough to wrap for this to test anything',
        );
        for (final lineRight in paintedTextLineRights(tester, inRow)) {
          expect(
            lineRight,
            closeTo(rowRight, 0.5),
            reason: 'every wrapped line of $what must stay flush right',
          );
        }
      }

      expectWrappedFlushRight(
        find.byKey(const Key('account-row-acc-cash')),
        find.text(accountAmount),
        'the account amount',
      );
      expectWrappedFlushRight(
        find.byKey(const Key('networth-archived-asset')),
        find.text(archivedAmount),
        'the archived subtotal',
      );
      expectWrappedFlushRight(
        find.ancestor(of: find.text(groupTotal), matching: find.byType(Padding)).first,
        find.text(groupTotal),
        'the group total',
      );
    });
  });

  // The other half of that guard, and the third regression this row shape has
  // produced: making the halves shrinkable must not make them shrink when
  // there is room. A flex child is capped at its *share* of the row, so with
  // `Expanded`/`Flexible` on both halves every label is cut to 50% of the card
  // however wide the screen — `Total liabilities` wrapped to 3 lines at 390dp
  // and 2 at 430dp with the right half of the card empty. Labels at these
  // widths must stay on one line.
  group('label wrapping', () {
    for (final width in [390.0, 430.0, 600.0, 800.0]) {
      testWidgets('no label wraps at ${width.toInt()}dp', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = FakeFinanceRepository()
          ..accounts = [
            ...FakeFinanceRepository().accounts,
            const NetWorthAccount(
              id: 'acc-old',
              kind: NetWorthKind.asset,
              name: 'Closed savings',
              sortOrder: 1,
              archived: true,
            ),
          ]
          ..seedSnapshot('acc-cash', '2026-07', 1234567)
          ..seedSnapshot('acc-old', '2026-07', 42)
          ..seedSnapshot('acc-card', '2026-07', 9);
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');

        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: NetWorthTab(
                controller: controller,
                onSwitchMonth: (m) async {},
                onEditAccountValue: (a) {},
                onManageAccounts: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // `Total liabilities` is the longest of these and the one that
        // regressed; the others come along so a partial fix can't pass.
        for (final label in [
          _loc.networthTotalLiabilities,
          _loc.networthTotalAssets,
          _loc.networthArchivedSubtotal,
          '台幣活存',
        ]) {
          expect(
            paintedTextLineCount(tester, find.text(label)),
            1,
            reason: '"$label" has room for one line at ${width.toInt()}dp',
          );
        }
      });
    }
  });
}
