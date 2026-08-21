import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
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
  /// Bumped by every [load] call, synchronously before its first `await` —
  /// an explicit-navigation generation counter [applyBatchSection] checks
  /// against [_claimedGeneration], not against the day itself.
  ///
  /// A day comparison (`this.day.day == day`) is what this replaced, and it
  /// over-corrected: comparing days strands the controller on whatever day
  /// it already happens to hold whenever a round's day differs from it —
  /// including the ordinary cases where nothing has navigated at all, e.g.
  /// the day rolling over at midnight, or a round catching a browsed-away
  /// tracker back up to today once the screen showing it is gone. The
  /// generation only moves on an explicit [load], so a round claimed after
  /// the last one is authoritative for whatever day it computed, whatever
  /// this controller currently holds — and a round claimed BEFORE a [load]
  /// that has since started or already landed is correctly refused, which is
  /// the case [applyBatchSection]'s tests guard.
  int _generation = 0;

  /// The generation a whole-screen batch round has claimed, via
  /// [claimBatchRound]. `null` (no round has claimed one yet) reads as "not
  /// claimed" in [applyBatchSection], so an unclaimed section is refused
  /// rather than accepted by accident.
  int? _claimedGeneration;

  /// Records the generation a whole-screen batch round is about to fetch
  /// for. Call synchronously, before the round's request goes out — mirrors
  /// [HealthCalendarController.claimBatchMonth].
  void claimBatchRound() => _claimedGeneration = _generation;

  Future<void> load(String idToken, String day) async {
    _generation++;
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

  /// Applies the health screen's batched `exercise_activities` + `exercise`
  /// sections for [day], leaving this controller in the state [load] would
  /// have left it in for the same payloads.
  ///
  /// Two sections, because [load] makes two reads. The activity library is
  /// static, so it is taken only when this controller has none — exactly
  /// [load]'s `activities.isEmpty` condition — and a failure to read it is
  /// only a failure when it was going to be read: [load] would not have
  /// requested it at all with a library already in memory.
  void applyBatchSection({
    required SectionOutcome<List<ExerciseActivity>> activities,
    required SectionOutcome<ExerciseDay> exercise,
  }) {
    if (_claimedGeneration != _generation) return;
    error = null;
    final needsActivities = this.activities.isEmpty;
    if (activities is SectionReauth<List<ExerciseActivity>> &&
            needsActivities ||
        exercise is SectionReauth<ExerciseDay>) {
      status = ExerciseStatus.needsReauth;
      notifyListeners();
      return;
    }
    if (needsActivities && activities is SectionOk<List<ExerciseActivity>>) {
      this.activities = activities.value;
    }
    if (needsActivities && activities is! SectionOk<List<ExerciseActivity>>) {
      status = ExerciseStatus.error;
      error = ExerciseError.fetchFailed;
      notifyListeners();
      return;
    }
    switch (exercise) {
      case SectionOk<ExerciseDay>(:final value):
        day = value;
        status = ExerciseStatus.loaded;
        lastLoadedAt = _clock();
      case SectionUnavailable<ExerciseDay>():
        status = ExerciseStatus.error;
        error = ExerciseError.fetchFailed;
      case SectionReauth<ExerciseDay>():
        status = ExerciseStatus.needsReauth;
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
