import 'package:life_os/shared/screen_batch/section_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_exceptions.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';

class FakeBodyProfileRepository implements BodyProfileRepository {
  WeightGoal goalToReturn = const WeightGoal(targetWeightKg: 51);
  BodyProfile profileToReturn = const BodyProfile(heightCm: 165);
  Object? getError;
  Object? setError;

  int getWeightGoalCalls = 0;
  double? lastSetHeightCm;
  double? lastSetTargetWeightKg;

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    getWeightGoalCalls++;
    if (getError != null) throw getError!;
    return goalToReturn;
  }

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async {
    if (getError != null) throw getError!;
    return profileToReturn;
  }

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async {
    if (setError != null) throw setError!;
    lastSetHeightCm = heightCm;
    lastSetTargetWeightKg = targetWeightKg;
    return BodyProfile(heightCm: heightCm, targetWeightKg: targetWeightKg);
  }
}

WeightGoalController _controller(FakeBodyProfileRepository repository) =>
    WeightGoalController(
      GetWeightGoal(repository),
      GetBodyProfile(repository),
      SetBodyProfile(repository),
    );

void main() {

  group('WeightGoalController.applyBatchSection', () {
    // The health screen no longer calls load(): every card is fanned out from
    // one batch response, so each apply has to land exactly where its own
    // load() landed — value, status, error, and nothing else moved.
    test('ok lands the identical state load() lands for the same payload', () async {
      const goal = WeightGoal(
        heightCm: 165,
        targetWeightKg: 51,
        currentWeightKg: 58,
        remainingKg: 7,
        achievementRate: 40,
        bmi: 21.3,
      );
      final repository = FakeBodyProfileRepository()
        ..goalToReturn = goal
        ..profileToReturn = const BodyProfile(heightCm: 165, targetWeightKg: 51);
      final viaLoad = WeightGoalController(
        GetWeightGoal(repository),
        GetBodyProfile(repository),
        SetBodyProfile(repository),
      );
      await viaLoad.load('token');

      final viaBatch = WeightGoalController(
        GetWeightGoal(repository),
        GetBodyProfile(repository),
        SetBodyProfile(repository),
      );
      viaBatch.applyBatchSection(const SectionOk(goal));

      expect(viaBatch.status, viaLoad.status);
      expect(viaBatch.error, viaLoad.error);
      expect(viaBatch.lastFailureWasSave, viaLoad.lastFailureWasSave);
      expect(viaBatch.goal!.currentWeightKg, viaLoad.goal!.currentWeightKg);
      expect(viaBatch.profile!.heightCm, viaLoad.profile!.heightCm);
      expect(viaBatch.profile!.targetWeightKg, viaLoad.profile!.targetWeightKg);
    });

    test('unavailable reaches the fetch-failed state, not an empty card', () {
      final controller = WeightGoalController(
        GetWeightGoal(FakeBodyProfileRepository()),
        GetBodyProfile(FakeBodyProfileRepository()),
        SetBodyProfile(FakeBodyProfileRepository()),
      );

      controller.applyBatchSection(const SectionUnavailable<WeightGoal>());

      expect(controller.status, WeightGoalStatus.error);
      expect(controller.error, WeightGoalError.fetchFailed);
      expect(controller.lastFailureWasSave, isFalse);
    });

    test('reauth reaches needsReauth', () {
      final controller = WeightGoalController(
        GetWeightGoal(FakeBodyProfileRepository()),
        GetBodyProfile(FakeBodyProfileRepository()),
        SetBodyProfile(FakeBodyProfileRepository()),
      );

      controller.applyBatchSection(const SectionReauth<WeightGoal>());

      expect(controller.status, WeightGoalStatus.needsReauth);
    });
  });


  group('WeightGoalController.load', () {
    test('loads the weight goal and the body profile', () async {
      final repository = FakeBodyProfileRepository()
        ..goalToReturn = const WeightGoal(
          targetWeightKg: 51,
          currentWeightKg: 52,
          remainingKg: 1,
          achievementRate: 75,
          bmi: 19.1,
        )
        ..profileToReturn = const BodyProfile(heightCm: 165, targetWeightKg: 51);
      final controller = _controller(repository);

      await controller.load('token');

      expect(controller.status, WeightGoalStatus.loaded);
      expect(controller.goal!.achievementRate, 75);
      expect(controller.profile!.heightCm, 165);
    });

    test('a 401 surfaces needsReauth', () async {
      final repository = FakeBodyProfileRepository()
        ..getError = const BodyProfileReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token');

      expect(controller.status, WeightGoalStatus.needsReauth);
    });

    test('a fetch failure surfaces an error state', () async {
      final repository = FakeBodyProfileRepository()
        ..getError = const BodyProfileFetchFailure();
      final controller = _controller(repository);

      await controller.load('token');

      expect(controller.status, WeightGoalStatus.error);
      expect(controller.error, WeightGoalError.fetchFailed);
    });
  });

  group('WeightGoalController.saveProfile', () {
    test('PUTs the entered values then re-reads the goal', () async {
      final repository = FakeBodyProfileRepository();
      final controller = _controller(repository);
      await controller.load('token');
      final callsAfterLoad = repository.getWeightGoalCalls;

      await controller.saveProfile('token', heightCm: 165, targetWeightKg: 50);

      expect(repository.lastSetHeightCm, 165);
      expect(repository.lastSetTargetWeightKg, 50);
      // Re-read after the save (one more getWeightGoal than after the load).
      expect(repository.getWeightGoalCalls, callsAfterLoad + 1);
      expect(controller.status, WeightGoalStatus.loaded);
    });

    test('a save 401 surfaces needsReauth', () async {
      final repository = FakeBodyProfileRepository()
        ..setError = const BodyProfileReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load('token');

      await controller.saveProfile('token', targetWeightKg: 50);

      expect(controller.status, WeightGoalStatus.needsReauth);
    });

    test('a save failure surfaces an error state', () async {
      final repository = FakeBodyProfileRepository()
        ..setError = const BodyProfileFetchFailure();
      final controller = _controller(repository);
      await controller.load('token');

      await controller.saveProfile('token', targetWeightKg: 50);

      expect(controller.status, WeightGoalStatus.error);
      expect(controller.error, WeightGoalError.fetchFailed);
    });
  });
}
