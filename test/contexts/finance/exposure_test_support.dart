import 'dart:async';

import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';

import 'finance_test_support.dart';

class ExposureTestRepository extends FakeFinanceRepository {
  final Map<String, Completer<void>> readGates = {};
  Completer<void>? factorWriteGate;
  bool failRead = false;
  bool failWrite = false;
  Object? writeFailure;
  final List<String> factorWrites = [];
  int concurrentWrites = 0;
  int maxConcurrentWrites = 0;

  void setFactor(String id, ExposureFactor? factor) {
    accounts = [
      for (final account in accounts)
        NetWorthAccount(
          id: account.id,
          kind: account.kind,
          name: account.name,
          sortOrder: account.sortOrder,
          archived: account.archived,
          exposureFactor: account.id == id ? factor : account.exposureFactor,
        ),
    ];
  }

  @override
  Future<List<NetWorthAccount>> listNetWorthAccounts(String idToken) async {
    final result = await super.listNetWorthAccounts(idToken);
    await readGates[idToken]?.future;
    if (failRead) throw const FinanceFetchFailure('offline');
    return result;
  }

  @override
  Future<NetWorthAccount> updateNetWorthAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
    ({ExposureFactor? value})? exposure,
  }) async {
    if (exposure == null) {
      return super.updateNetWorthAccount(
        idToken,
        id,
        name: name,
        sortOrder: sortOrder,
        archived: archived,
      );
    }
    factorWrites.add('$idToken:$id:${exposure.value?.multiplier}');
    concurrentWrites++;
    if (concurrentWrites > maxConcurrentWrites) {
      maxConcurrentWrites = concurrentWrites;
    }
    try {
      await factorWriteGate?.future;
      if (writeFailure case final failure?) throw failure;
      if (failWrite) throw const FinanceFetchFailure('offline');
      return await super.updateNetWorthAccount(idToken, id, exposure: exposure);
    } finally {
      concurrentWrites--;
    }
  }
}
