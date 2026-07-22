import 'package:flutter/foundation.dart';

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

  /// Loads the weight-goal overview and the editable body profile.
  Future<void> load(String idToken) async {
    status = WeightGoalStatus.loading;
    error = null;
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
    } catch (_) {
      status = WeightGoalStatus.error;
      error = WeightGoalError.unknown;
    }
    notifyListeners();
  }
}
