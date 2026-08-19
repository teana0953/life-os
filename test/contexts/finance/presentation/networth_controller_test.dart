import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';

import '../finance_test_support.dart';

void main() {
  group('NetWorthController', () {
    test('load lands the month, its accounts, and its trend', () async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-07', 520000)
        ..seedSnapshot('acc-card', '2026-07', 41484)
        ..seedSnapshot('acc-cash', '2026-06', 460181);
      final controller = testNetWorthController(repo);

      await controller.load('token', '2026-07');

      expect(controller.status, FinanceStatus.loaded);
      expect(controller.selectedMonth, '2026-07');
      expect(controller.accounts, hasLength(2));
      expect(controller.monthly!.netWorth, 478516);
      expect(controller.monthly!.prevNetWorth, 460181);
      expect(controller.trend.map((p) => p.month), ['2026-06', '2026-07']);
    });

    test('the trend window spans the 12 months ending at the selected month', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);

      await controller.load('token', '2026-07');

      expect(repo.trendCalls, ['2025-08..2026-07']);
    });

    test('does not notify before the first await', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      var notifications = 0;
      controller.addListener(() => notifications++);

      final pending = controller.load('token', '2026-07');
      expect(notifications, 0);

      await pending;
      expect(notifications, 1);
    });

    test('notifyOnStart lets a user gesture show loading immediately', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      var notifications = 0;
      controller.addListener(() => notifications++);

      final pending = controller.load('token', '2026-06', notifyOnStart: true);
      expect(notifications, 1);
      expect(controller.status, FinanceStatus.loading);

      await pending;
    });

    test('switching months clears the previous month data synchronously', () async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 100);
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      expect(controller.monthly, isNotNull);

      final gate = Completer<void>();
      repo.monthlyGates['2026-08'] = gate;
      final pending = controller.load('token', '2026-08');

      // Synchronously, before the response lands: no stale July figures
      // showing under an August label.
      expect(controller.selectedMonth, '2026-08');
      expect(controller.monthly, isNull);

      gate.complete();
      await pending;
      expect(controller.monthly!.month, '2026-08');
    });

    test('a stale month response never lands over the current month', () async {
      final repo = FakeFinanceRepository()
        ..seedSnapshot('acc-cash', '2026-06', 111)
        ..seedSnapshot('acc-cash', '2026-07', 222);
      final controller = testNetWorthController(repo);

      final juneGate = Completer<void>();
      repo.monthlyGates['2026-06'] = juneGate;
      final june = controller.load('token', '2026-06');
      final july = controller.load('token', '2026-07');
      await july;

      // June's slow response resolves last — and must be discarded.
      juneGate.complete();
      await june;

      expect(controller.selectedMonth, '2026-07');
      expect(controller.monthly!.month, '2026-07');
      expect(controller.monthly!.netWorth, 222);
    });

    test('the selected month is independent of the ledger controller', () async {
      final repo = FakeFinanceRepository();
      final ledger = testFinanceController(repo);
      final networth = testNetWorthController(repo);

      await ledger.load('token', '2026-07');
      await networth.load('token', '2026-03');
      await ledger.load('token', '2026-08');

      expect(networth.selectedMonth, '2026-03');
      expect(ledger.selectedMonth, '2026-08');
    });

    test('saveSnapshot upserts the selected month then reloads', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      await controller.saveSnapshot('token', accountId: 'acc-cash', value: 30000);

      expect(repo.networthCalls, ['upsert:acc-cash:2026-07:30000']);
      expect(controller.status, FinanceStatus.loaded);
      expect(controller.monthly!.netWorth, 30000);
    });

    test('saveSnapshot accepts 0 as a legal value', () async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 500);
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      await controller.saveSnapshot('token', accountId: 'acc-cash', value: 0);

      expect(repo.networthCalls, ['upsert:acc-cash:2026-07:0']);
      expect(controller.monthly!.netWorth, 0);
    });

    test('saveSnapshot never sends a negative value', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      await controller.saveSnapshot('token', accountId: 'acc-cash', value: -1);

      expect(repo.networthCalls, isEmpty);
      expect(controller.status, FinanceStatus.error);
      expect(controller.error, FinanceError.validation);
    });

    test('createAccount reloads the month with the new account', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      await controller.createAccount('token', kind: NetWorthKind.asset, name: '黃金');

      expect(repo.networthCalls, ['create:asset:黃金']);
      expect(controller.accounts.map((a) => a.name), contains('黃金'));
      expect(controller.status, FinanceStatus.loaded);
    });

    test('updateAccount (archive) reloads the month', () async {
      final repo = FakeFinanceRepository();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      await controller.updateAccount('token', 'acc-cash', archived: true);

      expect(repo.networthCalls.single, contains('archived=true'));
      expect(
        controller.accounts.firstWhere((a) => a.id == 'acc-cash').archived,
        isTrue,
      );
    });

    test('a 401 on load surfaces needsReauth', () async {
      final repo = FakeFinanceRepository()
        ..failNext = const FinanceReauthenticationRequired();
      final controller = testNetWorthController(repo);

      await controller.load('token', '2026-07');

      expect(controller.status, FinanceStatus.needsReauth);
    });

    test('a 401 on a write surfaces needsReauth without wiping the month', () async {
      final repo = FakeFinanceRepository()..seedSnapshot('acc-cash', '2026-07', 100);
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');

      repo.failNext = const FinanceReauthenticationRequired();
      await controller.saveSnapshot('token', accountId: 'acc-cash', value: 200);

      expect(controller.status, FinanceStatus.needsReauth);
      expect(controller.monthly!.netWorth, 100);
    });

    test('a load failure surfaces a retryable error state', () async {
      final repo = FakeFinanceRepository()
        ..failNext = const FinanceFetchFailure('offline');
      final controller = testNetWorthController(repo);

      await controller.load('token', '2026-07');

      expect(controller.status, FinanceStatus.error);
      expect(controller.error, FinanceError.fetchFailed);
      expect(controller.monthly, isNull);
    });

    group('lastLoadedAt (#198)', () {
      test('a successful load stamps the injected clock', () async {
        final controller = testNetWorthController(
          FakeFinanceRepository(),
          clock: () => DateTime(2026, 8, 19, 9, 30),
        );

        await controller.load('token', '2026-07');

        expect(controller.lastLoadedAt, DateTime(2026, 8, 19, 9, 30));
      });

      test(
        'a failed load leaves the previous stamp untouched — the label must '
        'describe the data on screen, which a failure did not change',
        () async {
          final repo = FakeFinanceRepository();
          var now = DateTime(2026, 8, 19, 9, 30);
          final controller = testNetWorthController(repo, clock: () => now);
          await controller.load('token', '2026-07');

          now = DateTime(2026, 8, 19, 10, 0);
          repo.failNext = const FinanceFetchFailure('offline');
          await controller.load('token', '2026-07');

          expect(controller.status, FinanceStatus.error);
          expect(controller.lastLoadedAt, DateTime(2026, 8, 19, 9, 30));
        },
      );

      test(
        'a response for a month the user has switched away from does not '
        'stamp: its data was discarded, so it never refreshed anything',
        () async {
          final repo = FakeFinanceRepository();
          var now = DateTime(2026, 8, 19, 9, 30);
          final controller = testNetWorthController(repo, clock: () => now);

          final gate = Completer<void>();
          repo.monthlyGates['2026-07'] = gate;
          final stale = controller.load('token', '2026-07');

          now = DateTime(2026, 8, 19, 10, 0);
          await controller.load('token', '2026-08');
          expect(controller.lastLoadedAt, DateTime(2026, 8, 19, 10, 0));

          now = DateTime(2026, 8, 19, 11, 0);
          gate.complete();
          await stale;

          expect(controller.lastLoadedAt, DateTime(2026, 8, 19, 10, 0));
        },
      );

      test(
        'reset() clears it — this app-lifetime singleton would otherwise show '
        "the previous account's load time to the next one (#156)",
        () async {
          final controller = testNetWorthController(
            FakeFinanceRepository(),
            clock: () => DateTime(2026, 8, 19, 9, 30),
          );
          await controller.load('token', '2026-07');
          expect(controller.lastLoadedAt, isNotNull);

          controller.reset();

          expect(controller.lastLoadedAt, isNull);
        },
      );
    });
  });
}
