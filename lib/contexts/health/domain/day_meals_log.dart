import 'meal_entry.dart';
import 'portions.dart';

/// A day's meals, as returned by `GET /api/meals?day=`. `totals` is a
/// [Portions] built directly from the flat snake_case `totals` object's four
/// portion keys — that same object also carries the day's nutrient keys
/// (`carb_g`/`protein_g`/`fat_g`/`sugar_g`/`fiber_g`/`kcal`), but Today
/// renders only portion progress, so those are not read this PR (no separate
/// totals type).
class DayMealsLog {
  final String day;
  final List<MealEntry> meals;
  final Portions totals;

  const DayMealsLog({
    required this.day,
    required this.meals,
    required this.totals,
  });

  factory DayMealsLog.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>;
    return DayMealsLog(
      day: json['day'] as String,
      meals: (json['meals'] as List)
          .map((m) => MealEntry.fromJson(m as Map<String, dynamic>))
          .toList(),
      totals: Portions(
        staple: (totals['staple'] as num).toDouble(),
        meat: (totals['meat'] as num).toDouble(),
        fruit: (totals['fruit'] as num).toDouble(),
        veg: (totals['veg'] as num).toDouble(),
      ),
    );
  }
}
