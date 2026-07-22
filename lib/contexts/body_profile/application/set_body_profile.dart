import '../domain/body_profile_repository.dart';
import '../domain/weight_goal.dart';

/// Use case: set the body profile (partial — only the provided fields are
/// sent).
class SetBodyProfile {
  final BodyProfileRepository _repository;

  SetBodyProfile(this._repository);

  Future<BodyProfile> call(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) => _repository.setBodyProfile(
    idToken,
    heightCm: heightCm,
    targetWeightKg: targetWeightKg,
  );
}
