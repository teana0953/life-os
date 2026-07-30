import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  String? favoritedIdToken;
  String? favoritedItemId;
  String? unfavoritedIdToken;
  String? unfavoritedItemId;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {
    favoritedIdToken = idToken;
    favoritedItemId = foodItemId;
  }

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {
    unfavoritedIdToken = idToken;
    unfavoritedItemId = foodItemId;
  }

  @override
  Future<FoodItem> createSharedItem(String idToken, SharedFoodItemInput input) =>
      throw UnimplementedError();

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) => throw UnimplementedError();
}

void main() {
  group('FavoriteFood', () {
    test('favorites the item via the repository', () async {
      final repository = FakeFoodDictionaryRepository();
      final favoriteFood = FavoriteFood(repository);

      await favoriteFood('token-123', 'item-1');

      expect(repository.favoritedIdToken, 'token-123');
      expect(repository.favoritedItemId, 'item-1');
    });
  });

  group('UnfavoriteFood', () {
    test('unfavorites the item via the repository', () async {
      final repository = FakeFoodDictionaryRepository();
      final unfavoriteFood = UnfavoriteFood(repository);

      await unfavoriteFood('token-123', 'item-1');

      expect(repository.unfavoritedIdToken, 'token-123');
      expect(repository.unfavoritedItemId, 'item-1');
    });
  });
}
