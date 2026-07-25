import 'package:flutter/foundation.dart';

import '../application/edit_care_slot.dart';
import '../application/get_care_history.dart';
import '../domain/care_history.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';

enum CareHistoryLoadStatus { loading, loaded, error, reauth }

/// Drives [CareHistoryScreen]: [load] fetches a date range (design mirrors
/// [TrendController] — [status] flips to `loading` on every call including a
/// period-switch reload, but [days] is only overwritten on success, so the
/// screen can keep showing the previous content with a thin progress
/// indicator instead of blanking). [edit] PUTs a slot's new outcome then
/// quietly re-fetches the same range (design mirrors
/// [CareTodayController]'s marking mechanism: the [editing] flag, never
/// dropping [status] back to `loading`). An edit failure keeps the existing
/// [days] and surfaces the typed error via [editError]; a 401 from either
/// [load] or [edit] routes [status] to [CareHistoryLoadStatus.reauth]. A
/// reload that follows a *successful* edit behaves the same way on failure
/// — it must not discard the just-updated list just because the follow-up
/// GET failed (FIX 2, mirroring `CareTodayController`); only a reauth 401 on
/// that reload still routes to reauth. Holds typed errors, not text — the
/// owning screen maps them to localized copy.
class CareHistoryController extends ChangeNotifier {
  final GetCareHistory _getHistory;
  final EditCareSlot _editSlot;

  CareHistoryController(this._getHistory, this._editSlot);

  CareHistoryLoadStatus status = CareHistoryLoadStatus.loading;
  List<CareHistoryDay> days = const [];
  Object? error;

  bool editing = false;
  Object? editError;

  String _from = '';
  String _to = '';

  Future<void> _fetch(String idToken, String from, String to) async {
    try {
      days = await _getHistory(idToken, from, to);
      status = CareHistoryLoadStatus.loaded;
      error = null;
    } catch (e) {
      if (e is CareReauthRequired) {
        status = CareHistoryLoadStatus.reauth;
      } else {
        error = e;
        status = CareHistoryLoadStatus.error;
      }
    }
  }

  /// Loads the range [from]–[to] (inclusive), remembering it so a
  /// subsequent [edit] can quietly re-fetch the same range.
  Future<void> load(String idToken, String from, String to) async {
    _from = from;
    _to = to;
    status = CareHistoryLoadStatus.loading;
    editError = null;
    notifyListeners();
    await _fetch(idToken, from, to);
    notifyListeners();
  }

  /// Sets the outcome of the slot identified by ([careScheduleId],
  /// [localDate], [timeOfDay]) to [status], then quietly re-fetches the last
  /// loaded range (design — [CareHistoryLoadStatus] stays `loaded`
  /// throughout, never dropping to `loading`). Guarded against
  /// re-entrancy — a second call while one is in flight is ignored.
  Future<void> edit(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    if (editing) return;
    editing = true;
    editError = null;
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
      if (e is CareReauthRequired) {
        this.status = CareHistoryLoadStatus.reauth;
      } else {
        // Keep the existing days — an edit failure doesn't lose the list.
        editError = e;
      }
      editing = false;
      notifyListeners();
      return;
    }

    try {
      days = await _getHistory(idToken, _from, _to);
      error = null;
    } catch (e) {
      if (e is CareReauthRequired) {
        this.status = CareHistoryLoadStatus.reauth;
      } else {
        // The edit itself succeeded — keep the existing (now-stale) days
        // rather than dropping to the full-screen error state (FIX 2).
        editError = e;
      }
    }
    editing = false;
    notifyListeners();
  }
}
