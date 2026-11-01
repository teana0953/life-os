import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/networth_account.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';

NetWorthAccount account(
  String id,
  NetWorthKind kind, {
  bool archived = false,
}) => NetWorthAccount(
  id: id,
  kind: kind,
  name: id,
  sortOrder: 0,
  archived: archived,
);

NetWorthAccountValue row(
  String id,
  int value, [
  NetWorthKind kind = NetWorthKind.asset,
]) => NetWorthAccountValue(accountId: id, kind: kind, name: id, value: value);

NetWorthExposure calculate(
  List<NetWorthAccountValue> rows,
  Map<String, ExposureFactor> factors, [
  List<NetWorthAccount> accounts = const [],
]) => NetWorthExposure.calculate(
  MonthlyNetWorth(
    month: '2026-07',
    accounts: rows,
    totalAsset: 0,
    totalLiability: 0,
    netWorth: 0,
    prevNetWorth: null,
    growthRate: null,
  ),
  accounts,
  factors,
);

void main() {
  test('大仁 ETF plus cash example is 6 million exposure and 1x', () {
    final result = calculate(
      [row('etf', 3000000), row('cash', 3000000)],
      {'etf': ExposureFactor.leveraged2, 'cash': ExposureFactor.cash},
    );
    expect(result.totalExposure, 6000000);
    expect(result.netWorth, 6000000);
    expect(result.leverage, 1);
  });

  test(
    'full property market value plus separate debt is 21 million and 3.5x',
    () {
      final result = calculate(
        [
          row('etf', 3000000),
          row('property', 15000000),
          row('mortgage', 12000000, NetWorthKind.liability),
        ],
        {
          'etf': ExposureFactor.leveraged2,
          'property': ExposureFactor.unleveraged,
          'mortgage': ExposureFactor.leveraged3,
        },
      );
      expect(result.totalExposure, 21000000);
      expect(result.netWorth, 6000000);
      expect(result.leverage, 3.5);
    },
  );

  test(
    'unknown positive asset blocks headline but recorded zero needs no factor',
    () {
      final result = calculate([row('unknown', 1), row('zero', 0)], {});
      expect(result.status, ExposureStatus.unclassified);
      expect(result.unclassifiedAccountIds, ['unknown']);
      expect(result.totalExposure, isNull);
      expect(result.leverage, isNull);
      expect(calculate([row('zero', 0)], {}).totalExposure, 0);
    },
  );

  for (final kind in NetWorthKind.values) {
    test('missing active $kind snapshot is not zero', () {
      final result = calculate(
        [row('etf', 100)],
        {'etf': ExposureFactor.leveraged3},
        [account('etf', NetWorthKind.asset), account('missing', kind)],
      );
      expect(result.status, ExposureStatus.unrecorded);
      expect(result.unrecordedAccountIds, ['missing']);
      expect(result.totalExposure, isNull);
      expect(result.netWorth, isNull);
      expect(result.leverage, isNull);
    });
  }

  test(
    'archived snapshots count and archived accounts without snapshots do not block',
    () {
      final result = calculate(
        [row('archived', 100)],
        {'archived': ExposureFactor.leveraged3},
        [
          account('archived', NetWorthKind.asset, archived: true),
          account('old', NetWorthKind.liability, archived: true),
        ],
      );
      expect(result.status, ExposureStatus.complete);
      expect(result.totalExposure, 300);
      expect(result.leverage, 3);
    },
  );

  for (final debt in [100, 150]) {
    test('no ratio for nonpositive net worth with debt $debt', () {
      final result = calculate(
        [row('etf', 100), row('debt', debt, NetWorthKind.liability)],
        {'etf': ExposureFactor.leveraged2},
      );
      expect(result.totalExposure, 200);
      expect(result.leverage, isNull);
    });
  }

  test('empty month and all-cash month are different states', () {
    expect(calculate([], {}).status, ExposureStatus.empty);
    expect(calculate([], {}).totalExposure, isNull);
    final cash = calculate([row('cash', 100)], {'cash': ExposureFactor.cash});
    expect(cash.status, ExposureStatus.complete);
    expect(cash.leverage, 0);
  });

  test('only exact persisted integer factors 0 through 3 are accepted', () {
    expect([0, 1, 2, 3].map(ExposureFactor.fromStored), ExposureFactor.values);
    for (final value in <Object?>[-1, 4, '2', 2.0, null, true]) {
      expect(ExposureFactor.fromStored(value), isNull);
    }
  });
}
