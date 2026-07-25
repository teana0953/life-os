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
/// dropping [status] back to `loading`). A PUT failure keeps the existing
/// [days] and surfaces the typed error via [editError] — the edit did not
/// take effect. A *successful* PUT whose follow-up GET fails surfaces that
/// separately via [refreshError] instead (FIX 2/3): the edit itself
/// succeeded server-side, only the refresh of the list failed, so the
/// screen must not tell the user their edit was lost — it must not discard
/// the just-updated list either. A 401 from [load], the edit PUT, or the
/// post-edit refresh routes [status] to [CareHistoryLoadStatus.reauth].
/// Holds typed errors, not text — the owning screen maps them to localized
/// copy.
class CareHistoryController extends ChangeNotifier {
  final GetCareHistory _getHistory;
  final EditCareSlot _editSlot;

  CareHistoryController(this._getHistory, this._editSlot);

  CareHistoryLoadStatus status = CareHistoryLoadStatus.loading;
  List<CareHistoryDay> days = const [];
  Object? error;

  bool editing = false;
  Object? editError;
  Object? refreshError;

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
    refreshError = null;
    notifyListeners();
    await _fetch(idToken, from, to);
    notifyListeners();
  }

  /// Sets the outcome of the slot identified by ([careScheduleId],
  /// [localDate], [timeOfDay]) to [status], then quietly re-fetches the last
  /// loaded range (design — [CareHistoryLoadStatus] stays `loaded`
  /// throughout, never dropping to `loading`). Guarded against
  /// re-entrancy — a second call while one is in flight is ignored. A PUT
  /// failure surfaces via [editError]; a PUT success whose refresh fails
  /// surfaces via [refreshError] instead (FIX 3) — the two must not be
  /// conflated, since only the former means the edit itself was lost.
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
        // rather than dropping to the full-screen error state (FIX 2), and
        // report the refresh failure separately from an edit failure
        // (FIX 3) so the screen doesn't tell the user the edit was lost.
        refreshError = e;
      }
    }
    editing = false;
    notifyListeners();
  }
}
