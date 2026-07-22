import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';

void main() {
  group('WeightGoal.fromJson', () {
    test('parses snake_case fields', () {
      final goal = WeightGoal.fromJson({
        'height_cm': 165,
        'target_weight_kg': 51,
        'current_weight_kg': 52,
        'remaining_kg': 1,
        'achievement_rate': 75,
        'bmi': 19.1,
      });

      expect(goal.heightCm, 165);
      expect(goal.targetWeightKg, 51);
      expect(goal.currentWeightKg, 52);
      expect(goal.remainingKg, 1);
      expect(goal.achievementRate, 75);
      expect(goal.bmi, 19.1);
      expect(goal.isProfileSet, isTrue);
    });

    test('tolerates every field being null', () {
      final goal = WeightGoal.fromJson({
        'height_cm': null,
        'target_weight_kg': null,
        'current_weight_kg': null,
        'remaining_kg': null,
        'achievement_rate': null,
        'bmi': null,
      });

      expect(goal.heightCm, isNull);
      expect(goal.targetWeightKg, isNull);
      expect(goal.currentWeightKg, isNull);
      expect(goal.remainingKg, isNull);
      expect(goal.achievementRate, isNull);
      expect(goal.bmi, isNull);
      // Neither height nor target set → not a "set" profile.
      expect(goal.isProfileSet, isFalse);
    });

    test('a set target alone counts as a set profile', () {
      final goal = WeightGoal.fromJson({'target_weight_kg': 51});
      expect(goal.isProfileSet, isTrue);
    });
  });

  group('BodyProfile.fromJson', () {
    test('parses snake_case fields and reports isSet', () {
      final profile = BodyProfile.fromJson({
        'height_cm': 165,
        'target_weight_kg': 51,
      });

      expect(profile.heightCm, 165);
      expect(profile.targetWeightKg, 51);
      expect(profile.isSet, isTrue);
    });

    test('both null → not set', () {
      final profile = BodyProfile.fromJson({
        'height_cm': null,
        'target_weight_kg': null,
      });

      expect(profile.isSet, isFalse);
    });
  });
}
