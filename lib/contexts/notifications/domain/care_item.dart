/// The category of a care reminder — drives which item-level fields apply
/// (design D2: dose/stock/stockAlert render and are sent only for
/// [medication]) and how the list screen groups reminders.
enum CareCategory { medication, rehab, radiotherapyCare, custom }

/// The backend wire enum string for [CareCategory] — sent, never a localized
/// label (design D2's Slice-2b trap).
extension CareCategoryWire on CareCategory {
  String get wireValue => switch (this) {
    CareCategory.medication => 'medication',
    CareCategory.rehab => 'rehab',
    CareCategory.radiotherapyCare => 'radiotherapy_care',
    CareCategory.custom => 'custom',
  };
}

/// Parses the backend wire enum string into a [CareCategory]. Throws
/// [FormatException] for an unrecognized value — the caller (infrastructure)
/// turns that into [CareRequestFailed].
CareCategory careCategoryFromWire(String value) => switch (value) {
  'medication' => CareCategory.medication,
  'rehab' => CareCategory.rehab,
  'radiotherapy_care' => CareCategory.radiotherapyCare,
  'custom' => CareCategory.custom,
  _ => throw FormatException('Unknown care category: $value'),
};

/// A single schedule on a [CareItem]: fires at [timeOfDay] on [repeatDays]
/// (empty = every day) every [weekInterval] week(s) — [startDate] is the
/// cadence's reference date (also the earliest date it applies) — until the
/// optional [endDate], while [enabled]. [doseQuantity] is the amount taken
/// per firing; the backend requires it (and [startDate]) on every schedule
/// regardless of category (design D2/D3 — the Slice-2b trap), even though
/// the form only shows a quantity editor for medication.
///
/// [id] is `null` for a schedule not yet persisted (new, in a draft/update);
/// an existing schedule keeps its [id] on edit so the backend upserts by id
/// and preserves adherence history (design D5).
class CareSchedule {
  final String? id;

  /// "HH:mm" 24h time.
  final String timeOfDay;

  /// Weekdays this fires on, 0=Sun..6=Sat (matches the backend); empty means
  /// every day.
  final List<int> repeatDays;

  final int weekInterval;
  final DateTime startDate;
  final DateTime? endDate;
  final double doseQuantity;
  final int nagIntervalMinutes;
  final bool enabled;

  const CareSchedule({
    this.id,
    required this.timeOfDay,
    required this.repeatDays,
    required this.weekInterval,
    required this.startDate,
    this.endDate,
    required this.doseQuantity,
    required this.nagIntervalMinutes,
    required this.enabled,
  });

  @override
  bool operator ==(Object other) =>
      other is CareSchedule &&
      other.id == id &&
      other.timeOfDay == timeOfDay &&
      _listEquals(other.repeatDays, repeatDays) &&
      other.weekInterval == weekInterval &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.doseQuantity == doseQuantity &&
      other.nagIntervalMinutes == nagIntervalMinutes &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
    id,
    timeOfDay,
    Object.hashAll(repeatDays),
    weekInterval,
    startDate,
    endDate,
    doseQuantity,
    nagIntervalMinutes,
    enabled,
  );
}

/// A generic care reminder: medication, rehab, radiotherapy care, or a
/// custom reminder. [dose]/[stock]/[stockAlert] are medication-only — `null`
/// (and not sent) for every other category (design D2).
class CareItem {
  final String id;
  final CareCategory category;
  final String title;
  final String? note;
  final String? dose;
  final double? stock;
  final double? stockAlert;
  final List<CareSchedule> schedules;

  const CareItem({
    required this.id,
    required this.category,
    required this.title,
    this.note,
    this.dose,
    this.stock,
    this.stockAlert,
    required this.schedules,
  });

  @override
  bool operator ==(Object other) =>
      other is CareItem &&
      other.id == id &&
      other.category == category &&
      other.title == title &&
      other.note == note &&
      other.dose == dose &&
      other.stock == stock &&
      other.stockAlert == stockAlert &&
      _listEquals(other.schedules, schedules);

  @override
  int get hashCode => Object.hash(
    id,
    category,
    title,
    note,
    dose,
    stock,
    stockAlert,
    Object.hashAll(schedules),
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

/// The fields for creating a new [CareItem] — no [id] (the backend assigns
/// one). Mirrors [CareItem]'s shape minus [id].
class CareItemDraft {
  final CareCategory category;
  final String title;
  final String? note;
  final String? dose;
  final double? stock;
  final double? stockAlert;
  final List<CareSchedule> schedules;

  const CareItemDraft({
    required this.category,
    required this.title,
    this.note,
    this.dose,
    this.stock,
    this.stockAlert,
    required this.schedules,
  });
}

/// The full replacement body for updating an existing [CareItem] — the
/// backend PATCH replaces the whole item (including the whole `schedules`
/// array, design D5), so every field is sent, not just changed ones.
class CareItemUpdate {
  final CareCategory category;
  final String title;
  final String? note;
  final String? dose;
  final double? stock;
  final double? stockAlert;
  final List<CareSchedule> schedules;

  const CareItemUpdate({
    required this.category,
    required this.title,
    this.note,
    this.dose,
    this.stock,
    this.stockAlert,
    required this.schedules,
  });
}

/// Thrown when the backend rejects the lifeos ID token (HTTP 401) — the
/// caller must sign in again.
class CareReauthRequired implements Exception {
  const CareReauthRequired();
}

/// Thrown for any other non-2xx response, network error, or unparseable
/// body.
class CareRequestFailed implements Exception {
  const CareRequestFailed();
}

/// Port for the backend's `/api/care/items` endpoints. No `logSlot` this
/// slice — the `/api/care/log` answer endpoint is wired in Slice C.
abstract class CareItemRepository {
  Future<List<CareItem>> list(String idToken);

  Future<CareItem> create(String idToken, CareItemDraft draft);

  Future<CareItem> update(String idToken, String id, CareItemUpdate update);

  Future<void> delete(String idToken, String id);
}
