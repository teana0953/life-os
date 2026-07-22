/// The user's editable body profile (from `GET`/`PUT /api/body-profile`): the
/// [heightCm] and [targetWeightKg] the user has set. Both are independently
/// `null` until set.
class BodyProfile {
  final double? heightCm;
  final double? targetWeightKg;

  const BodyProfile({this.heightCm, this.targetWeightKg});

  /// Whether either the height or the target weight has been set.
  bool get isSet => heightCm != null || targetWeightKg != null;

  factory BodyProfile.fromJson(Map<String, dynamic> json) => BodyProfile(
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
  );
}

/// The weight-goal overview (from `GET /api/weight-goal`): the set
/// [heightCm]/[targetWeightKg], the [currentWeightKg] (from the latest vitals
/// weight), the [remainingKg] to target, the [achievementRate] (a whole
/// percentage), and the [bmi]. Every field is independently `null` until there
/// is enough data to derive it.
class WeightGoal {
  final double? heightCm;
  final double? targetWeightKg;
  final double? currentWeightKg;
  final double? remainingKg;
  final int? achievementRate;
  final double? bmi;

  const WeightGoal({
    this.heightCm,
    this.targetWeightKg,
    this.currentWeightKg,
    this.remainingKg,
    this.achievementRate,
    this.bmi,
  });

  /// Whether either the height or the target weight has been set — the card
  /// shows the goal figures when this is true and a "set your goal" prompt when
  /// it is false.
  bool get isProfileSet => heightCm != null || targetWeightKg != null;

  factory WeightGoal.fromJson(Map<String, dynamic> json) => WeightGoal(
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
    currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble(),
    remainingKg: (json['remaining_kg'] as num?)?.toDouble(),
    achievementRate: (json['achievement_rate'] as num?)?.toInt(),
    bmi: (json['bmi'] as num?)?.toDouble(),
  );
}
