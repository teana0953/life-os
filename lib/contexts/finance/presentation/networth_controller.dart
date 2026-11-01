import 'package:flutter/foundation.dart';

import '../application/networth_use_cases.dart';
import '../application/exposure_settings.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_month.dart';
import '../domain/networth_account.dart';
import '../domain/networth_snapshot.dart';
import '../domain/networth_exposure.dart';
import 'finance_controller.dart';

/// How many months the trend window spans, ending at (and including) the
/// selected month.
const _trendWindowMonths = 12;

enum ExposureSettingsStatus { unavailable, loading, ready, readFailed }

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
  final ReorderNetWorthAccounts _reorderAccounts;
  final UpsertSnapshot _upsertSnapshot;
  final GetMonthlyNetWorth _getMonthlyNetWorth;
  final GetNetWorthTrend _getTrend;
  final ExposureSettings? _exposureSettings;

  /// Injectable clock used to stamp [lastLoadedAt] on a successful load —
  /// the tracker controllers' convention, so tests can pin the stamp.
  final DateTime Function() _clock;

  NetWorthController(
    this._listAccounts,
    this._createAccount,
    this._updateAccount,
    this._reorderAccounts,
    this._upsertSnapshot,
    this._getMonthlyNetWorth,
    this._getTrend, {
    DateTime Function() clock = DateTime.now,
    ExposureSettings? exposureSettings,
  }) : _clock = clock,
       _exposureSettings = exposureSettings;

  String? _uid;
  int _session = 0;
  int _loadRequest = 0;
  int _settingsRequest = 0;
  Future<void> _settingsWrites = Future.value();
  Map<String, ExposureFactor> _exposureFactors = {};
  int _pendingSettingsWrites = 0;
  ExposureSettingsStatus exposureSettingsStatus =
      ExposureSettingsStatus.unavailable;
  bool exposureSaveFailed = false;

  int get exposureSession => _session;
  bool get exposureSaving => _pendingSettingsWrites > 0;
  Map<String, ExposureFactor> get exposureFactors =>
      Map.unmodifiable(_exposureFactors);
  NetWorthExposure? get exposure => monthly == null
      ? null
      : NetWorthExposure.calculate(monthly!, accounts, _exposureFactors);

  Future<void> loadForUser(String? uid) async {
    if (_uid == uid && uid != null) return;
    reset();
    _uid = uid;
    await reloadExposureSettings();
  }

  Future<void> reloadExposureSettings() async {
    final uid = _uid;
    final settings = _exposureSettings;
    if (uid == null || settings == null) return;
    final session = _session;
    final request = ++_settingsRequest;
    exposureSettingsStatus = ExposureSettingsStatus.loading;
    notifyListeners();
    try {
      await _settingsWrites;
      if (session != _session || request != _settingsRequest) return;
      final factors = await settings.read(uid);
      if (session != _session || request != _settingsRequest) return;
      _exposureFactors = Map.of(factors);
      exposureSettingsStatus = ExposureSettingsStatus.ready;
      exposureSaveFailed = false;
    } catch (_) {
      if (session != _session || request != _settingsRequest) return;
      _exposureFactors = {};
      exposureSettingsStatus = ExposureSettingsStatus.readFailed;
    }
    notifyListeners();
  }

  Future<bool> saveExposureFactor(
    String accountId,
    ExposureFactor? factor, {
    required int session,
  }) async {
    final uid = _uid;
    final settings = _exposureSettings;
    final assetIds = {
      for (final account in accounts)
        if (account.kind == NetWorthKind.asset) account.id,
      for (final row in monthly?.accounts ?? <NetWorthAccountValue>[])
        if (row.kind == NetWorthKind.asset) row.accountId,
    };
    if (session != _session ||
        uid == null ||
        settings == null ||
        exposureSettingsStatus != ExposureSettingsStatus.ready ||
        !assetIds.contains(accountId)) {
      return false;
    }
    _pendingSettingsWrites++;
    notifyListeners();
    var saved = false;
    final write = _settingsWrites.then((_) async {
      if (session != _session) return;
      try {
        await settings.save(uid, accountId, factor);
        if (session != _session) return;
        if (factor == null) {
          _exposureFactors.remove(accountId);
        } else {
          _exposureFactors[accountId] = factor;
        }
        exposureSaveFailed = false;
        saved = true;
      } catch (_) {
        if (session != _session) return;
        exposureSaveFailed = true;
      }
      if (session != _session) return;
      _pendingSettingsWrites--;
      notifyListeners();
    });
    _settingsWrites = write;
    await write;
    return saved;
  }

  /// `YYYY-MM`. Empty until the first [load] — the caller supplies the
  /// initial month from its own clock, mirroring [FinanceController].
  String selectedMonth = '';

  FinanceStatus status = FinanceStatus.loading;
  FinanceError? error;
  List<NetWorthAccount> accounts = [];
  MonthlyNetWorth? monthly;
  List<NetWorthTrendPoint> trend = [];

  /// When this month's figures last landed successfully, or `null` before the
  /// first success — shown by the tab's pull-to-refresh "last updated" label.
  DateTime? lastLoadedAt;

  /// Set when a same-month reload (pull-to-refresh) fails while [monthly] is
  /// already on screen — mirrors [FinanceController.reloadFailed]. Without
  /// this, a same-month failure leaves [monthly] non-null, so the tab's error
  /// page (gated on `monthly == null`) never shows and the failure is
  /// otherwise silent.
  bool reloadFailed = false;

  /// Clears every loaded figure on sign-out so a subsequently signed-in user
  /// never sees the previous user's accounts or net worth. This controller is
  /// an app-lifetime singleton (main.dart), so nothing else would clear it.
  void reset() {
    _session++;
    _loadRequest++;
    _settingsRequest++;
    _uid = null;
    _exposureFactors = {};
    _pendingSettingsWrites = 0;
    exposureSettingsStatus = ExposureSettingsStatus.unavailable;
    exposureSaveFailed = false;
    selectedMonth = '';
    status = FinanceStatus.loading;
    error = null;
    reloadFailed = false;
    accounts = [];
    monthly = null;
    trend = [];
    lastLoadedAt = null;
    notifyListeners();
  }

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
  Future<void> load(
    String idToken,
    String month, {
    bool notifyOnStart = false,
  }) async {
    final session = _session;
    final request = ++_loadRequest;
    bool isCurrent() => session == _session && request == _loadRequest;
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
      if (!isCurrent()) return;
      accounts = results[0] as List<NetWorthAccount>;
      monthly = results[1] as MonthlyNetWorth;
      trend = results[2] as List<NetWorthTrendPoint>;
      status = FinanceStatus.loaded;
      reloadFailed = false;
      lastLoadedAt = _clock();
    } on FinanceReauthenticationRequired {
      if (!isCurrent()) return;
      status = FinanceStatus.needsReauth;
    } on FinanceFetchFailure {
      if (!isCurrent()) return;
      status = FinanceStatus.error;
      error = FinanceError.fetchFailed;
      reloadFailed = true;
    } catch (_) {
      if (!isCurrent()) return;
      status = FinanceStatus.error;
      error = FinanceError.unknown;
      reloadFailed = true;
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
    int? sortOrder,
  }) => _mutate(idToken, () async {
    await _createAccount(idToken, kind: kind, name: name, sortOrder: sortOrder);
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

  /// Rewrites a whole kind group's order in one server-side atomic write.
  /// [orderedIds] must be exactly that group's ids, archived included.
  ///
  /// Deliberately **not** through [_mutate]: that reloads the month, which is
  /// three parallel requests (accounts, monthly, trend) for a change that
  /// alters nothing but a display order the client already holds in full.
  /// That reload was most of the wait issue #136 is about. On success the
  /// group is renumbered locally to match exactly what the server was told;
  /// on failure nothing local moves, so the caller can put its own optimistic
  /// order back.
  ///
  /// Returns whether the write landed. A caller showing the new order before
  /// the answer arrives needs to know, and [status] alone cannot say: it stays
  /// `loaded` here, because a failed reorder must not blank the figures on
  /// screen.
  Future<bool> reorderAccounts(
    String idToken,
    NetWorthKind kind,
    List<String> orderedIds,
  ) async {
    final session = _session;
    final request = _loadRequest;
    bool isCurrent() => session == _session;
    try {
      await _reorderAccounts(idToken, kind, orderedIds);
    } on FinanceReauthenticationRequired {
      if (!isCurrent()) return false;
      _loadRequest++;
      status = FinanceStatus.needsReauth;
      notifyListeners();
      return false;
    } catch (_) {
      return false;
    }
    if (!isCurrent()) return false;
    if (request != _loadRequest) {
      await load(idToken, selectedMonth);
      if (!isCurrent()) return false;
    }
    final position = {
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
    };
    accounts = [
      for (final account in accounts)
        position.containsKey(account.id)
            ? NetWorthAccount(
                id: account.id,
                kind: account.kind,
                name: account.name,
                sortOrder: position[account.id]!,
                archived: account.archived,
              )
            : account,
    ];
    notifyListeners();
    return true;
  }

  /// Runs a write [action] then reloads the selected month, mapping typed
  /// failures onto [status]/[error] — on failure the already-loaded figures
  /// stay on screen (mirrors `FinanceController._mutate`), so the caller can
  /// surface a transient failure by checking [status] after awaiting.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    final session = _session;
    bool isCurrent() => session == _session;
    try {
      await action();
      if (!isCurrent()) return;
      await load(idToken, selectedMonth);
      return;
    } on FinanceReauthenticationRequired {
      if (!isCurrent()) return;
      status = FinanceStatus.needsReauth;
    } on FinanceValidationFailure {
      if (!isCurrent()) return;
      status = FinanceStatus.error;
      error = FinanceError.validation;
    } on FinanceNotFound {
      if (!isCurrent()) return;
      status = FinanceStatus.error;
      error = FinanceError.notFound;
    } on FinanceFetchFailure {
      if (!isCurrent()) return;
      status = FinanceStatus.error;
      error = FinanceError.fetchFailed;
    } catch (_) {
      if (!isCurrent()) return;
      status = FinanceStatus.error;
      error = FinanceError.unknown;
    }
    // A read started before this failure must not erase the write error.
    _loadRequest++;
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

  @override
  void dispose() {
    _session++;
    super.dispose();
  }
}
