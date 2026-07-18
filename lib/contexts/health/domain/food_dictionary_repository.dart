import 'food_item.dart';

/// Port for searching/favoriting the food dictionary.
abstract class FoodDictionaryRepository {
  Future<List<FoodItem>> search(String idToken, String query);
  Future<List<FoodItem>> listFavorites(String idToken);
  Future<void> favorite(String idToken, String foodItemId);
  Future<void> unfavorite(String idToken, String foodItemId);
}
