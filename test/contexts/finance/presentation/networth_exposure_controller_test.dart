import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/application/exposure_settings.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/finance/presentation/finance_controller.dart';
import 'package:life_os/contexts/finance/presentation/networth_controller.dart';

import '../exposure_test_support.dart';
import '../finance_test_support.dart';

void main() {
  for (final refreshFinishesFirst in [true, false]) {
    test(
      'snapshot save reconciles concurrent refresh, refresh first=$refreshFinishesFirst',
      () async {
        final repo = _SequencedRepository()
          ..seedSnapshot('acc-cash', '2026-07', 100)
          ..seedSnapshot('acc-card', '2026-07', 0);
        final store = FakeExposureSettingsRepository()
          ..values['a'] = {'acc-cash': ExposureFactor.leveraged2};
        final controller = testNetWorthController(
          repo,
          exposureSettings: ExposureSettings(store),
        );
        await controller.loadForUser('a');
        await controller.load('token', '2026-07');
        repo.writeGate = Completer<void>();
        final save = controller.saveSnapshot(
          'token',
          accountId: 'acc-cash',
          value: 200,
        );
        final readGate = Completer<void>();
        if (!refreshFinishesFirst) repo.nextGate = readGate;
        final refresh = controller.load('token', '2026-07');
        await Future<void>.delayed(Duration.zero);
        if (refreshFinishesFirst) {
          await refresh;
          expect(controller.monthly!.netWorth, 100);
        }
        repo.writeGate!.complete();
        await save;
        if (!refreshFinishesFirst) {
          readGate.complete();
          await refresh;
        }
        expect(controller.selectedMonth, '2026-07');
        expect(controller.monthly!.netWorth, 200);
        expect(controller.exposure!.totalExposure, 400);
      },
    );
  }

  test(
    'snapshot completion reloads visible month without moving back to source month',
    () async {
      final repo = _SequencedRepository()
        ..seedSnapshot('acc-cash', '2026-07', 100)
        ..seedSnapshot('acc-cash', '2026-08', 300);
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      repo.writeGate = Completer<void>();
      final save = controller.saveSnapshot(
        'token',
        accountId: 'acc-cash',
        value: 200,
      );
      await controller.load('token', '2026-08');
      repo.writeGate!.complete();
      await save;
      expect(repo.snapshots['acc-cash']!['2026-07'], 200);
      expect(controller.selectedMonth, '2026-08');
      expect(controller.monthly!.netWorth, 300);
    },
  );

  for (final (failure, status, error) in [
    (const FinanceReauthenticationRequired(), FinanceStatus.needsReauth, null),
    (
      const FinanceValidationFailure(),
      FinanceStatus.error,
      FinanceError.validation,
    ),
    (
      const FinanceFetchFailure('offline'),
      FinanceStatus.error,
      FinanceError.fetchFailed,
    ),
  ]) {
    test(
      'pending refresh cannot discard snapshot write error $failure',
      () async {
        final repo = _SequencedRepository()
          ..seedSnapshot('acc-cash', '2026-07', 100);
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');
        repo.writeGate = Completer<void>();
        repo.writeFailure = failure;
        final save = controller.saveSnapshot(
          'token',
          accountId: 'acc-cash',
          value: 200,
        );
        final gate = Completer<void>();
        repo.nextGate = gate;
        final refresh = controller.load('token', '2026-07');
        await Future<void>.delayed(Duration.zero);
        repo.writeGate!.complete();
        await save;
        gate.complete();
        await refresh;
        expect(controller.status, status);
        expect(controller.error, error);
        expect(controller.monthly!.netWorth, 100);
      },
    );
  }

  for (final refreshFinishesFirst in [true, false]) {
    test(
      'reorder reconciles concurrent refresh, refresh first=$refreshFinishesFirst',
      () async {
        final repo = _SequencedRepository();
        final other = await repo.createNetWorthAccount(
          'token',
          kind: NetWorthKind.asset,
          name: 'Other',
        );
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');
        final gate = Completer<void>();
        repo.reorderGate = gate.future;
        final save = controller.reorderAccounts('token', NetWorthKind.asset, [
          other.id,
          'acc-cash',
        ]);
        final readGate = Completer<void>();
        if (!refreshFinishesFirst) repo.nextGate = readGate;
        final refresh = controller.load('token', '2026-07');
        await Future<void>.delayed(Duration.zero);
        if (refreshFinishesFirst) await refresh;
        gate.complete();
        expect(await save, isTrue);
        if (!refreshFinishesFirst) {
          readGate.complete();
          await refresh;
        }
        expect(
          controller.accounts.firstWhere((a) => a.id == other.id).sortOrder,
          0,
        );
        expect(
          controller.accounts.firstWhere((a) => a.id == 'acc-cash').sortOrder,
          1,
        );
        expect(controller.status, FinanceStatus.loaded);
      },
    );
  }

  test('reorder reauthentication error survives concurrent refresh', () async {
    final repo = _SequencedRepository();
    final controller = testNetWorthController(repo);
    await controller.load('token', '2026-07');
    final gate = Completer<void>();
    repo.reorderGate = gate.future;
    final save = controller.reorderAccounts('token', NetWorthKind.asset, [
      'acc-cash',
    ]);
    final readGate = Completer<void>();
    repo.nextGate = readGate;
    final refresh = controller.load('token', '2026-07');
    await Future<void>.delayed(Duration.zero);
    repo.failNext = const FinanceReauthenticationRequired();
    gate.complete();
    expect(await save, isFalse);
    readGate.complete();
    await refresh;
    expect(controller.status, FinanceStatus.needsReauth);
  });

  test(
    'failed reorder after refresh reports failure and preserves saved order',
    () async {
      final repo = _SequencedRepository();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      final gate = Completer<void>();
      repo.reorderGate = gate.future;
      final save = controller.reorderAccounts('token', NetWorthKind.asset, [
        'acc-cash',
      ]);
      await controller.load('token', '2026-07');
      repo.failNext = const FinanceFetchFailure('offline');
      gate.complete();
      expect(await save, isFalse);
      expect(controller.accounts.first.sortOrder, 0);
      expect(controller.status, FinanceStatus.loaded);
    },
  );

  test('stored factors use selected month values and archived rows', () async {
    final repo = FakeFinanceRepository()
      ..seedSnapshot('acc-cash', '2026-07', 100)
      ..seedSnapshot('acc-card', '2026-07', 40)
      ..seedSnapshot('acc-cash', '2026-08', 200)
      ..seedSnapshot('acc-card', '2026-08', 20);
    final store = FakeExposureSettingsRepository()
      ..values['a'] = {'acc-cash': ExposureFactor.leveraged2};
    final controller = testNetWorthController(
      repo,
      exposureSettings: ExposureSettings(store),
    );
    await controller.loadForUser('a');
    await controller.load('a-token', '2026-07');
    expect(controller.exposure!.totalExposure, 200);
    expect(controller.exposure!.leverage, closeTo(200 / 60, 0.0001));
    await controller.updateAccount('a-token', 'acc-cash', archived: true);
    expect(controller.exposure!.totalExposure, 200);
    expect(
      await controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged3,
        session: controller.exposureSession,
      ),
      isTrue,
    );
    expect(controller.exposure!.totalExposure, 300);
    await controller.load('a-token', '2026-08');
    expect(controller.exposure!.totalExposure, 600);
    expect(controller.exposure!.netWorth, 180);
  });

  test('read failure is explicit, retryable and blocks changes', () async {
    final store = FakeExposureSettingsRepository()..failRead = true;
    final controller = testNetWorthController(
      FakeFinanceRepository(),
      exposureSettings: ExposureSettings(store),
    );
    await controller.loadForUser('a');
    expect(
      controller.exposureSettingsStatus,
      ExposureSettingsStatus.readFailed,
    );
    expect(
      await controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.cash,
        session: controller.exposureSession,
      ),
      isFalse,
    );
    expect(store.writes, isEmpty);
    store.failRead = false;
    await controller.reloadExposureSettings();
    expect(controller.exposureSettingsStatus, ExposureSettingsStatus.ready);
  });

  test(
    'no optimistic factor and a failed save leaves the saved value selected',
    () async {
      final store = FakeExposureSettingsRepository()
        ..values['a'] = {'acc-cash': ExposureFactor.cash}
        ..writeGate = Completer<void>();
      final controller = testNetWorthController(
        FakeFinanceRepository(),
        exposureSettings: ExposureSettings(store),
      );
      await controller.loadForUser('a');
      await controller.load('token', '2026-07');
      final save = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: controller.exposureSession,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.exposureSaving, isTrue);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
      store.failWrite = true;
      store.writeGate!.complete();
      expect(await save, isFalse);
      expect(controller.exposureSaveFailed, isTrue);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
      store.failWrite = false;
      expect(
        await controller.saveExposureFactor(
          'acc-cash',
          ExposureFactor.leveraged2,
          session: controller.exposureSession,
        ),
        isTrue,
      );
      expect(controller.exposureSaveFailed, isFalse);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.leveraged2);
    },
  );

  test(
    'overlapping same-account and different-account writes are serialized',
    () async {
      final repo = FakeFinanceRepository();
      await repo.createNetWorthAccount(
        'token',
        kind: NetWorthKind.asset,
        name: 'other',
      );
      final other = repo.accounts.last.id;
      final store = FakeExposureSettingsRepository()
        ..writeGate = Completer<void>();
      final controller = testNetWorthController(
        repo,
        exposureSettings: ExposureSettings(store),
      );
      await controller.loadForUser('a');
      await controller.load('token', '2026-07');
      final session = controller.exposureSession;
      final first = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: session,
      );
      final second = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged3,
        session: session,
      );
      final third = controller.saveExposureFactor(
        other,
        ExposureFactor.cash,
        session: session,
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, hasLength(1));
      store.writeGate!.complete();
      expect(await Future.wait([first, second, third]), [true, true, true]);
      expect(store.maxConcurrentWrites, 1);
      expect(store.values['a'], {
        'acc-cash': ExposureFactor.leveraged3,
        other: ExposureFactor.cash,
      });
      expect(controller.exposureFactors, store.values['a']);
    },
  );

  test(
    'stale settings reads cannot cross users, including A to B to A',
    () async {
      final store = FakeExposureSettingsRepository()
        ..values['a'] = {'acc-cash': ExposureFactor.leveraged2}
        ..readGates['a'] = Completer<void>();
      final controller = testNetWorthController(
        FakeFinanceRepository(),
        exposureSettings: ExposureSettings(store),
      );
      final stale = controller.loadForUser('a');
      await Future<void>.delayed(Duration.zero);
      final oldGate = store.readGates.remove('a')!;
      await controller.loadForUser('b');
      expect(controller.exposureFactors, isEmpty);
      store.values['a'] = {'acc-cash': ExposureFactor.leveraged3};
      await controller.loadForUser('a');
      oldGate.complete();
      await stale;
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.leveraged3);
    },
  );

  test(
    'pending write remains under captured UID and returning user reads after it',
    () async {
      final store = FakeExposureSettingsRepository()
        ..writeGate = Completer<void>();
      final controller = testNetWorthController(
        FakeFinanceRepository(),
        exposureSettings: ExposureSettings(store),
      );
      await controller.loadForUser('a');
      await controller.load('a-token', '2026-07');
      final oldSession = controller.exposureSession;
      final save = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: oldSession,
      );
      final queued = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged3,
        session: oldSession,
      );
      await Future<void>.delayed(Duration.zero);
      controller.reset();
      expect(controller.monthly, isNull);
      expect(controller.exposureFactors, isEmpty);
      final bindB = controller.loadForUser('b');
      store.writeGate!.complete();
      expect(await save, isFalse);
      expect(await queued, isFalse);
      await bindB;
      expect(controller.exposureFactors, isEmpty);
      expect(store.values['b'], isNull);
      expect(
        await controller.saveExposureFactor(
          'acc-cash',
          ExposureFactor.cash,
          session: oldSession,
        ),
        isFalse,
      );
      await controller.loadForUser('a');
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.leveraged2);
      expect(store.writes, ['a:acc-cash:2']);
    },
  );

  test(
    'reset invalidates a pending response even if the new user selects the same month',
    () async {
      final repo = _SequencedRepository()
        ..seedSnapshot('acc-cash', '2026-07', 100);
      final controller = testNetWorthController(repo);
      final gate = Completer<void>();
      repo.nextGate = gate;
      final stale = controller.load('a-token', '2026-07');
      await Future<void>.delayed(Duration.zero);
      controller.reset();
      repo.seedSnapshot('acc-cash', '2026-07', 200);
      await controller.load('b-token', '2026-07');
      gate.complete();
      await stale;
      expect(controller.monthly!.netWorth, 200);
    },
  );

  test(
    'request identity rejects older same-month refresh and A-B-A month response',
    () async {
      final repo = _SequencedRepository()
        ..seedSnapshot('acc-cash', '2026-07', 100);
      final controller = testNetWorthController(repo);
      final gate = Completer<void>();
      repo.nextGate = gate;
      final stale = controller.load('token', '2026-07');
      await Future<void>.delayed(Duration.zero);
      await controller.load('token', '2026-08');
      repo.seedSnapshot('acc-cash', '2026-07', 300);
      await controller.load('token', '2026-07');
      gate.complete();
      await stale;
      expect(controller.monthly!.netWorth, 300);
      final refreshGate = Completer<void>();
      repo.nextGate = refreshGate;
      final refresh = controller.load('token', '2026-07');
      await Future<void>.delayed(Duration.zero);
      repo.seedSnapshot('acc-cash', '2026-07', 400);
      await controller.load('token', '2026-07');
      refreshGate.complete();
      await refresh;
      expect(controller.monthly!.netWorth, 400);
    },
  );

  test(
    'old snapshot completion cannot reload the new user with an old token',
    () async {
      final repo = _SequencedRepository();
      final controller = testNetWorthController(repo);
      await controller.load('a-token', '2026-07');
      repo.writeGate = Completer<void>();
      final save = controller.saveSnapshot(
        'a-token',
        accountId: 'acc-cash',
        value: 100,
      );
      controller.reset();
      await controller.load('b-token', '2026-07');
      final loads = repo.tokens.length;
      repo.writeGate!.complete();
      await save;
      expect(repo.tokens.length, loads);
      expect(controller.monthly!.netWorth, 0);
      expect(controller.status, FinanceStatus.loaded);
    },
  );

  test('all-month factor completion uses current month values', () async {
    final repo = FakeFinanceRepository()
      ..seedSnapshot('acc-cash', '2026-07', 100)
      ..seedSnapshot('acc-card', '2026-07', 0)
      ..seedSnapshot('acc-cash', '2026-08', 200)
      ..seedSnapshot('acc-card', '2026-08', 0);
    final store = FakeExposureSettingsRepository()
      ..writeGate = Completer<void>();
    final controller = testNetWorthController(
      repo,
      exposureSettings: ExposureSettings(store),
    );
    await controller.loadForUser('a');
    await controller.load('token', '2026-07');
    final save = controller.saveExposureFactor(
      'acc-cash',
      ExposureFactor.leveraged2,
      session: controller.exposureSession,
    );
    await Future<void>.delayed(Duration.zero);
    await controller.load('token', '2026-08');
    store.writeGate!.complete();
    expect(await save, isTrue);
    expect(controller.exposure!.totalExposure, 400);
  });
}

class _SequencedRepository extends FakeFinanceRepository {
  Completer<void>? nextGate;
  Completer<void>? writeGate;
  Object? writeFailure;
  final List<String> tokens = [];

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(
    String idToken,
    String month,
  ) async {
    tokens.add(idToken);
    final gate = nextGate;
    nextGate = null;
    final result = await super.getMonthlyNetWorth(idToken, month);
    await gate?.future;
    return result;
  }

  @override
  Future<NetWorthSnapshot> upsertNetWorthSnapshot(
    String idToken, {
    required String accountId,
    required String month,
    required int value,
  }) async {
    await writeGate?.future;
    if (writeFailure case final failure?) throw failure;
    return super.upsertNetWorthSnapshot(
      idToken,
      accountId: accountId,
      month: month,
      value: value,
    );
  }
}
