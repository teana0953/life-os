import 'networth_account.dart';

/// One (account, month) market-value snapshot, as echoed back by
/// `PUT /api/finance/networth/snapshots`. Values are non-negative TWD
/// integers — both assets and liabilities are recorded positive.
class NetWorthSnapshot {
  final String id;
  final String accountId;
  final String month;
  final int value;

  const NetWorthSnapshot({
    required this.id,
    required this.accountId,
    required this.month,
    required this.value,
  });

  factory NetWorthSnapshot.fromJson(Map<String, dynamic> json) {
    return NetWorthSnapshot(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      month: json['month'] as String,
      value: (json['value'] as num).toInt(),
    );
  }
}

/// One account's value within a queried month (the account list embedded in
/// `GET /api/finance/networth`), including archived accounts that still hold
/// a snapshot for that month.
class NetWorthAccountValue {
  final String accountId;
  final NetWorthKind kind;
  final String name;
  final int value;

  const NetWorthAccountValue({
    required this.accountId,
    required this.kind,
    required this.name,
    required this.value,
  });

  factory NetWorthAccountValue.fromJson(Map<String, dynamic> json) {
    return NetWorthAccountValue(
      accountId: json['account_id'] as String,
      kind: netWorthKindFromJson(json['kind'] as String),
      name: json['name'] as String,
      value: (json['value'] as num).toInt(),
    );
  }
}

/// A month's net worth figures, as returned by
/// `GET /api/finance/networth?month=YYYY-MM`. [prevNetWorth] and
/// [growthRate] are null on the first recorded month; [growthRate] is also
/// null when the prior net worth is zero or negative (a ratio against such a
/// base is undefined or sign-misleading).
class MonthlyNetWorth {
  final String month;
  final List<NetWorthAccountValue> accounts;
  final int totalAsset;
  final int totalLiability;
  final int netWorth;
  final int? prevNetWorth;
  final double? growthRate;

  const MonthlyNetWorth({
    required this.month,
    required this.accounts,
    required this.totalAsset,
    required this.totalLiability,
    required this.netWorth,
    required this.prevNetWorth,
    required this.growthRate,
  });

  factory MonthlyNetWorth.fromJson(Map<String, dynamic> json) {
    return MonthlyNetWorth(
      month: json['month'] as String,
      accounts: (json['accounts'] as List)
          .map((e) => NetWorthAccountValue.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAsset: (json['total_asset'] as num).toInt(),
      totalLiability: (json['total_liability'] as num).toInt(),
      netWorth: (json['net_worth'] as num).toInt(),
      prevNetWorth: (json['prev_net_worth'] as num?)?.toInt(),
      growthRate: (json['growth_rate'] as num?)?.toDouble(),
    );
  }
}

/// One point of the net worth trend series
/// (`GET /api/finance/networth/trend`), ascending by month.
class NetWorthTrendPoint {
  final String month;
  final int netWorth;

  const NetWorthTrendPoint({required this.month, required this.netWorth});

  factory NetWorthTrendPoint.fromJson(Map<String, dynamic> json) {
    return NetWorthTrendPoint(
      month: json['month'] as String,
      netWorth: (json['net_worth'] as num).toInt(),
    );
  }
}
