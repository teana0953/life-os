import 'package:flutter/foundation.dart';

import '../application/add_exercise_entry.dart';
import '../application/delete_exercise_entry.dart';
import '../application/get_exercise_day.dart';
import '../application/list_exercise_activities.dart';
import '../domain/exercise_day.dart';
import '../domain/exercise_exceptions.dart';

enum ExerciseStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the day's exercise can fail, as understood by
/// `ExerciseScreen`.
enum ExerciseError { fetchFailed, unknown }

/// Drives the exercise screen: loads a day's entries (plus the static activity
/// library for the picker), and appends/removes entries immediately. Every
/// mutation re-reads the day from the backend rather than computing the total
/// locally — mirroring `WaterController._apply`, not a draft-then-save flow.
class ExerciseController extends ChangeNotifier {
  final ListExerciseActivities _listActivities;
  final GetExerciseDay _getDay;
  final AddExerciseEntry _addEntry;
  final DeleteExerciseEntry _deleteEntry;

  /// Injectable clock used to stamp [lastLoadedAt] on a successful load.
  /// Defaults to [DateTime.now]; tests pin it so the stamp is deterministic
  /// (mirrors the home greeting / reminders-throttle clocks).
  final DateTime Function() _clock;

  ExerciseController(
    this._listActivities,
    this._getDay,
    this._addEntry,
    this._deleteEntry, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  ExerciseStatus status = ExerciseStatus.loading;
  ExerciseError? error;
  ExerciseDay? day;
  List<ExerciseActivity> activities = [];

  /// When the day was last loaded successfully, or `null` before the first
  /// success — updated only on a successful [load], left unchanged on failure
  /// so it always reflects the data currently shown.
  DateTime? lastLoadedAt;

  /// Loads the day's entries and, if not already cached, the static activity
  /// library. The library is static, so it is fetched only once per controller.
  Future<void> load(String idToken, String day) async {
    status = ExerciseStatus.loading;
    error = null;
    notifyListeners();

    try {
      if (activities.isEmpty) {
        activities = await _listActivities(idToken);
      }
      this.day = await _getDay(idToken, day);
      status = ExerciseStatus.loaded;
      lastLoadedAt = _clock();
    } on ExerciseReauthenticationRequired {
      status = ExerciseStatus.needsReauth;
    } on ExerciseFetchFailure {
      status = ExerciseStatus.error;
      error = ExerciseError.fetchFailed;
    } catch (_) {
      status = ExerciseStatus.error;
      error = ExerciseError.unknown;
    }
    notifyListeners();
  }

  /// Appends an entry, then reloads the day (the total reflects the new entry).
  Future<void> addEntry(
    String idToken,
    String day, {
    required String activityId,
    required int durationMinutes,
    required String note,
  }) => _apply(
    idToken,
    day,
    () => _addEntry(
      idToken,
      day: day,
      activityId: activityId,
      durationMinutes: durationMinutes,
      note: note,
    ),
  );

  /// Removes an entry, then reloads the day (the total drops accordingly).
  Future<void> deleteEntry(String idToken, String day, String entryId) =>
      _apply(idToken, day, () => _deleteEntry(idToken, entryId));

  Future<void> _apply(
    String idToken,
    String day,
    Future<void> Function() mutation,
  ) async {
    status = ExerciseStatus.saving;
    notifyListeners();

    try {
      await mutation();
      await load(idToken, day);
      return;
    } on ExerciseReauthenticationRequired {
      status = ExerciseStatus.needsReauth;
    } on ExerciseFetchFailure {
      status = ExerciseStatus.error;
      error = ExerciseError.fetchFailed;
    } catch (_) {
      status = ExerciseStatus.error;
      error = ExerciseError.unknown;
    }
    notifyListeners();
  }
}
