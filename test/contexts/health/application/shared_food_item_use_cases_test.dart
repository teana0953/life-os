import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/create_shared_food_item.dart';
import 'package:life_os/contexts/health/application/update_shared_food_item.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';

FoodItem _riceItem() => const FoodItem(
  id: 'rice-1',
  ownerUserId: null,
  name: '飯/1碗',
  carbG: 60,
  proteinG: 4,
  fatG: 0.5,
  sugarG: 0,
  fiberG: 1,
  kcal: 280,
  staple: 4,
  meat: 0,
  fruit: 0,
  veg: 0,
  baseAmount: null,
  measureUnit: null,
);

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  String? createdIdToken;
  SharedFoodItemInput? createdInput;

  String? updatedIdToken;
  String? updatedId;
  SharedFoodItemPatch? updatedPatch;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}

  @override
  Future<FoodItem> createSharedItem(
    String idToken,
    SharedFoodItemInput input,
  ) async {
    createdIdToken = idToken;
    createdInput = input;
    return _riceItem();
  }

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) async {
    updatedIdToken = idToken;
    updatedId = id;
    updatedPatch = patch;
    return _riceItem();
  }
}

void main() {
  group('CreateSharedFoodItem', () {
    test('creates the item via the repository', () async {
      final repository = FakeFoodDictionaryRepository();
      final createSharedFoodItem = CreateSharedFoodItem(repository);
      const input = SharedFoodItemInput(
        name: '飯/1碗',
        carbG: 60,
        proteinG: 4,
        fatG: 0.5,
        sugarG: 0,
        fiberG: 1,
        kcal: 280,
        staple: 4,
        meat: 0,
        fruit: 0,
        veg: 0,
        baseAmount: null,
        measureUnit: null,
      );

      final result = await createSharedFoodItem('token-123', input);

      expect(repository.createdIdToken, 'token-123');
      expect(repository.createdInput, same(input));
      expect(result.id, 'rice-1');
    });
  });

  group('UpdateSharedFoodItem', () {
    test('updates the item via the repository', () async {
      final repository = FakeFoodDictionaryRepository();
      final updateSharedFoodItem = UpdateSharedFoodItem(repository);
      const patch = SharedFoodItemPatch(name: 'New name');

      final result = await updateSharedFoodItem('token-123', 'rice-1', patch);

      expect(repository.updatedIdToken, 'token-123');
      expect(repository.updatedId, 'rice-1');
      expect(repository.updatedPatch, same(patch));
      expect(result.id, 'rice-1');
    });
  });
}
