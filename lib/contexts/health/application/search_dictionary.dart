import '../domain/food_dictionary_repository.dart';
import '../domain/food_item.dart';

class SearchDictionary {
  final FoodDictionaryRepository _repository;

  SearchDictionary(this._repository);

  Future<List<FoodItem>> call(String idToken, String query) {
    return _repository.search(idToken, query);
  }
}
