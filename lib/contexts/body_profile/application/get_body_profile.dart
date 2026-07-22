import '../domain/body_profile_repository.dart';
import '../domain/weight_goal.dart';

/// Use case: fetch the editable body profile (for the edit pre-fill).
class GetBodyProfile {
  final BodyProfileRepository _repository;

  GetBodyProfile(this._repository);

  Future<BodyProfile> call(String idToken) =>
      _repository.getBodyProfile(idToken);
}
