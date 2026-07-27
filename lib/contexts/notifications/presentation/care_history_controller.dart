import 'package:flutter/foundation.dart';

import '../../../shared/data_revision.dart';
import '../../../shared/date/day_format.dart';
import '../application/edit_care_slot.dart';
import '../application/get_care_history.dart';
import '../domain/care_history.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';

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
/// [load] fetches the range for the self-held [spanDays], ending today per
/// the injected clock (design mirrors [TrendController] — [status] flips to
/// `loading` on every call including a period-switch reload, but [days] is
/// only overwritten on success, so the caller can keep showing the previous
/// content with a thin progress indicator instead of blanking). [setSpan]
/// changes [spanDays] and reloads. [edit] PUTs a slot's new outcome then
/// quietly re-fetches the range for the current [spanDays] (design mirrors
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
/// [spanDays] describing different periods. A
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

  /// The active period length (7/30/90) — [load] computes its range from
  /// this and the injected clock; [setSpan] changes it and reloads.
  int spanDays;

  CareHistoryController(
    this._getHistory,
    this._editSlot,
    this._dataRevision, {
    required this.spanDays,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  CareHistoryLoadStatus status = CareHistoryLoadStatus.loading;
  List<CareHistoryDay> days = const [];
  Object? error;

  /// The [spanDays] the current [days] were fetched for — `null` until a
  /// fetch has succeeded. Lets the edit-failure paths tell whether their own
  /// generation bump left [days] describing a different period than
  /// [spanDays] (see [edit]).
  int? _daysSpanDays;

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
  /// records while [spanDays] (and the selector) says another, with
  /// `status == loaded` and nothing indicating the mismatch.
  int _loadGeneration = 0;

  /// Loads the range for the current [spanDays], ending today (per the
  /// injected clock). A response from a superseded call is discarded (see
  /// [_loadGeneration]).
  Future<void> load(String idToken) {
    // A user-initiated load supersedes whatever the last edit reported.
    editError = null;
    refreshError = null;
    return _fetchCurrentSpan(idToken);
  }

  /// The fetch half of [load], without clearing [editError]/[refreshError] —
  /// [edit]'s failure paths re-issue it to repair the period mismatch their
  /// own generation bump creates, and must not erase the error they are
  /// about to report.
  Future<void> _fetchCurrentSpan(String idToken) async {
    final span = spanDays;
    final range = dayRangeEndingOn(span, _clock());
    final generation = ++_loadGeneration;
    status = CareHistoryLoadStatus.loading;
    notifyListeners();
    try {
      final fetched = await _getHistory(idToken, range.from, range.to);
      if (generation != _loadGeneration) return;
      days = fetched;
      _daysSpanDays = span;
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

  /// Switches the period (7/30/90) and reloads.
  Future<void> setSpan(String idToken, int days) async {
    spanDays = days;
    await load(idToken);
  }

  /// Sets the outcome of the slot identified by ([careScheduleId],
  /// [localDate], [timeOfDay]) to [status], then quietly re-fetches the
  /// range for the current [spanDays] (design — [CareHistoryLoadStatus] stays `loaded`
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
      // belong to the *previous* period while `spanDays` (and the selector
      // built from it) already says the new one — the exact mismatch
      // [_loadGeneration] exists to prevent, made permanent by stopping at
      // `loaded` with nothing in flight to repair it. Re-fetch the current
      // span in that case only, so an ordinary edit failure still just
      // keeps the list. [editError] survives the re-fetch (that's why this
      // is [_fetchCurrentSpan], not [load]).
      //
      // [editing] is released only *after* that repair, never before: it is
      // this method's re-entrancy guard, and releasing it early lets a
      // second edit start mid-repair and clear [editError] on entry — so the
      // caller awaiting this one reads a null error and reports a PUT that
      // failed as saved.
      if (_daysSpanDays != spanDays) await _fetchCurrentSpan(idToken);
      editing = false;
      notifyListeners();
      return CareEditOutcome.editFailed;
    }

    // The PUT itself succeeded server-side — bump regardless of whether the
    // follow-up refresh below succeeds, since the underlying record already
    // changed (design §D).
    _dataRevision.bump();

    // Re-derive the range from the *current* [spanDays] rather than reusing
    // the one the last [load] fetched, and take a generation ticket like
    // [load] does: the screen doesn't blank during a period switch, so its
    // tiles stay tappable while that switch's GET is still in flight, and
    // that GET's period is the one now on screen. Without both halves the
    // quiet reload would fetch the *previous* period and could land under
    // the switch's older response — leaving [days] and [spanDays]
    // describing different periods with `status == loaded` and nothing
    // indicating the mismatch.
    final span = spanDays;
    final range = dayRangeEndingOn(span, _clock());
    final generation = ++_loadGeneration;
    try {
      final fetched = await _getHistory(idToken, range.from, range.to);
      if (generation == _loadGeneration) {
        days = fetched;
        _daysSpanDays = span;
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
          // different period than [spanDays]. [editing] is likewise released
          // only after the repair — see that branch for why an early release
          // makes the caller misreport the outcome.
          if (_daysSpanDays != spanDays) await _fetchCurrentSpan(idToken);
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
