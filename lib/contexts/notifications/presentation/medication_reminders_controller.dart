import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/medication_reminders.dart';
import '../domain/medication_reminder.dart';

const _timezonePrefsKey = 'medication_reminder_timezone';

/// The default timezone shown until the user sets one (design D5).
const defaultMedicationReminderTimezone = 'Asia/Taipei';

enum MedicationRemindersStatus { loading, loaded, error, reauth }

/// Drives [MedicationRemindersScreen]: [load] fetches the list; [create],
/// [update], [delete], and [toggleEnabled] each call their endpoint then
/// reload the list (design D2) so the screen always reflects server truth. A
/// mutation failure keeps the existing [reminders] and surfaces the typed
/// error via [mutationError] without changing [status] away from `loaded`; a
/// 401 from any call (load or mutation) routes [status] to
/// [MedicationRemindersStatus.reauth]. Holds typed errors, not text — the
/// owning screen maps them to localized copy.
///
/// [timezone] has no server read (design D5 — the backend exposes no GET):
/// it starts at the last value persisted via [SharedPreferences] (default
/// [defaultMedicationReminderTimezone]) and is updated + persisted only on a
/// successful [setTimezone].
class MedicationRemindersController extends ChangeNotifier {
  final ListMedicationReminders _list;
  final CreateMedicationReminder _create;
  final UpdateMedicationReminder _update;
  final DeleteMedicationReminder _delete;
  final SetReminderTimezone _setTimezone;
  final SharedPreferences _prefs;

  MedicationRemindersController(
    this._list,
    this._create,
    this._update,
    this._delete,
    this._setTimezone,
    this._prefs,
  ) : timezone =
          _prefs.getString(_timezonePrefsKey) ??
          defaultMedicationReminderTimezone;

  MedicationRemindersStatus status = MedicationRemindersStatus.loading;
  List<MedicationReminder> reminders = const [];
  Object? error;

  bool mutating = false;
  Object? mutationError;

  String timezone;
  bool settingTimezone = false;
  Object? timezoneError;

  Future<void> _fetchList(String idToken) async {
    try {
      reminders = await _list(idToken);
      status = MedicationRemindersStatus.loaded;
      error = null;
    } catch (e) {
      if (e is ReminderReauthRequired) {
        status = MedicationRemindersStatus.reauth;
      } else {
        error = e;
        status = MedicationRemindersStatus.error;
      }
    }
  }

  Future<void> load(String idToken) async {
    status = MedicationRemindersStatus.loading;
    mutationError = null;
    notifyListeners();
    await _fetchList(idToken);
    notifyListeners();
  }

  /// Runs [action] (create/update/delete), then reloads the list (design
  /// D2). Guarded against re-entrancy — a second call while one is already
  /// in flight is ignored.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    if (mutating) return;
    mutating = true;
    mutationError = null;
    notifyListeners();

    try {
      await action();
      await _fetchList(idToken);
    } catch (e) {
      if (e is ReminderReauthRequired) {
        status = MedicationRemindersStatus.reauth;
      } else {
        // Keep the existing list — a mutation failure doesn't lose it.
        mutationError = e;
      }
    }
    mutating = false;
    notifyListeners();
  }

  Future<void> create(String idToken, MedicationReminderDraft draft) =>
      _mutate(idToken, () => _create(idToken, draft));

  Future<void> update(
    String idToken,
    String id,
    MedicationReminderUpdate changes,
  ) => _mutate(idToken, () => _update(idToken, id, changes));

  Future<void> delete(String idToken, String id) =>
      _mutate(idToken, () => _delete(idToken, id));

  /// Enable toggle: PATCHes just `enabled` (design D3).
  Future<void> toggleEnabled(String idToken, String id, bool enabled) =>
      _mutate(
        idToken,
        () => _update(idToken, id, MedicationReminderUpdate(enabled: enabled)),
      );

  Future<void> setTimezone(String idToken, String tz) async {
    if (settingTimezone) return;
    settingTimezone = true;
    timezoneError = null;
    notifyListeners();

    try {
      await _setTimezone(idToken, tz);
      timezone = tz;
      await _prefs.setString(_timezonePrefsKey, tz);
    } catch (e) {
      if (e is ReminderReauthRequired) {
        status = MedicationRemindersStatus.reauth;
      } else {
        timezoneError = e;
      }
    }
    settingTimezone = false;
    notifyListeners();
  }
}
