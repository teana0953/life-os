import 'food_item.dart';
import 'shared_food_item_input.dart';
import 'shared_food_item_patch.dart';

/// Port for searching/favoriting the food dictionary, and (for
/// administrators) creating/editing shared items.
abstract class FoodDictionaryRepository {
  Future<List<FoodItem>> search(String idToken, String query);
  Future<List<FoodItem>> listFavorites(String idToken);
  Future<void> favorite(String idToken, String foodItemId);
  Future<void> unfavorite(String idToken, String foodItemId);

  /// Creates a shared dictionary item (`owner_user_id = null`). Throws
  /// [DietForbidden] when the caller is not an administrator.
  Future<FoodItem> createSharedItem(String idToken, SharedFoodItemInput input);

  /// Partially edits an existing shared item — only the fields set on
  /// [patch] are sent. Throws [DietForbidden] when the caller is not an
  /// administrator, [DietNotFound] when the id doesn't exist or isn't a
  /// shared item.
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  );
}
