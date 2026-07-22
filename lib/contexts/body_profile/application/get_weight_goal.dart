import '../domain/body_profile_repository.dart';
import '../domain/weight_goal.dart';

/// Use case: fetch the weight-goal overview.
class GetWeightGoal {
  final BodyProfileRepository _repository;

  GetWeightGoal(this._repository);

  Future<WeightGoal> call(String idToken) => _repository.getWeightGoal(idToken);
}
