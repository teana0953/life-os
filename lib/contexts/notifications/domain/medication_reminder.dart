/// A medication reminder: fires at each of [times] on [daysOfWeek] every
/// [weekInterval] week(s) — [anchorDate] is the cadence's reference date
/// (needed once [weekInterval] > 1) — while [enabled].
class MedicationReminder {
  final String id;
  final String label;

  /// "HH:mm" 24h times.
  final List<String> times;

  /// Weekdays this fires on, 0=Sun..6=Sat (matches the backend).
  final List<int> daysOfWeek;

  final int weekInterval;
  final DateTime anchorDate;
  final bool enabled;

  const MedicationReminder({
    required this.id,
    required this.label,
    required this.times,
    required this.daysOfWeek,
    required this.weekInterval,
    required this.anchorDate,
    required this.enabled,
  });

  @override
  bool operator ==(Object other) =>
      other is MedicationReminder &&
      other.id == id &&
      other.label == label &&
      _listEquals(other.times, times) &&
      _listEquals(other.daysOfWeek, daysOfWeek) &&
      other.weekInterval == weekInterval &&
      other.anchorDate == anchorDate &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    Object.hashAll(times),
    Object.hashAll(daysOfWeek),
    weekInterval,
    anchorDate,
    enabled,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The fields for creating a new reminder — all required (no [id]; the
/// backend assigns one).
class MedicationReminderDraft {
  final String label;
  final List<String> times;
  final List<int> daysOfWeek;
  final int weekInterval;
  final DateTime anchorDate;
  final bool enabled;

  const MedicationReminderDraft({
    required this.label,
    required this.times,
    required this.daysOfWeek,
    required this.weekInterval,
    required this.anchorDate,
    required this.enabled,
  });
}

/// A partial update: only the non-null fields are sent (the backend PATCH
/// treats an omitted field as no-change) — the enable toggle sends only
/// [enabled] (design D3), while editing the full form sends every field.
class MedicationReminderUpdate {
  final String? label;
  final List<String>? times;
  final List<int>? daysOfWeek;
  final int? weekInterval;
  final DateTime? anchorDate;
  final bool? enabled;

  const MedicationReminderUpdate({
    this.label,
    this.times,
    this.daysOfWeek,
    this.weekInterval,
    this.anchorDate,
    this.enabled,
  });
}

/// Thrown when the backend rejects the lifeos ID token (HTTP 401) — the
/// caller must sign in again.
class ReminderReauthRequired implements Exception {
  const ReminderReauthRequired();
}

/// Thrown for any other non-2xx response, network error, or unparseable
/// body.
class ReminderRequestFailed implements Exception {
  const ReminderRequestFailed();
}

/// Port for the backend's `/api/reminders/medication` + `/api/user/timezone`
/// endpoints. No `getTimezone` — the backend exposes no read endpoint
/// (design D5); the UI shows a locally-remembered/default value instead.
abstract class MedicationReminderRepository {
  Future<List<MedicationReminder>> list(String idToken);

  Future<void> create(String idToken, MedicationReminderDraft draft);

  Future<void> update(
    String idToken,
    String id,
    MedicationReminderUpdate update,
  );

  Future<void> delete(String idToken, String id);

  Future<void> setTimezone(String idToken, String timezone);
}
