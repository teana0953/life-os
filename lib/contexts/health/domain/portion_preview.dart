import 'food_item.dart';
import 'portions.dart';

/// Pure client-side mirror of the backend's portion-scaling formula (D2 in
/// design.md): used for the quantity card's live preview only — the saved
/// entry's authoritative values always come from the backend response.
Portions previewPortionsForQuantity(FoodItem item, double quantity) {
  return Portions(
    staple: item.staple * quantity,
    meat: item.meat * quantity,
    fruit: item.fruit * quantity,
    veg: item.veg * quantity,
  );
}

/// Converts a measure amount (in the item's `measureUnit`) to a quantity via
/// the item's base amount. Returns `null` when the item has no base amount,
/// or when either input is not a positive number — mirrors the backend's
/// `measureToQuantity`/`NullBaseMeasureError` guards.
double? quantityFromMeasure(double measure, double? baseAmount) {
  if (baseAmount == null || baseAmount <= 0) return null;
  if (measure <= 0) return null;
  return measure / baseAmount;
}
