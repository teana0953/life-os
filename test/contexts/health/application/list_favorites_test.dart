import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> favoritesToReturn = [];
  String? receivedIdToken;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async {
    receivedIdToken = idToken;
    return favoritesToReturn;
  }

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
}

FoodItem _riceItem() => FoodItem.fromJson({
  'id': 'rice-1',
  'owner_user_id': null,
  'name': '飯/1碗',
  'carb_g': 60,
  'protein_g': 4,
  'fat_g': 0.5,
  'sugar_g': 0,
  'fiber_g': 1,
  'kcal': 280,
  'staple': 4,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'base_grams': null,
});

void main() {
  group('ListFavorites', () {
    test('returns the favorite items via the repository', () async {
      final repository = FakeFoodDictionaryRepository()
        ..favoritesToReturn = [_riceItem()];
      final listFavorites = ListFavorites(repository);

      final results = await listFavorites('token-123');

      expect(results.single.name, '飯/1碗');
      expect(repository.receivedIdToken, 'token-123');
    });
  });
}
