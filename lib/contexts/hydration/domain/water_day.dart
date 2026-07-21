/// A day's water intake in millilitres against its target, as returned by
/// `GET /api/water?day=`. [remainingMl] can be negative when the intake has
/// gone past the target (over-target).
class WaterDay {
  final String day;
  final int totalMl;
  final int targetMl;
  final int remainingMl;

  const WaterDay({
    required this.day,
    required this.totalMl,
    required this.targetMl,
    required this.remainingMl,
  });

  factory WaterDay.fromJson(Map<String, dynamic> json) {
    return WaterDay(
      day: json['day'] as String,
      totalMl: (json['total_ml'] as num).toInt(),
      targetMl: (json['target_ml'] as num).toInt(),
      remainingMl: (json['remaining_ml'] as num).toInt(),
    );
  }
}
