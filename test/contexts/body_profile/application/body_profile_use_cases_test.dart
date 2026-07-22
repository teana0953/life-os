import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';

class _FakeRepository implements BodyProfileRepository {
  String? getWeightGoalToken;
  String? getBodyProfileToken;
  String? setToken;
  double? setHeightCm;
  double? setTargetWeightKg;

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    getWeightGoalToken = idToken;
    return const WeightGoal(targetWeightKg: 51);
  }

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async {
    getBodyProfileToken = idToken;
    return const BodyProfile(heightCm: 165, targetWeightKg: 51);
  }

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async {
    setToken = idToken;
    setHeightCm = heightCm;
    setTargetWeightKg = targetWeightKg;
    return BodyProfile(heightCm: heightCm, targetWeightKg: targetWeightKg);
  }
}

void main() {
  test('GetWeightGoal delegates to the repository', () async {
    final repository = _FakeRepository();
    final goal = await GetWeightGoal(repository)('token-1');
    expect(repository.getWeightGoalToken, 'token-1');
    expect(goal.targetWeightKg, 51);
  });

  test('GetBodyProfile delegates to the repository', () async {
    final repository = _FakeRepository();
    final profile = await GetBodyProfile(repository)('token-2');
    expect(repository.getBodyProfileToken, 'token-2');
    expect(profile.heightCm, 165);
  });

  test('SetBodyProfile passes the partial fields through', () async {
    final repository = _FakeRepository();
    await SetBodyProfile(repository)('token-3', targetWeightKg: 50);
    expect(repository.setToken, 'token-3');
    expect(repository.setHeightCm, isNull);
    expect(repository.setTargetWeightKg, 50);
  });
}
