import 'weight_goal.dart';

/// Port for the body profile / weight goal: the weight-goal overview, the
/// editable body profile, and a partial update of the profile.
abstract class BodyProfileRepository {
  /// The weight-goal overview (target/current/remaining, achievement, BMI).
  Future<WeightGoal> getWeightGoal(String idToken);

  /// The editable body profile (height + target weight), for the edit pre-fill.
  Future<BodyProfile> getBodyProfile(String idToken);

  /// Sets the body profile; only the provided (non-null) fields are sent, so an
  /// untouched field is left unchanged. Returns the updated profile.
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  });
}
