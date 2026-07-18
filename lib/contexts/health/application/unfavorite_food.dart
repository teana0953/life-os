import '../domain/food_dictionary_repository.dart';

/// Use case: unmark a dictionary item as a favorite.
class UnfavoriteFood {
  final FoodDictionaryRepository _repository;

  UnfavoriteFood(this._repository);

  Future<void> call(String idToken, String foodItemId) {
    return _repository.unfavorite(idToken, foodItemId);
  }
}
