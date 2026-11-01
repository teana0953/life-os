import 'networth_account.dart';
import 'networth_snapshot.dart';

enum ExposureFactor {
  cash(0),
  unleveraged(1),
  leveraged2(2),
  leveraged3(3);

  final int multiplier;
  const ExposureFactor(this.multiplier);

  static ExposureFactor? fromStored(Object? value) {
    for (final factor in values) {
      if (value is int && factor.multiplier == value) return factor;
    }
    return null;
  }
}

enum ExposureStatus { empty, unrecorded, unclassified, complete }

class NetWorthExposure {
  final ExposureStatus status;
  final int? totalExposure;
  final int? netWorth;
  final List<String> unrecordedAccountIds;
  final List<String> unclassifiedAccountIds;

  const NetWorthExposure._({
    required this.status,
    required this.totalExposure,
    required this.netWorth,
    required this.unrecordedAccountIds,
    required this.unclassifiedAccountIds,
  });

  double? get leverage => status == ExposureStatus.complete && netWorth! > 0
      ? totalExposure! / netWorth!
      : null;

  factory NetWorthExposure.calculate(
    MonthlyNetWorth monthly,
    List<NetWorthAccount> accounts,
    Map<String, ExposureFactor> factors,
  ) {
    final recorded = {for (final row in monthly.accounts) row.accountId};
    final unrecorded = [
      for (final account in accounts)
        if (!account.archived && !recorded.contains(account.id)) account.id,
    ];
    final unclassified = <String>[];
    var exposure = 0;
    var netWorth = 0;
    for (final row in monthly.accounts) {
      if (row.kind == NetWorthKind.liability) {
        netWorth -= row.value;
      } else {
        netWorth += row.value;
        final factor = factors[row.accountId];
        if (factor == null && row.value > 0) {
          unclassified.add(row.accountId);
        } else {
          exposure += row.value * (factor?.multiplier ?? 0);
        }
      }
    }
    final status = monthly.accounts.isEmpty
        ? ExposureStatus.empty
        : unrecorded.isNotEmpty
        ? ExposureStatus.unrecorded
        : unclassified.isNotEmpty
        ? ExposureStatus.unclassified
        : ExposureStatus.complete;
    return NetWorthExposure._(
      status: status,
      totalExposure: status == ExposureStatus.complete ? exposure : null,
      netWorth: status == ExposureStatus.complete ? netWorth : null,
      unrecordedAccountIds: List.unmodifiable(unrecorded),
      unclassifiedAccountIds: List.unmodifiable(unclassified),
    );
  }
}
