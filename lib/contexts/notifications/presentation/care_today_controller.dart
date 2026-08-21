import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/config.dart';
import '../../../shared/screen_batch/section_outcome.dart';
import '../application/care_today.dart';
import '../application/edit_care_slot.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';

enum CareTodayLoadStatus { loading, loaded, error, reauth }

/// What one [CareTodayController.edit] call actually did, returned to its
/// caller rather than left for it to infer from [CareTodayController]'s
/// mutable fields after the `await` (mirrors [CareEditOutcome] in
/// `care_history_controller.dart`, including its saved/refresh-failed
/// split).
enum CareTodayEditOutcome {
  /// The PUT and its follow-up quiet reload both succeeded — the list on
  /// screen now shows the correction.
  saved,

  /// The PUT itself failed — nothing was written, and
  /// [CareTodayController.markError] holds the typed error.
  failed,

  /// The PUT succeeded but the follow-up reload failed: the correction *is*
  /// saved, only the list on screen is stale (and still shows the old time,
  /// which makes a "that failed" message doubly convincing). Reported apart
  /// from [failed] so the caller never tells the user their change was lost
  /// when it wasn't.
  refreshFailed,

  /// The request needs re-authentication; the screen shows its own exit.
  reauth,

  /// The call was dropped by the re-entrancy guard — another edit or mark
  /// was already in flight, so nothing was attempted. Must not be treated as
  /// silent by the caller (design §B).
  skipped,
}

int _compareTimeOfDay(CareTodaySlot a, CareTodaySlot b) =>
    a.timeOfDay.compareTo(b.timeOfDay);

/// A slot's identity — (careScheduleId, localDate, timeOfDay) — used to spot
/// the same slot across two different [CareTodaySlot] instances: excluding
/// the focus slot from its group (FIX 1) and tracking which row is mid-mark
/// (FIX 8).
typedef _SlotId = ({String careScheduleId, String localDate, String timeOfDay});

_SlotId _idOf(CareTodaySlot slot) => (
  careScheduleId: slot.careScheduleId,
  localDate: slot.localDate,
  timeOfDay: slot.timeOfDay,
);

/// The most-urgent slot for the focus card (design D3): the earliest
/// `overdue` slot by [CareTodaySlot.timeOfDay], else the earliest `pending`
/// slot; `null` when neither exists (the all-done celebration). A pure
/// function of [slots] — unit-tested independent of the controller.
CareTodaySlot? deriveFocusSlot(List<CareTodaySlot> slots) {
  final overdue = slots.where((s) => s.status == CareTodayStatus.overdue).toList()
    ..sort(_compareTimeOfDay);
  if (overdue.isNotEmpty) return overdue.first;
  final pending = slots.where((s) => s.status == CareTodayStatus.pending).toList()
    ..sort(_compareTimeOfDay);
  if (pending.isNotEmpty) return pending.first;
  return null;
}

/// The three checklist sections (design D3), each ordered by
/// [CareTodaySlot.timeOfDay].
class CareTodayGroups {
  final List<CareTodaySlot> overdue;
  final List<CareTodaySlot> later;
  final List<CareTodaySlot> done;

  const CareTodayGroups({
    required this.overdue,
    required this.later,
    required this.done,
  });
}

/// Groups [slots] into overdue / later (pending) / done (done|skipped|
/// missed) (design D3), excluding whichever slot [deriveFocusSlot] picked
/// (FIX 1) — the focus card already renders it, so its group must not repeat
/// it as a row. A pure function of [slots] — unit-tested independent of the
/// controller.
CareTodayGroups deriveGroups(List<CareTodaySlot> slots) {
  final focus = deriveFocusSlot(slots);
  bool isFocus(CareTodaySlot s) => focus != null && _idOf(s) == _idOf(focus);

  final overdue =
      slots
          .where((s) => s.status == CareTodayStatus.overdue && !isFocus(s))
          .toList()
        ..sort(_compareTimeOfDay);
  final later =
      slots
          .where((s) => s.status == CareTodayStatus.pending && !isFocus(s))
          .toList()
        ..sort(_compareTimeOfDay);
  final done =
      slots
          .where(
            (s) =>
                s.status == CareTodayStatus.done ||
                s.status == CareTodayStatus.skipped ||
                s.status == CareTodayStatus.missed,
          )
          .toList()
        ..sort(_compareTimeOfDay);
  return CareTodayGroups(overdue: overdue, later: later, done: done);
}

/// Drives [CareTodayScreen]: [load] fetches today's checklist; [markDone]/
/// [markSkipped] POST the log then re-fetch (design D2 — a *quiet* reload
/// that keeps [status] at `loaded` throughout via the [marking] flag, so the
/// screen never drops to the full-screen loading state for a mark). A mark
/// failure keeps the existing [slots] and surfaces the typed error via
/// [markError]; a 401 from either load or a mark routes [status] to
/// [CareTodayLoadStatus.reauth]. A reload that follows a *successful* mark
/// behaves the same way on failure — it must not discard the just-updated
/// list just because the follow-up GET failed (FIX 2); only the initial
/// [load] drops to the full-screen error state. Holds typed errors, not
/// text — the owning screen maps them to localized copy.
class CareTodayController extends ChangeNotifier {
  final GetCareToday _getToday;
  final MarkCareDone _markDone;
  final MarkCareSkipped _markSkipped;
  final EditCareSlot _editSlot;

  CareTodayController(
    this._getToday,
    this._markDone,
    this._markSkipped,
    this._editSlot, {
    Duration loadTimeout = careTodayLoadTimeout,
  }) : _loadTimeout = loadTimeout;

  /// Wall-clock bound on one checklist fetch. The transport already has
  /// [httpRequestTimeout], but a stall measured in the wild sat *outside* it
  /// (issue #193: the screen opened from a notification span forever with no
  /// error and no retry), so the state machine needs its own end — otherwise
  /// a single unanswerable request is a screen with nothing on it to act on.
  /// Longer than the transport's bound on purpose: when the transport does
  /// answer, its own error must be the one the user sees.
  final Duration _loadTimeout;

  CareTodayLoadStatus status = CareTodayLoadStatus.loading;
  String date = '';
  List<CareTodaySlot> slots = const [];
  Object? error;

  bool marking = false;
  Object? markError;

  /// The slot mid-mark, and which action is being applied to it — `null`
  /// when nothing is in flight. Lets the screen disable/spin only the one
  /// row being acted on instead of every Done/Skip button (FIX 8).
  _SlotId? _markingSlotId;
  CareLogStatus? _markingStatus;

  CareTodaySlot? get focusSlot => deriveFocusSlot(slots);

  CareTodayGroups get groups => deriveGroups(slots);

  /// The action in flight for [slot], or `null` if it isn't the one being
  /// marked right now (FIX 8).
  CareLogStatus? markingAction(CareTodaySlot slot) =>
      _markingSlotId != null && _markingSlotId == _idOf(slot)
      ? _markingStatus
      : null;

  Future<void> _fetch(String idToken) async {
    try {
      final today = await _getToday(idToken).timeout(_loadTimeout);
      date = today.date;
      slots = today.slots;
      status = CareTodayLoadStatus.loaded;
      error = null;
    } catch (e) {
      if (e is CareReauthRequired) {
        status = CareTodayLoadStatus.reauth;
      } else {
        error = e;
        status = CareTodayLoadStatus.error;
      }
    }
  }

  /// The fetch currently in flight, or `null` when none is. Both [load] and
  /// [reloadQuietly] can be driven by the user in quick succession (a reload
  /// follows every care notification tapped while 今日照護 is already open),
  /// and two overlapping GETs would land in completion order — the older
  /// response last, showing a staler list than the one already fetched.
  ///
  /// The *future*, not a `bool`: a caller that arrives during a fetch has to
  /// end up with that round's answer. Returning early instead left it looking
  /// at whatever state the other caller had set — a `loading` that nothing
  /// would ever clear, which is the permanent spinner in issue #193. Bounded
  /// by [_loadTimeout], so a stalled round always releases and a later tap
  /// starts a fresh one rather than joining a round that never returns.
  Future<void>? _inFlight;

  Future<void> load(String idToken) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    status = CareTodayLoadStatus.loading;
    markError = null;
    notifyListeners();
    return _startFetch(() => _fetch(idToken));
  }

  Future<void> _startFetch(Future<void> Function() body) {
    final completer = Completer<void>();
    _inFlight = completer.future;
    unawaited(_runFetch(body, completer));
    return completer.future;
  }

  Future<void> _runFetch(
    Future<void> Function() body,
    Completer<void> completer,
  ) async {
    try {
      await body();
    } finally {
      _inFlight = null;
      notifyListeners();
      completer.complete();
    }
  }

  /// Applies the health screen's batched `care_today` section, leaving this
  /// controller in the state [load] would have left it in for the same
  /// payload.
  ///
  /// A failed section carries [CareRequestFailed] into [error] — the very
  /// exception the granular repository throws — so the screen's error copy
  /// cannot tell a batched failure from a granular one.
  void applyBatchSection(SectionOutcome<CareToday> section) {
    markError = null;
    switch (section) {
      case SectionOk<CareToday>(:final value):
        date = value.date;
        slots = value.slots;
        error = null;
        status = CareTodayLoadStatus.loaded;
      case SectionUnavailable<CareToday>():
        error = const CareRequestFailed();
        status = CareTodayLoadStatus.error;
      case SectionReauth<CareToday>():
        status = CareTodayLoadStatus.reauth;
    }
    notifyListeners();
  }

  /// Re-fetches Today *quietly* for a hand-over that arrives while the screen
  /// is already showing it (design D9): [status] stays `loaded` throughout, so
  /// the list the user is looking at is never replaced by a spinner, and a
  /// failure keeps the existing slots rather than swapping in the full-screen
  /// error state — the same treatment the post-mark reload gets (FIX 2), for
  /// the same reason: losing a rendered list because a background refresh
  /// failed would be misleading. Only a 401 still routes to
  /// [CareTodayLoadStatus.reauth]. Ignored while another fetch is in flight.
  Future<void> reloadQuietly(String idToken) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    return _startFetch(() => _reloadQuietly(idToken));
  }

  Future<void> _reloadQuietly(String idToken) async {
    try {
      final today = await _getToday(idToken).timeout(_loadTimeout);
      date = today.date;
      slots = today.slots;
      error = null;
      // The screen renders from [status], so a successful reload must land on
      // `loaded` even when the previous state was `error`/`reauth`/`loading` —
      // otherwise the freshly fetched list stays hidden behind whatever is on
      // screen, which is exactly the "tapping the notification does nothing"
      // symptom this hand-over exists to remove. Quiet means never *dropping*
      // to `loading` mid-flight, not never writing the status at all.
      status = CareTodayLoadStatus.loaded;
    } catch (e) {
      if (e is CareReauthRequired) {
        status = CareTodayLoadStatus.reauth;
      } else if (status == CareTodayLoadStatus.loading) {
        // Nothing has ever loaded, and the shared in-flight guard may have
        // skipped the screen's own load() for this one. Staying quiet here
        // leaves the initial spinner up forever — no content, no retry, no way
        // out. The error state at least offers a retry button.
        error = e;
        status = CareTodayLoadStatus.error;
      }
      // Any other failure stays silent — the user did not ask for this
      // reload, so it must not take the list away from them.
    }
  }

  /// Runs [action] (a mark call) for ([careScheduleId], [localDate],
  /// [timeOfDay]) marked [status], then quietly re-fetches Today (design
  /// D2 — [CareTodayLoadStatus] stays `loaded` throughout, never dropping to
  /// `loading`). Guarded against re-entrancy — a second call while one is in
  /// flight is ignored.
  ///
  /// A failure from [action] itself keeps the existing [slots] and surfaces
  /// [markError] (or routes to reauth on a 401). Once [action] has
  /// succeeded, a failure from the follow-up reload gets the *same*
  /// treatment (FIX 2) — the mark already happened server-side, so losing
  /// the rendered list here would be misleading; only a reauth 401 on the
  /// reload still routes to [CareTodayLoadStatus.reauth].
  Future<void> _mark(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    required Future<void> Function() action,
  }) async {
    if (marking) {
      // Dropped by the re-entrancy guard — nothing was attempted for this
      // call, so it must not leave a stale markError (from an earlier,
      // already-settled action) looking like it belongs to this one.
      markError = null;
      notifyListeners();
      return;
    }
    marking = true;
    _markingSlotId = (
      careScheduleId: careScheduleId,
      localDate: localDate,
      timeOfDay: timeOfDay,
    );
    _markingStatus = status;
    markError = null;
    notifyListeners();

    try {
      await action();
    } catch (e) {
      if (e is CareReauthRequired) {
        this.status = CareTodayLoadStatus.reauth;
      } else {
        // Keep the existing slots — a mark failure doesn't lose the list.
        markError = e;
      }
      marking = false;
      _markingSlotId = null;
      _markingStatus = null;
      notifyListeners();
      return;
    }

    try {
      final today = await _getToday(idToken);
      date = today.date;
      slots = today.slots;
      error = null;
    } catch (e) {
      if (e is CareReauthRequired) {
        this.status = CareTodayLoadStatus.reauth;
      } else {
        // The mark itself succeeded — keep the existing (now-stale) slots
        // rather than dropping to the full-screen error state.
        markError = e;
      }
    }
    marking = false;
    _markingSlotId = null;
    _markingStatus = null;
    notifyListeners();
  }

  Future<void> markDone(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
  }) => _mark(
    idToken,
    careScheduleId: careScheduleId,
    localDate: localDate,
    timeOfDay: timeOfDay,
    status: CareLogStatus.done,
    action: () => _markDone(
      idToken,
      careScheduleId: careScheduleId,
      localDate: localDate,
      timeOfDay: timeOfDay,
    ),
  );

  Future<void> markSkipped(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
  }) => _mark(
    idToken,
    careScheduleId: careScheduleId,
    localDate: localDate,
    timeOfDay: timeOfDay,
    status: CareLogStatus.skipped,
    action: () => _markSkipped(
      idToken,
      careScheduleId: careScheduleId,
      localDate: localDate,
      timeOfDay: timeOfDay,
    ),
  );

  /// Edits the outcome (and, unless [status] is [CareLogStatus.skipped],
  /// completion time) of ([careScheduleId], [localDate], [timeOfDay]), then
  /// quietly re-fetches Today — same re-entrancy guard and quiet-reload
  /// treatment as [_mark] (never dropping [status] to `loading`; a failure
  /// from either the PUT or the follow-up reload keeps the existing [slots]
  /// and surfaces [markError]). Unlike [_mark], the outcome is also returned
  /// as a [CareTodayEditOutcome] snapshot: the caller opens a bottom sheet
  /// and must know — synchronously from this call, not by re-reading
  /// [markError] afterwards — whether the gate dropped it, since
  /// [markError]/[marking] are shared mutable state a concurrent load or
  /// later edit can clear out from under it (design §B).
  Future<CareTodayEditOutcome> edit(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  }) async {
    if (marking) return CareTodayEditOutcome.skipped;
    marking = true;
    _markingSlotId = (
      careScheduleId: careScheduleId,
      localDate: localDate,
      timeOfDay: timeOfDay,
    );
    _markingStatus = status;
    markError = null;
    notifyListeners();

    CareTodayEditOutcome outcome;
    try {
      await _editSlot(
        idToken,
        careScheduleId: careScheduleId,
        localDate: localDate,
        timeOfDay: timeOfDay,
        status: status,
        // A skipped record was never completed — never send a completion
        // time for it, even if the caller passed one (design §A).
        doneTime: status == CareLogStatus.skipped ? null : doneTime,
      );
      try {
        final today = await _getToday(idToken);
        date = today.date;
        slots = today.slots;
        error = null;
        outcome = CareTodayEditOutcome.saved;
      } catch (e) {
        if (e is CareReauthRequired) {
          this.status = CareTodayLoadStatus.reauth;
          outcome = CareTodayEditOutcome.reauth;
        } else {
          // The edit itself succeeded — keep the existing (now-stale) slots
          // rather than dropping to the full-screen error state, and report
          // it as a *refresh* failure so the caller doesn't announce a save
          // that landed as a loss.
          markError = e;
          outcome = CareTodayEditOutcome.refreshFailed;
        }
      }
    } catch (e) {
      if (e is CareReauthRequired) {
        this.status = CareTodayLoadStatus.reauth;
        outcome = CareTodayEditOutcome.reauth;
      } else {
        // Keep the existing slots — an edit failure doesn't lose the list.
        markError = e;
        outcome = CareTodayEditOutcome.failed;
      }
    }

    marking = false;
    _markingSlotId = null;
    _markingStatus = null;
    notifyListeners();
    return outcome;
  }
}
