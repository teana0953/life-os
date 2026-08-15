import '../domain/food_dictionary_repository.dart';

class FavoriteFood {
  final FoodDictionaryRepository _repository;

  FavoriteFood(this._repository);

  Future<void> call(String idToken, String foodItemId) {
    return _repository.favorite(idToken, foodItemId);
  }
}
