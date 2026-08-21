import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
import '../application/get_body_profile.dart';
import '../application/get_weight_goal.dart';
import '../application/set_body_profile.dart';
import '../domain/body_profile_exceptions.dart';
import '../domain/weight_goal.dart';

enum WeightGoalStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the weight goal can fail, as understood by the
/// dashboard / goal card.
enum WeightGoalError { fetchFailed, unknown }

/// Drives the goal card: loads the weight-goal overview (plus the editable body
/// profile for the edit pre-fill) and saves a partial profile update. Every
/// save re-reads from the backend rather than computing locally — mirroring
/// `WaterController._apply`, not a draft-then-save flow.
class WeightGoalController extends ChangeNotifier {
  final GetWeightGoal _getWeightGoal;
  final GetBodyProfile _getBodyProfile;
  final SetBodyProfile _setBodyProfile;

  WeightGoalController(
    this._getWeightGoal,
    this._getBodyProfile,
    this._setBodyProfile,
  );

  WeightGoalStatus status = WeightGoalStatus.loading;
  WeightGoalError? error;
  WeightGoal? goal;
  BodyProfile? profile;

  /// Whether the failure that put [status] in `error` came from [saveProfile]
  /// rather than [load]. Both end up in the same `error`/[error] pair, but the
  /// goal card has to tell them apart: a failed *refresh* leaves correct (if
  /// stale) figures on screen, while a failed *save* leaves figures the user
  /// just tried to replace — marking those "couldn't refresh" would report a
  /// rejected write as a stale read.
  bool lastFailureWasSave = false;

  /// Loads the weight-goal overview and the editable body profile.
  Future<void> load(String idToken) async {
    status = WeightGoalStatus.loading;
    error = null;
    lastFailureWasSave = false;
    notifyListeners();

    try {
      goal = await _getWeightGoal(idToken);
      profile = await _getBodyProfile(idToken);
      status = WeightGoalStatus.loaded;
    } on BodyProfileReauthenticationRequired {
      status = WeightGoalStatus.needsReauth;
    } on BodyProfileFetchFailure {
      status = WeightGoalStatus.error;
      error = WeightGoalError.fetchFailed;
    } catch (_) {
      status = WeightGoalStatus.error;
      error = WeightGoalError.unknown;
    }
    notifyListeners();
  }

  /// Applies the health screen's batched `weight_goal` section, leaving this
  /// controller in the same state [load] would have left it in for the same
  /// payload.
  ///
  /// [profile] is derived from the goal rather than fetched: `/api/weight-goal`
  /// carries the same `height_cm`/`target_weight_kg` the separate
  /// `/api/body-profile` read returns, and those two fields are all
  /// [BodyProfile] holds — so the edit pre-fill is identical without the
  /// second request.
  void applyBatchSection(SectionOutcome<WeightGoal> section) {
    error = null;
    lastFailureWasSave = false;
    switch (section) {
      case SectionOk<WeightGoal>(:final value):
        goal = value;
        profile = BodyProfile(
          heightCm: value.heightCm,
          targetWeightKg: value.targetWeightKg,
        );
        status = WeightGoalStatus.loaded;
      case SectionUnavailable<WeightGoal>():
        status = WeightGoalStatus.error;
        error = WeightGoalError.fetchFailed;
      case SectionReauth<WeightGoal>():
        status = WeightGoalStatus.needsReauth;
    }
    notifyListeners();
  }

  /// Persists a partial profile update, then reloads the overview.
  Future<void> saveProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async {
    status = WeightGoalStatus.saving;
    notifyListeners();

    try {
      await _setBodyProfile(
        idToken,
        heightCm: heightCm,
        targetWeightKg: targetWeightKg,
      );
      await load(idToken);
      return;
    } on BodyProfileReauthenticationRequired {
      status = WeightGoalStatus.needsReauth;
    } on BodyProfileFetchFailure {
      status = WeightGoalStatus.error;
      error = WeightGoalError.fetchFailed;
      lastFailureWasSave = true;
    } catch (_) {
      status = WeightGoalStatus.error;
      error = WeightGoalError.unknown;
      lastFailureWasSave = true;
    }
    notifyListeners();
  }
}
