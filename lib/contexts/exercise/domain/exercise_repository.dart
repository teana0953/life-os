import 'exercise_day.dart';

/// Port for the exercise tracker: the static activity library, a day's
/// entries, and immediate append/remove of an entry.
abstract class ExerciseRepository {
  /// The static, shared activity library.
  Future<List<ExerciseActivity>> listActivities(String idToken);

  /// The [day]'s entries and total duration.
  Future<ExerciseDay> getDay(String idToken, String day);

  /// Appends an entry to [day]; returns the created entry.
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  });

  /// Removes the entry with [entryId]; returns whether one was deleted.
  Future<bool> deleteEntry(String idToken, String entryId);
}
