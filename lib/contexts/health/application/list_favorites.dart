import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';

class ListFavorites {
  final FoodDictionaryRepository _repository;

  ListFavorites(this._repository);

  Future<List<FoodItem>> call(String idToken) {
    return _repository.listFavorites(idToken);
  }
}
