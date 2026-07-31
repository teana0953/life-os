import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';
import '../domain/shared_food_item_input.dart';

/// Use case: create a shared (admin-owned, everyone-visible) dictionary
/// item.
class CreateSharedFoodItem {
  final FoodDictionaryRepository _repository;

  CreateSharedFoodItem(this._repository);

  Future<FoodItem> call(String idToken, SharedFoodItemInput input) {
    return _repository.createSharedItem(idToken, input);
  }
}
