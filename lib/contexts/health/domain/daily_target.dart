import 'portions.dart';

/// A day's effective per-category portion target (base + bonus) and the
/// remaining portions against what has been logged, as returned by
/// `GET /api/daily-target?day=`.
class DailyTargetWithRemaining {
  final String day;
  final Portions base;
  final Portions bonus;
  final Portions effective;
  final Portions logged;
  final Portions remaining;

  const DailyTargetWithRemaining({
    required this.day,
    required this.base,
    required this.bonus,
    required this.effective,
    required this.logged,
    required this.remaining,
  });

  factory DailyTargetWithRemaining.fromJson(Map<String, dynamic> json) {
    return DailyTargetWithRemaining(
      day: json['day'] as String,
      base: Portions.fromJson(json['base'] as Map<String, dynamic>),
      bonus: Portions.fromJson(json['bonus'] as Map<String, dynamic>),
      effective: Portions.fromJson(json['effective'] as Map<String, dynamic>),
      logged: Portions.fromJson(json['logged'] as Map<String, dynamic>),
      remaining: Portions.fromJson(json['remaining'] as Map<String, dynamic>),
    );
  }
}

/// A day's base/bonus portion goals, as returned by `PUT /api/daily-target`.
class DailyTarget {
  final String id;
  final String day;
  final double baseStaple;
  final double baseMeat;
  final double baseFruit;
  final double baseVeg;
  final double bonusStaple;
  final double bonusMeat;
  final double bonusFruit;
  final double bonusVeg;

  const DailyTarget({
    required this.id,
    required this.day,
    required this.baseStaple,
    required this.baseMeat,
    required this.baseFruit,
    required this.baseVeg,
    required this.bonusStaple,
    required this.bonusMeat,
    required this.bonusFruit,
    required this.bonusVeg,
  });

  factory DailyTarget.fromJson(Map<String, dynamic> json) {
    return DailyTarget(
      id: json['id'] as String,
      day: json['day'] as String,
      baseStaple: (json['base_staple'] as num).toDouble(),
      baseMeat: (json['base_meat'] as num).toDouble(),
      baseFruit: (json['base_fruit'] as num).toDouble(),
      baseVeg: (json['base_veg'] as num).toDouble(),
      bonusStaple: (json['bonus_staple'] as num).toDouble(),
      bonusMeat: (json['bonus_meat'] as num).toDouble(),
      bonusFruit: (json['bonus_fruit'] as num).toDouble(),
      bonusVeg: (json['bonus_veg'] as num).toDouble(),
    );
  }
}
