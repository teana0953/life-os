import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';
import '../domain/shared_food_item_patch.dart';

/// Use case: partially edit an existing shared dictionary item.
class UpdateSharedFoodItem {
  final FoodDictionaryRepository _repository;

  UpdateSharedFoodItem(this._repository);

  Future<FoodItem> call(String idToken, String id, SharedFoodItemPatch patch) {
    return _repository.updateSharedItem(idToken, id, patch);
  }
}
