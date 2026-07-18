import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> favoritesToReturn = [];
  List<FoodItem> searchResultsToReturn = [];
  Object? loadErrorToThrow;
  Object? searchErrorToThrow;
  Object? toggleErrorToThrow;
  String? favoritedId;
  String? unfavoritedId;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async {
    if (searchErrorToThrow != null) throw searchErrorToThrow!;
    return searchResultsToReturn;
  }

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async {
    if (loadErrorToThrow != null) throw loadErrorToThrow!;
    return favoritesToReturn;
  }

  @override
  Future<void> favorite(String idToken, String foodItemId) async {
    if (toggleErrorToThrow != null) throw toggleErrorToThrow!;
    favoritedId = foodItemId;
  }

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {
    if (toggleErrorToThrow != null) throw toggleErrorToThrow!;
    unfavoritedId = foodItemId;
  }
}

FoodItem _item(String id, String name) => FoodItem.fromJson({
  'id': id,
  'owner_user_id': null,
  'name': name,
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

DictionaryController _controller(FakeFoodDictionaryRepository repository) {
  return DictionaryController(
    SearchDictionary(repository),
    ListFavorites(repository),
    FavoriteFood(repository),
    UnfavoriteFood(repository),
  );
}

void main() {
  group('DictionaryController.load', () {
    test('loads favorites', () async {
      final repository = FakeFoodDictionaryRepository()
        ..favoritesToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);

      await controller.load('token-123');

      expect(controller.status, DictionaryStatus.loaded);
      expect(controller.favorites.single.name, '飯/1碗');
    });

    test('sets error status on DietFetchFailure', () async {
      final repository = FakeFoodDictionaryRepository()
        ..loadErrorToThrow = const DietFetchFailure('server error');
      final controller = _controller(repository);

      await controller.load('token-123');

      expect(controller.status, DictionaryStatus.error);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final repository = FakeFoodDictionaryRepository()
        ..loadErrorToThrow = const DietReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token-123');

      expect(controller.status, DictionaryStatus.needsReauth);
    });
  });

  group('DictionaryController.search', () {
    test('populates results, and clears them for an empty query', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchResultsToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.search('飯');
      expect(controller.results.single.name, '飯/1碗');

      await controller.search('');
      expect(controller.results, isEmpty);
    });

    test('a successful empty response shows no results without an error', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchResultsToReturn = [];
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.search('no-matches');

      expect(controller.results, isEmpty);
      expect(controller.status, DictionaryStatus.loaded);
      expect(controller.error, isNull);
    });

    test('sets error status on DietFetchFailure, distinct from no results', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchErrorToThrow = const DietFetchFailure('server error');
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.search('飯');

      expect(controller.status, DictionaryStatus.error);
      expect(controller.error, DictionaryError.fetchFailed);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchErrorToThrow = const DietReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.search('飯');

      expect(controller.status, DictionaryStatus.needsReauth);
    });
  });

  group('DictionaryController.toggleFavorite', () {
    test('favorites an unfavorited item and refreshes favorites', () async {
      final repository = FakeFoodDictionaryRepository();
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: false);

      expect(repository.favoritedId, 'rice-1');
    });

    test('unfavorites a favorited item', () async {
      final repository = FakeFoodDictionaryRepository();
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: true);

      expect(repository.unfavoritedId, 'rice-1');
    });

    test('sets error status on DietFetchFailure without crashing', () async {
      final repository = FakeFoodDictionaryRepository()
        ..toggleErrorToThrow = const DietFetchFailure('server error');
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: false);

      expect(controller.status, DictionaryStatus.error);
      expect(controller.error, DictionaryError.fetchFailed);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final repository = FakeFoodDictionaryRepository()
        ..toggleErrorToThrow = const DietReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load('token-123');

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: false);

      expect(controller.status, DictionaryStatus.needsReauth);
    });
  });
}
