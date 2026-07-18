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

/// Converts a gram amount to a quantity via the item's base grams. Returns
/// `null` when the item has no base grams, or when either input is not a
/// positive number — mirrors the backend's `gramsToQuantity`/
/// `NullBaseGramsError` guards.
double? quantityFromGrams(double grams, double? baseGrams) {
  if (baseGrams == null || baseGrams <= 0) return null;
  if (grams <= 0) return null;
  return grams / baseGrams;
}
