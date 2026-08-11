import 'package:flutter/foundation.dart';

import '../application/add_transaction.dart';
import '../application/delete_budget.dart';
import '../application/delete_transaction.dart';
import '../application/get_finance_month.dart';
import '../application/get_split_spending.dart';
import '../application/update_transaction.dart';
import '../application/upsert_budget.dart';
import '../domain/finance_budget.dart';
import '../domain/finance_category.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_month.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';
import '../domain/installment_plan.dart';
import '../domain/monthly_summary.dart';
import '../domain/split_spending.dart';

enum FinanceStatus { loading, loaded, needsReauth, error }

/// Loading state for the overview's split-spending line — deliberately
/// separate from [FinanceStatus] (design D9/D6, task 6.1): a failure here
/// must not blank the whole overview, and the line has to keep loading
/// independently of the month's recorded transactions/summary.
enum SplitSpendingStatus { loading, loaded, error }

/// Reasons loading/writing the finance month can fail, as understood by the
/// finance screens. [FinanceController] has no [BuildContext] and so cannot
/// hold a localized message directly — the screen maps this to text.
enum FinanceError { fetchFailed, unknown, validation, notFound, conflict }

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
  final UpsertBudget _upsertBudget;
  final DeleteBudget _deleteBudget;
  final GetSplitSpending _getSplitSpending;

  FinanceController(
    this._getFinanceMonth,
    this._addTransaction,
    this._updateTransaction,
    this._deleteTransaction,
    this._upsertBudget,
    this._deleteBudget,
    this._getSplitSpending,
  );

  /// `YYYY-MM`. Empty until the first [load] call — callers compute the
  /// initial month (from their own clock) and pass it explicitly, mirroring
  /// how the day-keyed trackers take `day` from the caller rather than
  /// defaulting internally.
  String selectedMonth = '';

  /// Bumped at the start of every [load] call. [selectedMonth] alone only
  /// catches a response landing for a month the reader has since switched
  /// away from — it says nothing when two [load] calls target the *same*
  /// month (e.g. two quick split writes each triggering a background
  /// reload) and land out of order, letting the earlier, now-stale response
  /// overwrite the later one. Each call captures its own sequence number and
  /// only applies its result while it is still the most recent call.
  int _loadSeq = 0;

  FinanceStatus status = FinanceStatus.loading;
  FinanceError? error;

  /// True only when the most recent [load] call itself failed to fetch —
  /// never set by a write (`_mutate`/[saveBudgets]) leaving [status] `error`
  /// for its own reasons (a validation/conflict/not-found failure, which the
  /// sheet that triggered it already reports on its own). Kept separate from
  /// [status] because the two screens' "reload of what's already on screen
  /// failed" notice must fire only for an actual reload failure — gating it
  /// on `status == error` alone made a failed *write* permanently show a
  /// "couldn't refresh" row about data that was never stale.
  bool reloadFailed = false;
  List<FinanceCategory> categories = [];
  List<FinanceTransaction> transactions = [];
  MonthlySummary? summary;
  List<FinanceBudget> budgets = [];

  /// The instalment plans behind this month's `transactions` (see
  /// [FinanceMonthData.installmentPlans]) — a plan absent here is either not
  /// referenced this month or not the caller's own.
  Map<String, InstallmentPlan> installmentPlans = {};

  /// The overview's split-spending line (design D6/D9, task 6) — loaded and
  /// tracked independently of [status]/[error] above, so a failure here
  /// never blanks the rest of the overview.
  SplitSpendingStatus splitSpendingStatus = SplitSpendingStatus.loading;
  List<SplitSpending> splitSpending = [];

  /// Drops everything a signed-in user's session put here, so the next user
  /// to sign in inherits none of it (`app.dart`'s
  /// `_resetControllersOnSignOut`, mirroring [NetWorthController.reset]).
  ///
  /// `FinanceScaffold` reloads this controller on every entry, which is why
  /// it was left out before — but a reload is not a clear: entering finance
  /// in the same calendar month re-enters `load` with `isMonthChange ==
  /// false`, so the previous account's figures stay on the fields until the
  /// new fetches land. This makes sign-out, not the next load, the point
  /// they stop existing.
  void reset() {
    // Bumped, not left alone: this controller is an app-lifetime singleton,
    // so a `load` started by the previous account can still be in flight
    // when they sign out. The old guard (`selectedMonth != month`, dropped
    // when this became a sequence number) incidentally discarded such a
    // response because `reset` cleared `selectedMonth` to `''`; the sequence
    // guard has no such side effect unless `_loadSeq` moves too, so without
    // this a slow in-flight response for the signed-out account's own month
    // still passes `seq == _loadSeq` and repopulates the screen after
    // sign-out — the exact #156/#157 leak shape.
    _loadSeq++;
    selectedMonth = '';
    status = FinanceStatus.loading;
    error = null;
    reloadFailed = false;
    categories = [];
    transactions = [];
    summary = null;
    budgets = [];
    installmentPlans = {};
    splitSpendingStatus = SplitSpendingStatus.loading;
    splitSpending = [];
  }

  /// Loads [month]'s categories, summary, and transactions. Sets
  /// [selectedMonth] to [month] synchronously (so a concurrent call started
  /// after this one can tell this one is now stale) but — the repo's
  /// no-sync-notify rule — does NOT call [notifyListeners] before the first
  /// `await` by default, so callers may trigger this from `initState` (via a
  /// post-frame callback) without risking a "setState during build" crash.
  ///
  /// If [month] differs from the [selectedMonth] this call is switching away
  /// from, [summary]/[transactions] (which belong to that old month) are
  /// discarded synchronously — otherwise a failed switch would leave the
  /// screen showing the old month's data under the new month's label (the
  /// class doc's month-mismatch bug class).
  ///
  /// [notifyOnStart]: set by user-gesture-triggered callers (e.g. the month
  /// switcher, not the initial entry load) so the screen can show loading
  /// feedback immediately — safe here because, unlike the entry call, it
  /// runs well after the widget has built.
  ///
  /// [background]: set by an unrequested reload the reader did not ask for
  /// (`FinanceScaffold._reloadLedger`, fired after a split write or a group
  /// detail return). A background reload's own token can be near-expiry or
  /// the server can 401 it independently of the reader's own session — that
  /// must not blank the screen into the full-page "sign in again" exit the
  /// same failure gets when the reader's *own* action triggered it; it's
  /// downgraded to the same [FinanceError.fetchFailed]/[reloadFailed] path
  /// as any other failed background reload, leaving whatever is already on
  /// screen in place under a [reloadFailed] notice.
  /// Returns `true` if this call's own result (data or error) was the one
  /// applied to [status]/[error]/the data fields, `false` if a newer,
  /// still-current call superseded it before this one landed — the caller
  /// then knows [status] says nothing about *this* call's own outcome (a
  /// fresher call, in flight or already settled, owns it instead). Every
  /// caller that needs to know whether *its own* write/reload succeeded
  /// (`_mutate`, `saveBudgets`, `FinanceScaffold._reloadLedger`) reads this
  /// rather than [status] directly — see their call sites for why: `status`
  /// alone cannot distinguish "this call's own result" from "whatever a
  /// concurrent call left behind while this one was still in flight".
  Future<bool> load(
    String idToken,
    String month, {
    bool notifyOnStart = false,
    bool background = false,
  }) async {
    final seq = ++_loadSeq;
    final isMonthChange = month != selectedMonth;
    selectedMonth = month;
    status = FinanceStatus.loading;
    error = null;
    // Always flips to loading (mirrors `status` above), but the *value* is
    // only cleared on an actual month change — same "same-month reload keeps
    // showing the old figure while it quietly refreshes" behaviour as
    // `summary`/`transactions` below.
    splitSpendingStatus = SplitSpendingStatus.loading;
    // Cleared on **every** load, not only on a month change, so the value
    // and [splitSpendingStatus] can never disagree. `summary`/`transactions`
    // get to survive a same-month reload because `status == loaded` means
    // "the main fetch that produced them has landed"; since this leg is now
    // a separate request (design D9), a `loaded` main fetch says nothing
    // about whose split figures are held here — and this controller is an
    // app-lifetime singleton, so "whose" can be a *different account*
    // (design.md: 不能變成登出後殘留上一個帳號分帳金額的新來源).
    splitSpending = [];
    if (isMonthChange) {
      summary = null;
      transactions = [];
      budgets = [];
      installmentPlans = {};
    }
    if (notifyOnStart) notifyListeners();

    // Started concurrently with the main fetch below, not chained after it
    // and not folded into a shared `Future.wait` (design D9/D6): its own
    // failure must never turn the whole month into [FinanceStatus.error].
    // Awaited at the end so callers of [load] see a fully settled state.
    final splitSpendingFuture = _loadSplitSpending(idToken, month, seq);

    try {
      final data = await _getFinanceMonth(idToken, month);
      // Stale-response guard: a faster later call — for this same month or a
      // different one — may have moved on while this request was in flight;
      // that response must never land over whatever the newer call produced.
      if (seq != _loadSeq) return false;
      categories = data.categories;
      summary = data.summary;
      transactions = data.transactions;
      budgets = data.budgets;
      installmentPlans = data.installmentPlans;
      status = FinanceStatus.loaded;
      reloadFailed = false;
    } on FinanceReauthenticationRequired {
      if (seq != _loadSeq) return false;
      if (background) {
        status = FinanceStatus.error;
        error = FinanceError.fetchFailed;
        reloadFailed = true;
      } else {
        status = FinanceStatus.needsReauth;
        reloadFailed = false;
      }
    } on FinanceFetchFailure {
      if (seq != _loadSeq) return false;
      status = FinanceStatus.error;
      error = FinanceError.fetchFailed;
      reloadFailed = true;
    } catch (_) {
      if (seq != _loadSeq) return false;
      status = FinanceStatus.error;
      error = FinanceError.unknown;
      reloadFailed = true;
    }
    notifyListeners();
    await splitSpendingFuture;
    return true;
  }

  /// Marks the currently loaded month as having failed a background reload,
  /// without making a request — for when a background reload
  /// (`FinanceScaffold._reloadLedger`) could not even get a token to call
  /// [load] with (`guardedIdToken` returns `''`, not a thrown failure, when
  /// it can't refresh one). Calling [load] with an empty token would just
  /// turn that into a 401 the server never actually sent. A no-op before the
  /// first successful load ([summary] still `null`): there is nothing on
  /// screen yet for a notice to be about.
  void markReloadFailed() {
    if (summary == null) return;
    status = FinanceStatus.error;
    error = FinanceError.fetchFailed;
    reloadFailed = true;
    notifyListeners();
  }

  /// Reloads after a write that is already known to have succeeded
  /// server-side — used by [addTransaction], [updateTransaction], and
  /// [deleteTransaction], which only reach this after their own write call
  /// completed without throwing. If a concurrent, newer call (e.g. a
  /// background reload from a split write elsewhere,
  /// `FinanceScaffold._reloadLedger`) supersedes this call's own reload
  /// response before it lands, [load] returns `false` and leaves [status]
  /// wherever it stood at the *start* of this call — `loading`, set
  /// synchronously by [load] itself, never resolved to a terminal state by
  /// this call. Left alone, every caller that reads [status] right after
  /// awaiting the write (`AddTransactionSheet._save`/`_delete`) would read
  /// "still loading" as "the write failed" — even though it plainly did
  /// not — and tell the user so about a row that is already saved,
  /// inviting a duplicate resubmit on retry. The write's own success is
  /// known unconditionally here (this is only reached once it has already
  /// happened), so a superseded reload still resolves to
  /// [FinanceStatus.loaded]; the newer call's own result (fresher data,
  /// and possibly a different status of its own) settles in right after,
  /// same as it would have anyway.
  Future<void> _reloadAfterWrite(String idToken, String month) async {
    final applied = await load(idToken, month);
    if (!applied) {
      status = FinanceStatus.loaded;
      error = null;
      notifyListeners();
    }
  }

  /// Loads [month]'s split-spending totals (design D6) — see [load]'s doc
  /// for why this is separate from the main fetch. [seq] is checked against
  /// [_loadSeq] on completion (the same stale-response guard [load] applies
  /// to `summary`/`transactions`): a slow response for a call the reader has
  /// since moved on from — same month or not — must never overwrite the
  /// currently selected month's line.
  Future<void> _loadSplitSpending(String idToken, String month, int seq) async {
    try {
      final result = await _getSplitSpending(idToken, month);
      if (seq != _loadSeq) return;
      splitSpending = result;
      splitSpendingStatus = SplitSpendingStatus.loaded;
    } catch (_) {
      if (seq != _loadSeq) return;
      splitSpendingStatus = SplitSpendingStatus.error;
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
    await _reloadAfterWrite(idToken, monthOf(created.date));
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
    await _reloadAfterWrite(idToken, monthOf(updated.date));
  });

  /// Deletes a transaction, then reloads the currently selected month — NOT
  /// necessarily the deleted transaction's month (the user may have since
  /// switched months while its edit sheet was open).
  Future<void> deleteTransaction(String idToken, String id) =>
      _mutate(idToken, () async {
        await _deleteTransaction(idToken, id);
        await _reloadAfterWrite(idToken, selectedMonth);
      });

  /// Applies only the differences between [desired] and the currently loaded
  /// [budgets], sequentially: [desired] maps a budget's `categoryId` (`null`
  /// = overall) to its wanted amount — `null` or `0` means "not set". A
  /// changed/new amount upserts, a cleared existing budget deletes, and an
  /// untouched entry sends nothing (design.md's batch-diff rule).
  ///
  /// On success the month reloads and this returns with [status] `loaded`.
  /// On failure of any step, the month reloads immediately — so the sheet
  /// can show what was actually applied — and [status]/[error] then reflect
  /// the failure (unless the reload itself needs reauth, which takes
  /// priority). Because the diff is always computed against the *current*
  /// [budgets], a caller that retries with the same [desired] map after a
  /// failure will only re-send the steps that didn't already succeed.
  Future<void> saveBudgets(String idToken, Map<String?, int?> desired) async {
    final currentByCategory = {for (final budget in budgets) budget.categoryId: budget};
    try {
      for (final entry in desired.entries) {
        final categoryId = entry.key;
        final wantedAmount = entry.value;
        final current = currentByCategory[categoryId];
        if (wantedAmount == null || wantedAmount == 0) {
          if (current != null) await _deleteBudget(idToken, current.id);
        } else if (current == null || current.amount != wantedAmount) {
          await _upsertBudget(idToken, categoryId: categoryId, amount: wantedAmount);
        }
      }
      await load(idToken, selectedMonth);
      return;
    } on FinanceReauthenticationRequired {
      final applied = await load(idToken, selectedMonth);
      // `!applied ||`: a concurrent, newer reload (e.g. a background reload
      // from a split write elsewhere) can supersede this call's own reload
      // before it lands, leaving [status] wherever [load] set it
      // synchronously at the start — `loading`, not a terminal state (see
      // [_reloadAfterWrite]'s doc for the full shape). Without the
      // `!applied` branch this error would be silently dropped and the
      // caller would read "still loading" for a budget save that is known
      // to have failed.
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.needsReauth;
        notifyListeners();
      }
    } on FinanceValidationFailure {
      final applied = await load(idToken, selectedMonth);
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.error;
        error = FinanceError.validation;
        notifyListeners();
      }
    } on FinanceNotFound {
      final applied = await load(idToken, selectedMonth);
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.error;
        error = FinanceError.notFound;
        notifyListeners();
      }
    } on FinanceFetchFailure {
      final applied = await load(idToken, selectedMonth);
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.error;
        error = FinanceError.fetchFailed;
        notifyListeners();
      }
    } catch (_) {
      final applied = await load(idToken, selectedMonth);
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.error;
        error = FinanceError.unknown;
        notifyListeners();
      }
    }
  }

  /// Runs a write [action], mapping its typed failures onto [status]/[error]
  /// — mirrors `ExerciseController._apply`: on failure the previously loaded
  /// [categories]/[summary]/[transactions] are left untouched, so the screen
  /// keeps showing them while the caller (the record sheet) surfaces a
  /// transient failure (snackbar, content preserved) by checking [status]
  /// after awaiting. On success, [action] itself calls [load], which already
  /// notifies — so this does not double-notify on the happy path.
  ///
  /// **Two failures are the exception to "never reload on failure"** (design
  /// D5): a `409` means someone else changed the split under the caller, and a
  /// `404` on a mirrored row means the split — and with it the row — is gone.
  /// In both, what is on screen is now wrong about the *server's own* facts,
  /// not just about this write, so both reload and only then set the error
  /// status, mirroring [saveBudgets]. Setting it after matters: [load] leaves
  /// [status] `loaded`, and the record sheet pops itself on `loaded` — it would
  /// close on what it should be reporting.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    try {
      await action();
      return;
    } on FinanceReauthenticationRequired {
      status = FinanceStatus.needsReauth;
    } on FinanceValidationFailure {
      status = FinanceStatus.error;
      error = FinanceError.validation;
    } on FinanceConflict {
      final applied = await load(idToken, selectedMonth);
      // `!applied ||`: see [_reloadAfterWrite]'s doc — a concurrent, newer
      // reload can supersede this call's own reload before it lands,
      // leaving [status] `loading` instead of a terminal state. Without the
      // `!applied` branch this 409 would be silently dropped and the caller
      // would read "still loading" for a write that is known to have
      // failed.
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.error;
        error = FinanceError.conflict;
      }
    } on FinanceNotFound {
      final applied = await load(idToken, selectedMonth);
      if (!applied || status == FinanceStatus.loaded) {
        status = FinanceStatus.error;
        error = FinanceError.notFound;
      }
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
