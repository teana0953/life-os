import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
        await repo.updateNetWorthAccount(
          'token',
          'acc-cash',
          exposure: (value: ExposureFactor.leveraged2),
        );
        final controller = testNetWorthController(repo);
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
    for (final refreshFinishesFirst in [false, true]) {
      test(
        'snapshot error $failure settles exposure after overlapping refresh, refresh first=$refreshFinishesFirst',
        () async {
          final repo = _SequencedRepository()
            ..seedSnapshot('acc-cash', '2026-07', 100);
          await repo.updateNetWorthAccount(
            'token',
            'acc-cash',
            exposure: (value: ExposureFactor.cash),
          );
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
          if (refreshFinishesFirst) {
            gate.complete();
            await refresh;
          }
          repo.writeGate!.complete();
          await save;
          if (!refreshFinishesFirst) {
            gate.complete();
            await refresh;
          }
          expect(controller.status, status);
          expect(controller.error, error);
          expect(controller.monthly!.netWorth, 100);
          expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
          expect(
            controller.exposureSettingsStatus,
            refreshFinishesFirst && status != FinanceStatus.needsReauth
                ? ExposureSettingsStatus.ready
                : ExposureSettingsStatus.readFailed,
          );
          await controller.reloadExposureSettings(
            () async => 'token',
            session: controller.exposureSession,
          );
          expect(
            controller.exposureSettingsStatus,
            ExposureSettingsStatus.ready,
          );
          expect(
            await controller.saveExposureFactor(
              'acc-cash',
              ExposureFactor.leveraged2,
              session: controller.exposureSession,
              idToken: () async => 'token',
            ),
            isTrue,
          );
        },
      );
    }
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
        await repo.updateNetWorthAccount(
          'token',
          'acc-cash',
          exposure: (value: ExposureFactor.leveraged2),
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
        expect(
          controller.exposureFactors['acc-cash'],
          ExposureFactor.leveraged2,
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

  test('factor completion preserves a concurrent rename and archive', () async {
    final repo = ExposureTestRepository()..factorWriteGate = Completer<void>();
    final controller = testNetWorthController(repo);
    await controller.load('token', '2026-07');
    final save = controller.saveExposureFactor(
      'acc-cash',
      ExposureFactor.leveraged2,
      session: controller.exposureSession,
      idToken: () async => 'token',
    );
    await Future<void>.delayed(Duration.zero);
    await controller.updateAccount(
      'token',
      'acc-cash',
      name: 'Renamed',
      archived: true,
    );
    repo.factorWriteGate!.complete();
    expect(await save, isTrue);
    final account = controller.accounts.firstWhere((a) => a.id == 'acc-cash');
    expect(account.name, 'Renamed');
    expect(account.archived, isTrue);
    expect(account.exposureFactor, ExposureFactor.leveraged2);
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
    await repo.updateNetWorthAccount(
      'token',
      'acc-cash',
      exposure: (value: ExposureFactor.leveraged2),
    );
    final controller = testNetWorthController(repo);
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
        idToken: () async => 'token',
      ),
      isTrue,
    );
    expect(controller.exposure!.totalExposure, 300);
    await controller.load('a-token', '2026-08');
    expect(controller.exposure!.totalExposure, 600);
    expect(controller.exposure!.netWorth, 180);
  });

  test(
    'read failure preserves confirmed factors and retries through normal reload',
    () async {
      final repo = ExposureTestRepository()
        ..setFactor('acc-cash', ExposureFactor.cash);
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      repo.failRead = true;
      await controller.load('token', '2026-07');
      expect(
        controller.exposureSettingsStatus,
        ExposureSettingsStatus.readFailed,
      );
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
      expect(
        await controller.saveExposureFactor(
          'acc-cash',
          ExposureFactor.leveraged2,
          session: controller.exposureSession,
          idToken: () async => 'token',
        ),
        isFalse,
      );
      expect(repo.factorWrites, isEmpty);
      repo.failRead = false;
      await controller.reloadExposureSettings(
        () async => 'token',
        session: controller.exposureSession,
      );
      expect(controller.exposureSettingsStatus, ExposureSettingsStatus.ready);
    },
  );

  test(
    'no optimistic factor and failed save retains selection until retry',
    () async {
      final repo = ExposureTestRepository()
        ..setFactor('acc-cash', ExposureFactor.cash)
        ..factorWriteGate = Completer<void>();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      final save = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: controller.exposureSession,
        idToken: () async => 'token',
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.exposureSaving, isTrue);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
      repo.failWrite = true;
      repo.factorWriteGate!.complete();
      expect(await save, isFalse);
      expect(controller.exposureSaveFailed, isTrue);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
      repo.failWrite = false;
      expect(
        await controller.saveExposureFactor(
          'acc-cash',
          ExposureFactor.leveraged2,
          session: controller.exposureSession,
          idToken: () async => 'token',
        ),
        isTrue,
      );
      expect(controller.exposureSaveFailed, isFalse);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.leveraged2);
    },
  );

  test(
    'overlapping writes serialize and resolve fresh tokens when dispatched',
    () async {
      final repo = ExposureTestRepository()
        ..factorWriteGate = Completer<void>();
      final other = await repo.createNetWorthAccount(
        'token',
        kind: NetWorthKind.asset,
        name: 'other',
      );
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      var tokenCalls = 0;
      Future<String> token() async => 'fresh-${++tokenCalls}';
      final session = controller.exposureSession;
      final first = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: session,
        idToken: token,
      );
      final second = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged3,
        session: session,
        idToken: token,
      );
      final third = controller.saveExposureFactor(
        other.id,
        ExposureFactor.cash,
        session: session,
        idToken: token,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.factorWrites, ['fresh-1:acc-cash:2']);
      repo.factorWriteGate!.complete();
      expect(await Future.wait([first, second, third]), [true, true, true]);
      expect(repo.maxConcurrentWrites, 1);
      expect(tokenCalls, 3);
      expect(repo.factorWrites, [
        'fresh-1:acc-cash:2',
        'fresh-2:acc-cash:3',
        'fresh-3:${other.id}:0',
      ]);
      expect(controller.exposureFactors, {
        'acc-cash': ExposureFactor.leveraged3,
        other.id: ExposureFactor.cash,
      });
    },
  );

  test(
    'stale account reads cannot cross sessions including A to B to A',
    () async {
      final repo = ExposureTestRepository()
        ..setFactor('acc-cash', ExposureFactor.leveraged2);
      final controller = testNetWorthController(repo);
      await controller.loadForUser('a');
      final gate = Completer<void>();
      repo.readGates['a-token'] = gate;
      final stale = controller.load('a-token', '2026-07');
      await Future<void>.delayed(Duration.zero);
      await controller.loadForUser('b');
      repo.setFactor('acc-cash', null);
      await controller.load('b-token', '2026-07');
      expect(controller.exposureFactors, isEmpty);
      await controller.loadForUser('a');
      repo.readGates.remove('a-token');
      repo.setFactor('acc-cash', ExposureFactor.leveraged3);
      await controller.load('a-token', '2026-07');
      gate.complete();
      await stale;
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.leveraged3);
    },
  );

  test(
    'pending old write and queued action cannot populate a new session',
    () async {
      final repo = ExposureTestRepository()
        ..factorWriteGate = Completer<void>();
      final controller = testNetWorthController(repo);
      await controller.loadForUser('a');
      await controller.load('a-token', '2026-07');
      final oldSession = controller.exposureSession;
      final save = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: oldSession,
        idToken: () async => 'a-token',
      );
      final queued = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged3,
        session: oldSession,
        idToken: () async => 'a-token',
      );
      await Future<void>.delayed(Duration.zero);
      controller.reset();
      expect(controller.monthly, isNull);
      expect(controller.exposureFactors, isEmpty);
      await controller.loadForUser('b');
      repo.factorWriteGate!.complete();
      expect(await save, isFalse);
      expect(await queued, isFalse);
      expect(controller.exposureFactors, isEmpty);
      expect(
        await controller.saveExposureFactor(
          'acc-cash',
          ExposureFactor.cash,
          session: oldSession,
          idToken: () async => 'b-token',
        ),
        isFalse,
      );
      expect(repo.factorWrites, ['a-token:acc-cash:2']);
    },
  );

  for (final closeSheet in [false, true]) {
    test(
      'session or sheet changed during token resolution prevents dispatch, close=$closeSheet',
      () async {
        final repo = ExposureTestRepository();
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');
        final token = Completer<String>();
        var active = true;
        final save = controller.saveExposureFactor(
          'acc-cash',
          ExposureFactor.leveraged2,
          session: controller.exposureSession,
          idToken: () => token.future,
          isActive: () => active,
        );
        await Future<void>.delayed(Duration.zero);
        if (closeSheet) {
          active = false;
        } else {
          controller.reset();
        }
        token.complete('new-user-token');
        expect(await save, isFalse);
        expect(repo.factorWrites, isEmpty);
        expect(controller.exposureSaving, isFalse);
      },
    );
  }

  for (final factor in [ExposureFactor.leveraged2, null]) {
    test(
      'pre-save account read cannot overwrite acknowledged factor $factor',
      () async {
        final repo = ExposureTestRepository()
          ..setFactor('acc-cash', ExposureFactor.cash);
        final controller = testNetWorthController(repo);
        await controller.load('token', '2026-07');
        repo.factorWriteGate = Completer<void>();
        final save = controller.saveExposureFactor(
          'acc-cash',
          factor,
          session: controller.exposureSession,
          idToken: () async => 'token',
        );
        await Future<void>.delayed(Duration.zero);
        final gate = Completer<void>();
        repo.readGates['token'] = gate;
        final refresh = controller.load('token', '2026-07');
        await Future<void>.delayed(Duration.zero);
        repo.factorWriteGate!.complete();
        expect(await save, isTrue);
        gate.complete();
        await refresh;
        expect(controller.accounts.first.exposureFactor, factor);
        repo.readGates.clear();
        repo.setFactor('acc-cash', ExposureFactor.leveraged3);
        await controller.load('token', '2026-07');
        expect(
          controller.exposureFactors['acc-cash'],
          ExposureFactor.leveraged3,
        );
      },
    );
  }

  test(
    'exposure 401 survives a concurrent refresh and keeps confirmed state',
    () async {
      final repo = ExposureTestRepository()
        ..setFactor('acc-cash', ExposureFactor.cash)
        ..factorWriteGate = Completer<void>()
        ..writeFailure = const FinanceReauthenticationRequired();
      final controller = testNetWorthController(repo);
      await controller.load('token', '2026-07');
      final save = controller.saveExposureFactor(
        'acc-cash',
        ExposureFactor.leveraged2,
        session: controller.exposureSession,
        idToken: () async => 'token',
      );
      await Future<void>.delayed(Duration.zero);
      final gate = Completer<void>();
      repo.readGates['token'] = gate;
      final refresh = controller.load('token', '2026-07');
      await Future<void>.delayed(Duration.zero);
      repo.factorWriteGate!.complete();
      expect(await save, isFalse);
      gate.complete();
      await refresh;
      expect(controller.status, FinanceStatus.needsReauth);
      expect(controller.exposureSaveFailed, isTrue);
      expect(controller.exposureFactors['acc-cash'], ExposureFactor.cash);
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
    final repo = ExposureTestRepository()
      ..seedSnapshot('acc-cash', '2026-07', 100)
      ..seedSnapshot('acc-card', '2026-07', 0)
      ..seedSnapshot('acc-cash', '2026-08', 200)
      ..seedSnapshot('acc-card', '2026-08', 0);
    repo.factorWriteGate = Completer<void>();
    final controller = testNetWorthController(repo);
    await controller.loadForUser('a');
    await controller.load('token', '2026-07');
    final save = controller.saveExposureFactor(
      'acc-cash',
      ExposureFactor.leveraged2,
      session: controller.exposureSession,
      idToken: () async => 'token',
    );
    await Future<void>.delayed(Duration.zero);
    await controller.load('token', '2026-08');
    repo.factorWriteGate!.complete();
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
