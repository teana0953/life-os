/// A dictionary food item, as returned by the backend `/api/food-items`
/// endpoints.
class FoodItem {
  final String id;
  final String? ownerUserId;
  final String name;
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sugarG;
  final double fiberG;
  final double kcal;
  final double staple;
  final double meat;
  final double fruit;
  final double veg;

  /// Gram weight of one dictionary unit; `null` when the unit has no
  /// defined gram weight (grams entry is unavailable for this item).
  final double? baseGrams;

  const FoodItem({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sugarG,
    required this.fiberG,
    required this.kcal,
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
    required this.baseGrams,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String?,
      name: json['name'] as String,
      carbG: (json['carb_g'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      sugarG: (json['sugar_g'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
      staple: (json['staple'] as num).toDouble(),
      meat: (json['meat'] as num).toDouble(),
      fruit: (json['fruit'] as num).toDouble(),
      veg: (json['veg'] as num).toDouble(),
      baseGrams: (json['base_grams'] as num?)?.toDouble(),
    );
  }
}
