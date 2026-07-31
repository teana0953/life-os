import 'package:flutter/foundation.dart';

import '../application/add_transaction.dart';
import '../application/delete_transaction.dart';
import '../application/get_finance_month.dart';
import '../application/update_transaction.dart';
import '../domain/finance_category.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_month.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/monthly_summary.dart';

enum FinanceStatus { loading, loaded, needsReauth, error }

/// Reasons loading/writing the finance month can fail, as understood by the
/// finance screens. [FinanceController] has no [BuildContext] and so cannot
/// hold a localized message directly — the screen maps this to text.
enum FinanceError { fetchFailed, unknown, validation, notFound }

/// Drives the finance shell: the selected month's categories, summary, and
/// transactions, plus add/update/delete mutations. Month-keyed like
/// `TodayController`/`ExerciseController`, but with the extra race/cross-month
/// guards design.md calls for (this repo's most repeated bug class: a shared
/// controller showing day/month A on screen while data lands in day/month B):
///
/// - **Race-safe month switching**: a slow response for a month the user has
///   since switched away from must never overwrite the currently selected
///   month's data.
/// - **Cross-month write jump**: adding/editing a transaction reloads the
///   month the transaction's own date falls in — jumping [selectedMonth]
///   there if it differs from the month currently viewed — so a cross-month
///   save is immediately visible, never silently written into a month
///   nobody is looking at.
class FinanceController extends ChangeNotifier {
  final GetFinanceMonth _getFinanceMonth;
  final AddTransaction _addTransaction;
  final UpdateTransaction _updateTransaction;
  final DeleteTransaction _deleteTransaction;

  FinanceController(
    this._getFinanceMonth,
    this._addTransaction,
    this._updateTransaction,
    this._deleteTransaction,
  );

  /// `YYYY-MM`. Empty until the first [load] call — callers compute the
  /// initial month (from their own clock) and pass it explicitly, mirroring
  /// how the day-keyed trackers take `day` from the caller rather than
  /// defaulting internally.
  String selectedMonth = '';

  FinanceStatus status = FinanceStatus.loading;
  FinanceError? error;
  List<FinanceCategory> categories = [];
  List<FinanceTransaction> transactions = [];
  MonthlySummary? summary;

  /// Loads [month]'s categories, summary, and transactions. Sets
  /// [selectedMonth] to [month] synchronously (so a concurrent call started
  /// after this one can tell this one is now stale) but — the repo's
  /// no-sync-notify rule — does NOT call [notifyListeners] before the first
  /// `await`, so callers may trigger this from `initState` (via a
  /// post-frame callback) without risking a "setState during build" crash.
  Future<void> load(String idToken, String month) async {
    selectedMonth = month;
    status = FinanceStatus.loading;
    error = null;

    try {
      final data = await _getFinanceMonth(idToken, month);
      // Stale-response guard: a faster later switch may have moved
      // `selectedMonth` on while this request was in flight — that response
      // must never land over the (now different) currently viewed month.
      if (selectedMonth != month) return;
      categories = data.categories;
      summary = data.summary;
      transactions = data.transactions;
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

  /// Records a new transaction, then reloads the month the transaction's own
  /// date falls in (see class doc — the cross-month write jump).
  Future<void> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) => _mutate(idToken, () async {
    final created = await _addTransaction(
      idToken,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    await load(idToken, monthOf(created.date));
  });

  /// Full-replace edits an existing transaction, then reloads the month its
  /// (possibly changed) date falls in.
  Future<void> updateTransaction(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) => _mutate(idToken, () async {
    final updated = await _updateTransaction(
      idToken,
      id,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    await load(idToken, monthOf(updated.date));
  });

  /// Deletes a transaction, then reloads the currently selected month — NOT
  /// necessarily the deleted transaction's month (the user may have since
  /// switched months while its edit sheet was open).
  Future<void> deleteTransaction(String idToken, String id) =>
      _mutate(idToken, () async {
        await _deleteTransaction(idToken, id);
        await load(idToken, selectedMonth);
      });

  /// Runs a write [action], mapping its typed failures onto [status]/[error]
  /// — mirrors `ExerciseController._apply`: on failure the previously loaded
  /// [categories]/[summary]/[transactions] are left untouched, so the screen
  /// keeps showing them while the caller (the record sheet) surfaces a
  /// transient failure (snackbar, content preserved) by checking [status]
  /// after awaiting. On success, [action] itself calls [load], which already
  /// notifies — so this does not double-notify on the happy path.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    try {
      await action();
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
}
