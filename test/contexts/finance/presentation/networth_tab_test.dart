import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_tab.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../finance_test_support.dart';

const _locale = Locale('en');
final _loc = lookupAppLocalizations(_locale);

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
      expect(find.text('2026-06'), findsOneWidget);
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
        '2026-07',
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
  });
}
