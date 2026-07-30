import 'field_update.dart';

/// A partial edit to a shared dictionary item (`PATCH
/// /api/admin/food-items/:id`). Every field is optional — an absent field
/// isn't sent at all (the backend leaves it alone). `baseAmount` and
/// `measureUnit` use [FieldUpdate] because they need a third state, an
/// explicit `null` that clears the measure basis, distinct from "not
/// supplied".
class SharedFoodItemPatch {
  final String? name;
  final double? carbG;
  final double? proteinG;
  final double? fatG;
  final double? sugarG;
  final double? fiberG;
  final double? kcal;
  final double? staple;
  final double? meat;
  final double? fruit;
  final double? veg;
  final FieldUpdate<double> baseAmount;
  final FieldUpdate<String> measureUnit;

  const SharedFoodItemPatch({
    this.name,
    this.carbG,
    this.proteinG,
    this.fatG,
    this.sugarG,
    this.fiberG,
    this.kcal,
    this.staple,
    this.meat,
    this.fruit,
    this.veg,
    this.baseAmount = const FieldUpdate.unset(),
    this.measureUnit = const FieldUpdate.unset(),
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (carbG != null) json['carb_g'] = carbG;
    if (proteinG != null) json['protein_g'] = proteinG;
    if (fatG != null) json['fat_g'] = fatG;
    if (sugarG != null) json['sugar_g'] = sugarG;
    if (fiberG != null) json['fiber_g'] = fiberG;
    if (kcal != null) json['kcal'] = kcal;
    if (staple != null) json['staple'] = staple;
    if (meat != null) json['meat'] = meat;
    if (fruit != null) json['fruit'] = fruit;
    if (veg != null) json['veg'] = veg;
    if (baseAmount.isSet) json['base_amount'] = baseAmount.value;
    if (measureUnit.isSet) json['measure_unit'] = measureUnit.value;
    return json;
  }
}
