import 'care_item.dart';

/// The status of a single care slot for today (design D3): still due
/// (`pending`), overdue, already `done`, deliberately `skipped`, or `missed`
/// (past due with no record). Drives grouping and which inline actions the
/// screen shows (design D4).
enum CareTodayStatus { pending, overdue, done, skipped, missed }

/// Parses the backend wire enum string into a [CareTodayStatus]. Throws
/// [FormatException] for an unrecognized value — the caller (infrastructure)
/// turns that into [CareRequestFailed].
CareTodayStatus careTodayStatusFromWire(String value) => switch (value) {
  'pending' => CareTodayStatus.pending,
  'overdue' => CareTodayStatus.overdue,
  'done' => CareTodayStatus.done,
  'skipped' => CareTodayStatus.skipped,
  'missed' => CareTodayStatus.missed,
  _ => throw FormatException('Unknown care today status: $value'),
};

/// The two statuses that can be POSTed to `/api/care/log` — only
/// `pending`/`overdue` slots are actionable (design D4).
enum CareLogStatus { done, skipped }

/// The backend wire enum string for [CareLogStatus] — sent, never a
/// localized label.
extension CareLogStatusWire on CareLogStatus {
  String get wireValue => switch (this) {
    CareLogStatus.done => 'done',
    CareLogStatus.skipped => 'skipped',
  };
}

/// A single care slot for today. [category] reuses the existing Slice-D
/// [CareCategory] (design D2b — not redefined here). [note]/[dose]/
/// [doneTime] are nullable per the backend contract; [doseQuantity] is
/// always sent (mirrors [CareSchedule.doseQuantity] — required regardless of
/// category).
class CareTodaySlot {
  final String careItemId;
  final String careScheduleId;
  final CareCategory category;
  final String title;
  final String? note;
  final String? dose;

  /// "HH:mm" 24h time.
  final String timeOfDay;

  /// "YYYY-MM-DD" — today's date, echoed per slot.
  final String localDate;

  final CareTodayStatus status;
  final String? doneTime;
  final double doseQuantity;

  const CareTodaySlot({
    required this.careItemId,
    required this.careScheduleId,
    required this.category,
    required this.title,
    this.note,
    this.dose,
    required this.timeOfDay,
    required this.localDate,
    required this.status,
    this.doneTime,
    required this.doseQuantity,
  });

  @override
  bool operator ==(Object other) =>
      other is CareTodaySlot &&
      other.careItemId == careItemId &&
      other.careScheduleId == careScheduleId &&
      other.category == category &&
      other.title == title &&
      other.note == note &&
      other.dose == dose &&
      other.timeOfDay == timeOfDay &&
      other.localDate == localDate &&
      other.status == status &&
      other.doneTime == doneTime &&
      other.doseQuantity == doseQuantity;

  @override
  int get hashCode => Object.hash(
    careItemId,
    careScheduleId,
    category,
    title,
    note,
    dose,
    timeOfDay,
    localDate,
    status,
    doneTime,
    doseQuantity,
  );
}

/// Today's full checklist: the [date] ("YYYY-MM-DD") and its [slots] (design
/// D1 — the backend returns `{date, items:[...]}`, not a bare array).
class CareToday {
  final String date;
  final List<CareTodaySlot> slots;

  const CareToday({required this.date, required this.slots});
}

/// Port for the backend's `/api/care/today` (read) and `/api/care/log`
/// (write) endpoints. Typed errors [CareReauthRequired]/[CareRequestFailed]
/// are reused from `care_item.dart` (design D2b — not redefined here).
abstract class CareTodayRepository {
  Future<CareToday> getToday(String idToken);

  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  });
}
