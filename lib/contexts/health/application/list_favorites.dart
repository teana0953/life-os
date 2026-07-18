import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';

/// Use case: list the caller's favorite dictionary items.
class ListFavorites {
  final FoodDictionaryRepository _repository;

  ListFavorites(this._repository);

  Future<List<FoodItem>> call(String idToken) {
    return _repository.listFavorites(idToken);
  }
}
