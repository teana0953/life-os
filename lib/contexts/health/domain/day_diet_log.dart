import 'food_entry.dart';

/// One meal's entries within a [DayDietLog].
class MealGroup {
  final String meal;
  final List<FoodEntry> entries;

  const MealGroup({required this.meal, required this.entries});

  factory MealGroup.fromJson(Map<String, dynamic> json) {
    return MealGroup(
      meal: json['meal'] as String,
      entries: (json['entries'] as List)
          .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Nutrient totals for a day, computed from atomic fields only (never
/// portions). Note: unlike entry fields, the backend serializes these keys
/// as camelCase (a plain JS object, not run through `entryToJson`).
class DayNutrientTotals {
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sugarG;
  final double fiberG;
  final double kcal;

  const DayNutrientTotals({
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sugarG,
    required this.fiberG,
    required this.kcal,
  });

  factory DayNutrientTotals.fromJson(Map<String, dynamic> json) {
    return DayNutrientTotals(
      carbG: (json['carbG'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      fatG: (json['fatG'] as num).toDouble(),
      sugarG: (json['sugarG'] as num).toDouble(),
      fiberG: (json['fiberG'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
    );
  }
}

/// A day's diet log, grouped by meal in eaten-at order, as returned by
/// `GET /api/diet-entries?day=`.
class DayDietLog {
  final String day;
  final List<MealGroup> meals;
  final DayNutrientTotals totals;

  const DayDietLog({
    required this.day,
    required this.meals,
    required this.totals,
  });

  factory DayDietLog.fromJson(Map<String, dynamic> json) {
    return DayDietLog(
      day: json['day'] as String,
      meals: (json['meals'] as List)
          .map((m) => MealGroup.fromJson(m as Map<String, dynamic>))
          .toList(),
      totals: DayNutrientTotals.fromJson(json['totals'] as Map<String, dynamic>),
    );
  }
}
