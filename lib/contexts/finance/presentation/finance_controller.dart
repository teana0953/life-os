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

/// What one write ([FinanceController.addTransaction],
/// [FinanceController.updateTransaction],
/// [FinanceController.deleteTransaction], [FinanceController.saveBudgets])
/// did — returned to the caller that issued it, and about **that write
/// alone**.
///
/// Deliberately not [FinanceStatus]/[FinanceError], and deliberately not read
/// off the controller's fields (#165). [FinanceStatus] is the *screen's*
/// state: a background reload fired by a split write elsewhere, a month
/// switch in another tab, or a second sheet's save all move it while a write
/// is in flight. The three sheets used to read `status == loaded` as "my save
/// went through", which made every concurrent call's outcome masquerade as
/// this one's — reported as a failed save, that is a bottom sheet left open
/// over money the server already has, and a user who presses Save again. The
/// two questions are now two values: `status` answers "what should the screen
/// show", the returned result answers "what happened to my write".
///
/// An enum rather than a `bool` because the record sheet answers the
/// refusals differently: a 409 re-seeds the mirrored facts and asks the user
/// to re-confirm, a 404 says the row is gone and closes, a 401 in the budget
/// sheet asks them to sign in again, and everything else is the generic
/// retryable failure. A `bool` would push the callers straight back to
/// reading `controller.error` — the same shared field, the same bug.
enum FinanceWriteResult {
  /// The server accepted the write. Says nothing about the reload that
  /// follows it: that reload refreshes the screen (and reports its own
  /// failure through [FinanceController.status]/`reloadFailed`), but the row
  /// is on the server either way.
  saved,
  needsReauth,
  validation,
  notFound,
  conflict,
  /// Same 409 as [conflict], but *this write's own* post-refusal reload ran
  /// to completion and did not land `FinanceStatus.loaded` — a fetch failure
  /// or a (non-background) 401 from this call specifically, not merely
  /// superseded by a fresher concurrent call (#165, round 5: the record
  /// sheet used to read [FinanceController.reloadFailed] for this, a field
  /// any unrelated concurrent load can also flip, which both missed this
  /// call's own 401 — [load] leaves `reloadFailed` false there — and let a
  /// background reload's *unrelated* failure land on a write whose own
  /// reload had already succeeded). [FinanceController.transactions] cannot
  /// be trusted as an answer about this write in that case: the record sheet
  /// must not re-seed from it, and must not say the split "moved out of the
  /// month" either — both would report something this call never actually
  /// learned. A *superseded* own reload is NOT this case: a fresher call's
  /// data is a valid current answer, identified by the row's id — see
  /// [conflict]'s doc and the sheet's own comment.
  conflictReloadFailed,
  fetchFailed,
  unknown,
}

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

  /// Injectable clock used to stamp [lastLoadedAt] on a successful load —
  /// the tracker controllers' convention, so tests can pin the stamp.
  final DateTime Function() _clock;

  FinanceController(
    this._getFinanceMonth,
    this._addTransaction,
    this._updateTransaction,
    this._deleteTransaction,
    this._upsertBudget,
    this._deleteBudget,
    this._getSplitSpending, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

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

  /// Bumped only by [reset] — never by [load]. Captured by [_mutate] and
  /// [saveBudgets] *before* their write's own network call, so that if
  /// [reset] runs while that write is still in flight (sign-out mid-write),
  /// the write's own post-success reload can tell its session ended even
  /// though, by the time it goes to call [load], that call's own freshly
  /// minted [_loadSeq] would otherwise look perfectly current. [_loadSeq]
  /// alone cannot express this: [reset] bumping it only protects a reload
  /// already in flight at reset time, not one a write starts *after* reset
  /// with the signed-out session's stale token — see [_reloadAfterWrite]
  /// and [_reportRefusedWrite].
  int _sessionEpoch = 0;

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

  /// When the main fetch last landed successfully, or `null` before the first
  /// success — shown by the tabs' pull-to-refresh "last updated" label.
  /// Deliberately independent of [splitSpendingStatus]: that leg is a
  /// separate request (design D9) whose failure never blanks the overview, so
  /// gating the stamp on it would leave the label empty on a screen that is
  /// in fact showing freshly loaded figures.
  DateTime? lastLoadedAt;

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
    _sessionEpoch++;
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
    lastLoadedAt = null;
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
    // Awaited before returning — on *every* path, including the superseded
    // early returns via [_superseded] — so callers of [load] see a fully
    // settled state.
    final splitSpendingFuture = _loadSplitSpending(idToken, month, seq);

    try {
      final data = await _getFinanceMonth(idToken, month);
      // Stale-response guard: a faster later call — for this same month or a
      // different one — may have moved on while this request was in flight;
      // that response must never land over whatever the newer call produced.
      if (seq != _loadSeq) return _superseded(splitSpendingFuture);
      categories = data.categories;
      summary = data.summary;
      transactions = data.transactions;
      budgets = data.budgets;
      installmentPlans = data.installmentPlans;
      status = FinanceStatus.loaded;
      reloadFailed = false;
      lastLoadedAt = _clock();
    } on FinanceReauthenticationRequired {
      if (seq != _loadSeq) return _superseded(splitSpendingFuture);
      // `background && summary != null`: the downgrade only makes sense when
      // there is something already on screen to leave in place (see the
      // [background] doc above) — mirrors [markReloadFailed]'s own
      // `summary == null` guard. When a background reload 401s before any
      // successful [load] ever landed (e.g. the initial load itself failed,
      // and a split write elsewhere's background reload is what actually
      // discovers the dead session), there is nothing on screen to protect,
      // and the session really is dead — a full [FinanceStatus.needsReauth]
      // exit is correct here, not a "load failed / retry" page whose retry
      // can never succeed.
      if (background && summary != null) {
        status = FinanceStatus.error;
        error = FinanceError.fetchFailed;
        reloadFailed = true;
      } else {
        status = FinanceStatus.needsReauth;
        reloadFailed = false;
      }
    } on FinanceFetchFailure {
      if (seq != _loadSeq) return _superseded(splitSpendingFuture);
      status = FinanceStatus.error;
      error = FinanceError.fetchFailed;
      reloadFailed = true;
    } catch (_) {
      if (seq != _loadSeq) return _superseded(splitSpendingFuture);
      status = FinanceStatus.error;
      error = FinanceError.unknown;
      reloadFailed = true;
    }
    notifyListeners();
    await splitSpendingFuture;
    return true;
  }

  /// The superseded early return out of [load]: this call's response is
  /// dropped, but its split-spending leg — started before the main fetch and
  /// still in flight — is waited for first, so [load] really does return "a
  /// fully settled state" on every path rather than only on the ones that
  /// land. Returning straight from the guard left that future dangling: the
  /// doc said otherwise, and a test that awaits a superseded [load] would go
  /// on to assert against a controller a stray `notifyListeners` was still
  /// about to touch.
  Future<bool> _superseded(Future<void> splitSpendingFuture) async {
    await splitSpendingFuture;
    return false;
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

  /// Refreshes the screen after a write the server has already accepted —
  /// used by [addTransaction], [updateTransaction], [deleteTransaction] and
  /// [saveBudgets]'s success path, all of which only reach this once their
  /// own write call returned without throwing.
  ///
  /// **Its outcome is deliberately dropped.** This reload speaks for the
  /// screen, not for the write: whether it lands, is superseded by a newer
  /// call, or fails outright, the row is on the server, and the caller is
  /// told so by the [FinanceWriteResult] the write path returns. That
  /// separation is #165's fix, and the reason nothing here tries to steer
  /// [status] back to [FinanceStatus.loaded] on a superseded reload: the
  /// screen belongs to whichever call is newest — if that call failed to
  /// fetch, the reader must keep seeing the "couldn't refresh" notice; if it
  /// 401'd, the reader must keep seeing the sign-in exit. Both attempts to
  /// make this one field answer both questions (7af5e79, 7c58e68) turned one
  /// half true by making the other half lie.
  ///
  /// [epoch] is the [_sessionEpoch] the caller captured before its write's
  /// own network call started. If [reset] ran since — sign-out landed while
  /// the write was in flight — this must not call [load] at all: doing so
  /// would fetch with the signed-out session's token and, because that call
  /// mints its own fresh [_loadSeq], it would look like the newest call and
  /// repaint the previous account's data over a screen [reset] already
  /// cleared (#156/#157).
  Future<void> _reloadAfterWrite(String idToken, String month, int epoch) async {
    if (epoch != _sessionEpoch) return;
    await load(idToken, month);
  }

  /// Reloads after a write the server **refused**, then reports that refusal
  /// on [status]/[error] — the D5 "what is on screen is now wrong about the
  /// server's own facts" path (a 409/404 on a mirrored row), plus every
  /// [saveBudgets] failure, whose sheet needs to see what actually applied.
  ///
  /// The refusal is only painted onto the screen when **this call's own
  /// reload is the one that landed** (`applied`) and that reload succeeded
  /// (`status == loaded`, its own result). Otherwise a newer call owns the
  /// screen — it may still be in flight, or already settled on its own
  /// terminal outcome — and this stale one must not overwrite it. The caller
  /// hears about the refusal through the returned [FinanceWriteResult]
  /// regardless, so nothing is lost by staying off the screen here.
  ///
  /// [epoch] is the [_sessionEpoch] captured before the refused write's own
  /// network call — same reasoning as [_reloadAfterWrite]: if [reset] ran
  /// since, this must not call [load] (or paint anything) with the
  /// signed-out session's token at all.
  ///
  /// Returns whether **this call's own reload ran to completion and did not
  /// land loaded** (`applied && status != FinanceStatus.loaded`) — the one
  /// case in which [transactions]/[summary] must not be trusted as an answer
  /// about this write, because they were left exactly as they were before
  /// this write's own reload. A *superseded* reload (`!applied`) is
  /// deliberately reported as `false` here, not this case: the fields then
  /// belong to a fresher call, which is a valid current answer. This is
  /// computed and returned as the resolved value of this call's own
  /// `Future` — never stashed on a controller field — so a concurrent,
  /// unrelated call cannot overwrite it out from under a caller still
  /// holding the result (#165, round 5).
  Future<bool> _reportRefusedWrite(
    String idToken, {
    required FinanceStatus refusedStatus,
    FinanceError? refusal,
    required int epoch,
  }) async {
    if (epoch != _sessionEpoch) return false;
    final applied = await load(idToken, selectedMonth);
    if (!applied) return false;
    if (status != FinanceStatus.loaded) return true;
    status = refusedStatus;
    error = refusal;
    notifyListeners();
    return false;
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
  /// date falls in (see class doc — the cross-month write jump). Returns what
  /// happened to *this* write (see [FinanceWriteResult]); the reload's own
  /// fate is not part of it.
  Future<FinanceWriteResult> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) => _mutate(idToken, (epoch) async {
    final created = await _addTransaction(
      idToken,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    await _reloadAfterWrite(idToken, monthOf(created.date), epoch);
  });

  /// Full-replace edits an existing transaction, then reloads the month its
  /// (possibly changed) date falls in. Returns this write's own outcome.
  Future<FinanceWriteResult> updateTransaction(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) => _mutate(idToken, (epoch) async {
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
    await _reloadAfterWrite(idToken, monthOf(updated.date), epoch);
  });

  /// Deletes a transaction, then reloads the currently selected month — NOT
  /// necessarily the deleted transaction's month (the user may have since
  /// switched months while its edit sheet was open). Returns this write's own
  /// outcome.
  Future<FinanceWriteResult> deleteTransaction(String idToken, String id) =>
      _mutate(idToken, (epoch) async {
        await _deleteTransaction(idToken, id);
        await _reloadAfterWrite(idToken, selectedMonth, epoch);
      });

  /// Applies only the differences between [desired] and the currently loaded
  /// [budgets], sequentially: [desired] maps a budget's `categoryId` (`null`
  /// = overall) to its wanted amount — `null` or `0` means "not set". A
  /// changed/new amount upserts, a cleared existing budget deletes, and an
  /// untouched entry sends nothing (design.md's batch-diff rule).
  ///
  /// On success the month reloads and this returns [FinanceWriteResult.saved]
  /// — whatever that reload does. On failure of any step, the month reloads
  /// immediately (so the sheet can show what was actually applied) and this
  /// returns the refusal, which `budget_sheet.dart` maps to its copy: a
  /// [FinanceWriteResult.needsReauth] asks the user to sign in again,
  /// everything else is the generic retryable message. Because the diff is
  /// always computed against the *current* [budgets], a caller that retries
  /// with the same [desired] map after a failure will only re-send the steps
  /// that didn't already succeed.
  Future<FinanceWriteResult> saveBudgets(
    String idToken,
    Map<String?, int?> desired,
  ) async {
    final epoch = _sessionEpoch;
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
      // Through [_reloadAfterWrite], exactly like the three transaction
      // writes and for exactly the same reason: every step above has already
      // succeeded server-side, so nothing that reload runs into changes the
      // answer this call gives its own caller.
      await _reloadAfterWrite(idToken, selectedMonth, epoch);
      return FinanceWriteResult.saved;
    } on FinanceReauthenticationRequired {
      await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.needsReauth,
        epoch: epoch,
      );
      return FinanceWriteResult.needsReauth;
    } on FinanceValidationFailure {
      await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.error,
        refusal: FinanceError.validation,
        epoch: epoch,
      );
      return FinanceWriteResult.validation;
    } on FinanceNotFound {
      await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.error,
        refusal: FinanceError.notFound,
        epoch: epoch,
      );
      return FinanceWriteResult.notFound;
    } on FinanceFetchFailure {
      await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.error,
        refusal: FinanceError.fetchFailed,
        epoch: epoch,
      );
      return FinanceWriteResult.fetchFailed;
    } catch (_) {
      await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.error,
        refusal: FinanceError.unknown,
        epoch: epoch,
      );
      return FinanceWriteResult.unknown;
    }
  }

  /// Runs a write [action] and **returns its outcome** — mirrors
  /// `ExerciseController._apply` for the screen half: on failure the
  /// previously loaded [categories]/[summary]/[transactions] are left
  /// untouched, so the reader keeps seeing them while the caller (the record
  /// sheet) surfaces the refusal itself. What the caller reads is the
  /// returned [FinanceWriteResult], never [status] — see that enum's doc for
  /// why. On success, [action] itself calls [load], which already notifies —
  /// so this does not double-notify on the happy path.
  ///
  /// **Two failures are the exception to "never reload on failure"** (design
  /// D5): a `409` means someone else changed the split under the caller, and a
  /// `404` on a mirrored row means the split — and with it the row — is gone.
  /// In both, what is on screen is now wrong about the *server's own* facts,
  /// not just about this write, so both reload and only then set the error
  /// status, mirroring [saveBudgets] (see [_reportRefusedWrite]).
  ///
  /// The four failure arms that don't reload (`needsReauth`, `validation`,
  /// `fetchFailed`, unknown) still write `status`/`error` directly — they
  /// have nothing to reload against, unlike the 409/404 arms. But "directly"
  /// must not mean "unconditionally": [seq] is [_loadSeq] captured before
  /// [action] ran, so if a concurrent, newer [load] (a month switch, another
  /// write's background reload) has already settled its own terminal status
  /// by the time this write's failure lands, that newer call — not this
  /// stale one — owns the screen, and painting over it here would silently
  /// replace it (e.g. hiding a live [FinanceStatus.needsReauth] sign-in exit
  /// behind a generic "load failed" page). [epoch] is threaded into [action]
  /// so its own success-path reload can apply the same "did a sign-out
  /// happen since I started" check — see [_reloadAfterWrite].
  Future<FinanceWriteResult> _mutate(
    String idToken,
    Future<void> Function(int epoch) action,
  ) async {
    final seq = _loadSeq;
    final epoch = _sessionEpoch;
    final FinanceWriteResult result;
    try {
      await action(epoch);
      return FinanceWriteResult.saved;
    } on FinanceReauthenticationRequired {
      if (seq == _loadSeq) status = FinanceStatus.needsReauth;
      result = FinanceWriteResult.needsReauth;
    } on FinanceValidationFailure {
      if (seq == _loadSeq) {
        status = FinanceStatus.error;
        error = FinanceError.validation;
      }
      result = FinanceWriteResult.validation;
    } on FinanceConflict {
      final ownReloadFailed = await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.error,
        refusal: FinanceError.conflict,
        epoch: epoch,
      );
      result = ownReloadFailed
          ? FinanceWriteResult.conflictReloadFailed
          : FinanceWriteResult.conflict;
    } on FinanceNotFound {
      await _reportRefusedWrite(
        idToken,
        refusedStatus: FinanceStatus.error,
        refusal: FinanceError.notFound,
        epoch: epoch,
      );
      result = FinanceWriteResult.notFound;
    } on FinanceFetchFailure {
      if (seq == _loadSeq) {
        status = FinanceStatus.error;
        error = FinanceError.fetchFailed;
      }
      result = FinanceWriteResult.fetchFailed;
    } catch (_) {
      if (seq == _loadSeq) {
        status = FinanceStatus.error;
        error = FinanceError.unknown;
      }
      result = FinanceWriteResult.unknown;
    }
    notifyListeners();
    return result;
  }
}
