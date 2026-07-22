import 'menstrual_period.dart';

/// Port for the menstrual tracker: the whole overview (periods + derived
/// stats + last period) and immediate add/update/delete of a period. Not
/// day-keyed — a period is a date range, independent of any viewed day.
abstract class MenstrualRepository {
  /// The user's whole period history plus derived cycle statistics.
  Future<MenstrualOverview> getOverview(String idToken);

  /// Records a new period; returns the created period.
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  });

  /// Partially updates the period [id]. Only the fields the caller passes are
  /// changed: [startDate] and/or [endDate] are set when non-null; passing
  /// [clearEndDate] `true` clears the end date (reopening a completed period).
  /// Not passing a field leaves it untouched.
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  });

  /// Deletes the period [id]; returns whether one was deleted.
  Future<bool> deletePeriod(String idToken, String id);
}
