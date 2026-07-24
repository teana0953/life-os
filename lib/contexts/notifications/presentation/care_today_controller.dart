import 'package:flutter/foundation.dart';

import '../application/care_today.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';

enum CareTodayLoadStatus { loading, loaded, error, reauth }

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

  CareTodayController(this._getToday, this._markDone, this._markSkipped);

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
      final today = await _getToday(idToken);
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

  Future<void> load(String idToken) async {
    status = CareTodayLoadStatus.loading;
    markError = null;
    notifyListeners();
    await _fetch(idToken);
    notifyListeners();
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
    if (marking) return;
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
}
