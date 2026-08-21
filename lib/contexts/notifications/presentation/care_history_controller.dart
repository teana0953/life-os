import 'package:flutter/foundation.dart';

import '../../../shared/data_revision.dart';
import '../../../shared/screen_batch/section_outcome.dart';
import '../application/edit_care_slot.dart';
import '../application/get_care_history.dart';
import '../domain/care_history.dart';
import '../domain/care_history_filter.dart';
import '../domain/care_history_period.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';
import '../infrastructure/care_history_filter_store.dart';

enum CareHistoryLoadStatus { loading, loaded, error, reauth }

/// What one [CareHistoryController.edit] call actually did, returned to its
/// caller rather than left for it to infer from [CareHistoryController]'s
/// mutable fields after the `await`.
///
/// Reading those fields afterwards is racy in a way that misreports care
/// records: a concurrent `load` (the user tapping the period selector) clears
/// `editError`/`refreshError` by design, and a later `edit` clears them on
/// entry — so a caller that awaited a *failed* PUT could find them null and
/// tell the user the record was saved. A returned value is a snapshot of that
/// call's own outcome and can't be overwritten by anything that happens next.
enum CareEditOutcome {
  /// The PUT succeeded and the follow-up refresh did too.
  saved,

  /// The PUT itself failed — the record was NOT changed.
  editFailed,

  /// The PUT succeeded but the follow-up refresh failed: the record changed,
  /// the list on screen is stale.
  refreshFailed,

  /// The request needs re-authentication; the screen shows its own exit.
  reauth,

  /// The call was dropped by the re-entrancy guard — another edit was already
  /// in flight, so nothing was attempted.
  skipped,
}

/// Drives [CareHistoryScreen] (and the trend tab's care-adherence card):
/// [load] fetches the range for the self-held [period], ending today per
/// the injected clock (design mirrors [TrendController] — [status] flips to
/// `loading` on every call including a period-switch reload, but [days] is
/// only overwritten on success, so the caller can keep showing the previous
/// content with a thin progress indicator instead of blanking).
/// [setPeriod] changes [period] and reloads. [edit] PUTs a slot's new outcome then
/// quietly re-fetches the range for the current [period] (design mirrors
/// [CareTodayController]'s marking mechanism: the [editing] flag, never
/// dropping [status] back to `loading`). A PUT failure keeps the existing
/// [days] and surfaces the typed error via [editError] — the edit did not
/// take effect. A *successful* PUT whose follow-up GET fails surfaces that
/// separately via [refreshError] instead (FIX 2/3): the edit itself
/// succeeded server-side, only the refresh of the list failed, so the
/// screen must not tell the user their edit was lost — it must not discard
/// the just-updated list either. A 401 from [load], the edit PUT, or the
/// post-edit refresh routes [status] to [CareHistoryLoadStatus.reauth]. A
/// Concurrent [load]s are resolved by a generation ticket (see
/// [_loadGeneration]) so an out-of-order response can't leave [days] and
/// [period] describing different periods. A
/// successful edit bumps the injected [DataRevision] once — the record
/// changed server-side, so other screens/cards depending on care data (e.g.
/// the trend tab's own [CareHistoryController] instance) know to reload
/// (design §D); a failed edit PUT (error or reauth) does not bump. Holds
/// typed errors, not text — the owning screen maps them to localized copy.
class CareHistoryController extends ChangeNotifier {
  final GetCareHistory _getHistory;
  final EditCareSlot _editSlot;
  final DataRevision _dataRevision;

  /// Returns the current time; injectable so tests can pin the range. Only
  /// the date component is used.
  final DateTime Function() _clock;

  /// Persists (and restored, at construction) the chosen period. `null` for
  /// an instance whose period is nobody's saved preference — the trend tab's
  /// card owns its own period selector, and sharing the store with it would
  /// let its selection overwrite the history screen's.
  final CareHistoryFilterStore? _filterStore;

  /// The active period — [load] computes its range from this and the
  /// injected clock; [setPeriod] changes it and reloads.
  CareHistoryPeriod period;

  /// Which of the loaded [days]' slots the screen shows ([filteredDays]).
  /// Memory-only by design: see [CareHistoryFilterStore] for why a restored
  /// filter would read as lost data.
  CareHistoryFilter filter = const CareHistoryFilter();

  CareHistoryController(
    this._getHistory,
    this._editSlot,
    this._dataRevision, {
    required CareHistoryPeriod period,
    CareHistoryFilterStore? filterStore,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock,
       _filterStore = filterStore,
       period = filterStore?.readPeriod() ?? period;

  /// The rolling span's length (7/30/90), or `null` while a custom date
  /// range is active.
  int? get spanDays => period.spanDays;

  CareHistoryLoadStatus status = CareHistoryLoadStatus.loading;
  List<CareHistoryDay> days = const [];
  Object? error;

  /// The [period] the current [days] were fetched for — `null` until a
  /// fetch has succeeded. Lets the edit-failure paths tell whether their own
  /// generation bump left [days] describing a different period than
  /// [period] (see [edit]).
  CareHistoryPeriod? _daysPeriod;

  /// Public read of [_daysPeriod] — the period [days] actually describes,
  /// as opposed to [period] (design §C): [setPeriod] writes [period]
  /// *before* awaiting the reload, so a caller keying its copy off
  /// [period] mid-reload would describe the just-selected, still
  /// unconfirmed period rather than what's actually on screen. `null` only
  /// before any load has ever settled.
  CareHistoryPeriod? get daysPeriod => _daysPeriod;

  /// [days] narrowed by [filter] — what the screen's list, summary and empty
  /// state all read, so the three can never disagree about which records are
  /// on screen.
  List<CareHistoryDay> get filteredDays =>
      applyCareHistoryFilter(days, filter);

  /// Replaces the filter. Purely a client-side slice of the days already
  /// loaded — never a re-query, and never persisted.
  void setFilter(CareHistoryFilter newFilter) {
    filter = newFilter;
    notifyListeners();
  }

  /// Whether a load has ever settled — succeeded *or* failed. The screen's
  /// full-page spinner (which has no period selector) is for the very first
  /// attempt only; every later load keeps the screen shell and shows a thin
  /// progress indicator. Not `days.isEmpty`: a period genuinely without
  /// records has no days either, and a *failed* first load has already put
  /// the error state — with its selector — on screen, so retrying or
  /// switching period from there must not drop back to a spinner that has
  /// neither.
  bool firstLoadSettled = false;

  bool editing = false;
  Object? editError;
  Object? refreshError;

  /// Monotonic ticket taken by each [load] — and by [edit]'s quiet reload;
  /// only the latest one may write its result. Two independent drivers load
  /// the trend tab's instance
  /// concurrently — the user (the card's period selector → [setSpan]) and
  /// `HealthScaffold._load`'s `Future.wait`, re-run on every [DataRevision]
  /// bump (i.e. after every `/care-history` edit) — so without this the last
  /// response to *arrive* would win, leaving [days] holding one period's
  /// records while [period] (and the selector) says another, with
  /// `status == loaded` and nothing indicating the mismatch.
  int _loadGeneration = 0;

  /// Loads the range for the current [period], ending today (per the
  /// injected clock). A response from a superseded call is discarded (see
  /// [_loadGeneration]).
  Future<void> load(String idToken) {
    // A user-initiated load supersedes whatever the last edit reported.
    editError = null;
    refreshError = null;
    return _fetchCurrentPeriod(idToken);
  }

  /// The fetch half of [load], without clearing [editError]/[refreshError] —
  /// [edit]'s failure paths re-issue it to repair the period mismatch their
  /// own generation bump creates, and must not erase the error they are
  /// about to report.
  Future<void> _fetchCurrentPeriod(String idToken) async {
    final requestedPeriod = period;
    final range = requestedPeriod.resolve(_clock());
    final generation = ++_loadGeneration;
    status = CareHistoryLoadStatus.loading;
    notifyListeners();
    try {
      final fetched = await _getHistory(idToken, range.from, range.to);
      if (generation != _loadGeneration) return;
      days = fetched;
      _daysPeriod = requestedPeriod;
      status = CareHistoryLoadStatus.loaded;
      error = null;
    } catch (e) {
      if (generation != _loadGeneration) return;
      if (e is CareReauthRequired) {
        status = CareHistoryLoadStatus.reauth;
      } else {
        error = e;
        status = CareHistoryLoadStatus.error;
      }
    }
    // Reached only by the load that won its generation ticket (both branches
    // above return early otherwise), i.e. one that actually settled.
    firstLoadSettled = true;
    notifyListeners();
  }

  /// Applies the batched `care_range` section, but only when it describes the
  /// span this card is showing *now* — returns whether it did.
  ///
  /// Two windows cannot be described by a `care_days` count and so are never
  /// applied: a custom date range ([spanDays] is `null`), and a span the
  /// round did not request because it changed while the request was in
  /// flight. The caller loads this one card granularly in either case.
  ///
  /// Takes a generation ticket like a load does (see [_loadGeneration]): the
  /// card's own period switch can still be in flight, and without the ticket
  /// its older response would land on top of this and leave [days] and
  /// [period] describing different periods.
  bool applyBatchSection(
    SectionOutcome<List<CareHistoryDay>> section, {
    required int requestedSpanDays,
  }) {
    if (spanDays == null || spanDays != requestedSpanDays) return false;
    ++_loadGeneration;
    switch (section) {
      case SectionOk<List<CareHistoryDay>>(:final value):
        days = value;
        _daysPeriod = period;
        error = null;
        status = CareHistoryLoadStatus.loaded;
      case SectionUnavailable<List<CareHistoryDay>>():
        error = const CareRequestFailed();
        status = CareHistoryLoadStatus.error;
      case SectionReauth<List<CareHistoryDay>>():
        status = CareHistoryLoadStatus.reauth;
    }
    firstLoadSettled = true;
    notifyListeners();
    return true;
  }

  /// Switches the period and reloads, persisting the choice when this
  /// instance was given a store.
  Future<void> setPeriod(String idToken, CareHistoryPeriod newPeriod) async {
    period = newPeriod;
    // Spelled out rather than `await _filterStore?.writePeriod(...)`: that
    // awaits `null` for a store-less instance, which yields to the event
    // loop before the reload even starts and would let a caller observe the
    // controller between the two.
    final store = _filterStore;
    if (store != null) await store.writePeriod(newPeriod);
    await load(idToken);
  }

  /// Switches to a rolling span (7/30/90) and reloads.
  Future<void> setSpan(String idToken, int newSpanDays) =>
      setPeriod(idToken, CareHistoryPeriod.span(newSpanDays));

  /// Sets the outcome of the slot identified by ([careScheduleId],
  /// [localDate], [timeOfDay]) to [status], then quietly re-fetches the
  /// range for the current [period] (design — [CareHistoryLoadStatus] stays `loaded`
  /// throughout, never dropping to `loading`). Guarded against
  /// re-entrancy — a second call while one is in flight is ignored. A PUT
  /// failure surfaces via [editError]; a PUT success whose refresh fails
  /// surfaces via [refreshError] instead (FIX 3) — the two must not be
  /// conflated, since only the former means the edit itself was lost.
  ///
  /// **Callers must report the outcome from the returned [CareEditOutcome],
  /// not by reading [editError]/[refreshError] after the `await`** — those
  /// fields are shared mutable state that a concurrent `load` or a later
  /// `edit` can clear, which would turn a failed PUT into a "saved" message.
  /// They remain for `build`, which reads whatever is current by definition.
  Future<CareEditOutcome> edit(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    if (editing) return CareEditOutcome.skipped;
    editing = true;
    editError = null;
    refreshError = null;
    notifyListeners();

    try {
      await _editSlot(
        idToken,
        careScheduleId: careScheduleId,
        localDate: localDate,
        timeOfDay: timeOfDay,
        status: status,
      );
    } catch (e) {
      // Take a generation ticket here too, symmetrically with the success
      // path below: a period switch's GET can still be in flight (the screen
      // doesn't blank, so tiles stay tappable), and when it lands it would
      // otherwise overwrite the outcome set here — turning a `reauth` into
      // `loaded`, which the screen reads as "the edit went through" and
      // reports as saved. A record that failed to save must never be shown
      // as saved.
      ++_loadGeneration;
      if (e is CareReauthRequired) {
        this.status = CareHistoryLoadStatus.reauth;
        editing = false;
        notifyListeners();
        return CareEditOutcome.reauth;
      }
      // Keep the existing days — an edit failure doesn't lose the list.
      editError = e;
      // Having just superseded that in-flight load, this path now owns the
      // `loading` it left behind; without this the screen would spin
      // forever on a failed edit that happened during a period switch.
      this.status = CareHistoryLoadStatus.loaded;
      // If the load just superseded was a period switch, those kept days
      // belong to the *previous* period while `period` (and the selector
      // built from it) already says the new one — the exact mismatch
      // [_loadGeneration] exists to prevent, made permanent by stopping at
      // `loaded` with nothing in flight to repair it. Re-fetch the current
      // span in that case only, so an ordinary edit failure still just
      // keeps the list. [editError] survives the re-fetch (that's why this
      // is [_fetchCurrentPeriod], not [load]).
      //
      // [editing] is released only *after* that repair, never before: it is
      // this method's re-entrancy guard, and releasing it early lets a
      // second edit start mid-repair and clear [editError] on entry — so the
      // caller awaiting this one reads a null error and reports a PUT that
      // failed as saved.
      if (_daysPeriod != period) await _fetchCurrentPeriod(idToken);
      editing = false;
      notifyListeners();
      return CareEditOutcome.editFailed;
    }

    // The PUT itself succeeded server-side — bump regardless of whether the
    // follow-up refresh below succeeds, since the underlying record already
    // changed (design §D).
    _dataRevision.bump();

    // Re-derive the range from the *current* [period] rather than reusing
    // the one the last [load] fetched, and take a generation ticket like
    // [load] does: the screen doesn't blank during a period switch, so its
    // tiles stay tappable while that switch's GET is still in flight, and
    // that GET's period is the one now on screen. Without both halves the
    // quiet reload would fetch the *previous* period and could land under
    // the switch's older response — leaving [days] and [period]
    // describing different periods with `status == loaded` and nothing
    // indicating the mismatch.
    final requestedPeriod = period;
    final range = requestedPeriod.resolve(_clock());
    final generation = ++_loadGeneration;
    try {
      final fetched = await _getHistory(idToken, range.from, range.to);
      if (generation == _loadGeneration) {
        days = fetched;
        _daysPeriod = requestedPeriod;
        error = null;
        // This reload superseded any load that was in flight, so it is now
        // the one that has to settle the `loading` that load left behind.
        this.status = CareHistoryLoadStatus.loaded;
      }
    } catch (e) {
      if (generation == _loadGeneration) {
        if (e is CareReauthRequired) {
          this.status = CareHistoryLoadStatus.reauth;
        } else {
          // The edit itself succeeded — keep the existing (now-stale) days
          // rather than dropping to the full-screen error state (FIX 2), and
          // report the refresh failure separately from an edit failure
          // (FIX 3) so the screen doesn't tell the user the edit was lost.
          refreshError = e;
          this.status = CareHistoryLoadStatus.loaded;
          // Same repair as the failed-PUT branch above, on the same
          // condition: this reload's generation ticket discarded any period
          // switch still in flight, so the kept days can describe a
          // different period than [period]. [editing] is likewise released
          // only after the repair — see that branch for why an early release
          // makes the caller misreport the outcome.
          if (_daysPeriod != period) await _fetchCurrentPeriod(idToken);
          editing = false;
          notifyListeners();
          return CareEditOutcome.refreshFailed;
        }
        editing = false;
        notifyListeners();
        return CareEditOutcome.reauth;
      }
    }
    editing = false;
    notifyListeners();
    return CareEditOutcome.saved;
  }
}
