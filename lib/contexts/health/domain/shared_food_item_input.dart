/// Input to create a new shared dictionary item (`POST
/// /api/admin/food-items`) — every field the backend accepts, all required.
class SharedFoodItemInput {
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
  final double? baseAmount;
  final String? measureUnit;

  const SharedFoodItemInput({
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
    required this.baseAmount,
    required this.measureUnit,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'carb_g': carbG,
    'protein_g': proteinG,
    'fat_g': fatG,
    'sugar_g': sugarG,
    'fiber_g': fiberG,
    'kcal': kcal,
    'staple': staple,
    'meat': meat,
    'fruit': fruit,
    'veg': veg,
    'base_amount': baseAmount,
    'measure_unit': measureUnit,
  };
}
