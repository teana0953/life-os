import '../domain/food_dictionary_repository.dart';

class UnfavoriteFood {
  final FoodDictionaryRepository _repository;

  UnfavoriteFood(this._repository);

  Future<void> call(String idToken, String foodItemId) {
    return _repository.unfavorite(idToken, foodItemId);
  }
}
