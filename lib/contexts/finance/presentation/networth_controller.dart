import 'package:flutter/foundation.dart';

import '../application/networth_use_cases.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_month.dart';
import '../domain/networth_account.dart';
import '../domain/networth_snapshot.dart';
import 'finance_controller.dart';

/// How many months the trend window spans, ending at (and including) the
/// selected month.
const _trendWindowMonths = 12;

/// Drives the 淨值 tab: the selected month's accounts, net worth figures, and
/// the recent-months trend, plus snapshot and account writes.
///
/// Separate from [FinanceController] on purpose, and **its [selectedMonth] is
/// deliberately independent of the ledger's**: net worth is a month-end
/// balance snapshot while the ledger is that month's cash flow, and users
/// routinely look at different months in each. Sharing one month would
/// reproduce this repo's most repeated bug — one tab's month silently moving
/// because the other tab moved.
///
/// Reuses [FinanceStatus]/[FinanceError] so the 淨值 tab maps failures to
/// localized copy exactly like the ledger tabs do.
class NetWorthController extends ChangeNotifier {
  final ListNetWorthAccounts _listAccounts;
  final CreateNetWorthAccount _createAccount;
  final UpdateNetWorthAccount _updateAccount;
  final UpsertSnapshot _upsertSnapshot;
  final GetMonthlyNetWorth _getMonthlyNetWorth;
  final GetNetWorthTrend _getTrend;

  NetWorthController(
    this._listAccounts,
    this._createAccount,
    this._updateAccount,
    this._upsertSnapshot,
    this._getMonthlyNetWorth,
    this._getTrend,
  );

  /// `YYYY-MM`. Empty until the first [load] — the caller supplies the
  /// initial month from its own clock, mirroring [FinanceController].
  String selectedMonth = '';

  FinanceStatus status = FinanceStatus.loading;
  FinanceError? error;
  List<NetWorthAccount> accounts = [];
  MonthlyNetWorth? monthly;
  List<NetWorthTrendPoint> trend = [];

  /// Loads [month]'s accounts, figures, and trend in one batch. The trend
  /// window is the 12 months ending at [month], so it moves with the month
  /// switcher.
  ///
  /// Race- and month-safe like [FinanceController.load]: [selectedMonth] is
  /// set synchronously (so a later call can tell this one is stale), a month
  /// change discards the previous month's figures synchronously rather than
  /// leaving them under the new month's label, and a response for a month the
  /// user has since switched away from is dropped. No [notifyListeners]
  /// before the first `await` unless [notifyOnStart] (set by user-gesture
  /// callers, not the entry load).
  Future<void> load(String idToken, String month, {bool notifyOnStart = false}) async {
    final isMonthChange = month != selectedMonth;
    selectedMonth = month;
    status = FinanceStatus.loading;
    error = null;
    if (isMonthChange) {
      monthly = null;
      trend = [];
    }
    if (notifyOnStart) notifyListeners();

    try {
      final results = await Future.wait([
        _listAccounts(idToken),
        _getMonthlyNetWorth(idToken, month),
        _getTrend(idToken, from: _trendStart(month), to: month),
      ]);
      if (selectedMonth != month) return;
      accounts = results[0] as List<NetWorthAccount>;
      monthly = results[1] as MonthlyNetWorth;
      trend = results[2] as List<NetWorthTrendPoint>;
      status = FinanceStatus.loaded;
    } on FinanceReauthenticationRequired {
      if (selectedMonth != month) return;
      status = FinanceStatus.needsReauth;
    } on FinanceFetchFailure {
      if (selectedMonth != month) return;
      status = FinanceStatus.error;
      error = FinanceError.fetchFailed;
    } catch (_) {
      if (selectedMonth != month) return;
      status = FinanceStatus.error;
      error = FinanceError.unknown;
    }
    notifyListeners();
  }

  /// Upserts [accountId]'s market value for [selectedMonth], then reloads.
  ///
  /// `0` is a legal value (an emptied account); a negative [value] is never
  /// sent — the sheet already gates it, and sending it would only earn a 400.
  Future<void> saveSnapshot(
    String idToken, {
    required String accountId,
    required int value,
  }) {
    if (value < 0) {
      status = FinanceStatus.error;
      error = FinanceError.validation;
      notifyListeners();
      return Future.value();
    }
    return _mutate(idToken, () async {
      await _upsertSnapshot(
        idToken,
        accountId: accountId,
        month: selectedMonth,
        value: value,
      );
    });
  }

  Future<void> createAccount(
    String idToken, {
    required NetWorthKind kind,
    required String name,
  }) => _mutate(idToken, () async {
    await _createAccount(idToken, kind: kind, name: name);
  });

  Future<void> updateAccount(
    String idToken,
    String id, {
    String? name,
    int? sortOrder,
    bool? archived,
  }) => _mutate(idToken, () async {
    await _updateAccount(
      idToken,
      id,
      name: name,
      sortOrder: sortOrder,
      archived: archived,
    );
  });

  /// Runs a write [action] then reloads the selected month, mapping typed
  /// failures onto [status]/[error] — on failure the already-loaded figures
  /// stay on screen (mirrors `FinanceController._mutate`), so the caller can
  /// surface a transient failure by checking [status] after awaiting.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    try {
      await action();
      await load(idToken, selectedMonth);
      return;
    } on FinanceReauthenticationRequired {
      status = FinanceStatus.needsReauth;
    } on FinanceValidationFailure {
      status = FinanceStatus.error;
      error = FinanceError.validation;
    } on FinanceNotFound {
      status = FinanceStatus.error;
      error = FinanceError.notFound;
    } on FinanceFetchFailure {
      status = FinanceStatus.error;
      error = FinanceError.fetchFailed;
    } catch (_) {
      status = FinanceStatus.error;
      error = FinanceError.unknown;
    }
    notifyListeners();
  }

  /// The first month of the trend window ending at [month].
  static String _trendStart(String month) {
    var start = month;
    for (var i = 0; i < _trendWindowMonths - 1; i++) {
      start = previousMonth(start);
    }
    return start;
  }
}
