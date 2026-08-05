import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> favoritesToReturn = [];
  List<FoodItem> searchResultsToReturn = [];
  Object? loadErrorToThrow;
  Object? searchErrorToThrow;
  Object? toggleErrorToThrow;
  String? favoritedId;
  String? unfavoritedId;

  /// Every id token [search] was called with, in order — the *value that was
  /// sent*, which is what the token-freshness test asserts on.
  final List<String> searchTokens = [];

  /// Every id token [favorite] was called with, in order.
  final List<String> favoriteTokens = [];

  @override
  Future<List<FoodItem>> search(String idToken, String query) async {
    searchTokens.add(idToken);
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
    favoriteTokens.add(idToken);
    if (toggleErrorToThrow != null) throw toggleErrorToThrow!;
    favoritedId = foodItemId;
  }

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {
    if (toggleErrorToThrow != null) throw toggleErrorToThrow!;
    unfavoritedId = foodItemId;
  }

  @override
  Future<FoodItem> createSharedItem(String idToken, SharedFoodItemInput input) =>
      throw UnimplementedError();

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) => throw UnimplementedError();
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
  'base_amount': null,
  'measure_unit': null,
});

class _CountingFoodDictionaryRepository extends FakeFoodDictionaryRepository {
  int searchCallCount = 0;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async {
    searchCallCount++;
    return super.search(idToken, query);
  }
}

DictionaryController _controller(
  FakeFoodDictionaryRepository repository, {
  Duration searchDebounce = Duration.zero,
}) {
  return DictionaryController(
    SearchDictionary(repository),
    ListFavorites(repository),
    FavoriteFood(repository),
    UnfavoriteFood(repository),
    idToken: () async => 'token-123',
    searchDebounce: searchDebounce,
  );
}

void main() {
  // This controller is the one deliberate exception to "only presentation
  // holds the provider" (design D2): `search`/`toggleFavorite` take no token,
  // so before this change they reused whatever `load` had captured — a
  // dictionary left open past the token's one-hour life 401'd on every
  // keystroke. Asserts on the token the repository RECEIVED.
  group('DictionaryController token freshness', () {
    test('a second search carries the second token, not the first one', () async {
      final repository = FakeFoodDictionaryRepository();
      var token = 'token-1';
      final controller = DictionaryController(
        SearchDictionary(repository),
        ListFavorites(repository),
        FavoriteFood(repository),
        UnfavoriteFood(repository),
        idToken: () async => token,
      );
      await controller.load();

      await controller.search('rice');
      expect(repository.searchTokens, ['token-1']);

      // Firebase renewed the token while the dictionary stayed open.
      token = 'token-2';

      await controller.search('bread');

      expect(repository.searchTokens, ['token-1', 'token-2']);
    });

    test('toggling a favorite after a renewal carries the new token', () async {
      final repository = FakeFoodDictionaryRepository();
      var token = 'token-1';
      final controller = DictionaryController(
        SearchDictionary(repository),
        ListFavorites(repository),
        FavoriteFood(repository),
        UnfavoriteFood(repository),
        idToken: () async => token,
      );
      await controller.load();

      await controller.toggleFavorite(_item('rice-1', 'rice'), isFavorite: false);
      expect(repository.favoriteTokens, ['token-1']);

      token = 'token-2';
      await controller.toggleFavorite(_item('rice-2', 'bread'), isFavorite: false);

      expect(repository.favoriteTokens, ['token-1', 'token-2']);
    });
  });

  group('DictionaryController.load', () {
    test('loads favorites', () async {
      final repository = FakeFoodDictionaryRepository()
        ..favoritesToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);

      await controller.load();

      expect(controller.status, DictionaryStatus.loaded);
      expect(controller.favorites.single.name, '飯/1碗');
    });

    test('sets error status on DietFetchFailure', () async {
      final repository = FakeFoodDictionaryRepository()
        ..loadErrorToThrow = const DietFetchFailure('server error');
      final controller = _controller(repository);

      await controller.load();

      expect(controller.status, DictionaryStatus.error);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final repository = FakeFoodDictionaryRepository()
        ..loadErrorToThrow = const DietReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load();

      expect(controller.status, DictionaryStatus.needsReauth);
    });
  });

  group('DictionaryController.search', () {
    test('populates results, and clears them for an empty query', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchResultsToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);
      await controller.load();

      await controller.search('飯');
      expect(controller.results.single.name, '飯/1碗');

      await controller.search('');
      expect(controller.results, isEmpty);
    });

    test('clearSearch resets query and results back to favorites-only', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchResultsToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);
      await controller.load();

      await controller.search('飯');
      expect(controller.query, '飯');
      expect(controller.results, isNotEmpty);

      controller.clearSearch();

      expect(controller.query, isEmpty);
      expect(controller.results, isEmpty);
    });

    test('a successful empty response shows no results without an error', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchResultsToReturn = [];
      final controller = _controller(repository);
      await controller.load();

      await controller.search('no-matches');

      expect(controller.results, isEmpty);
      expect(controller.status, DictionaryStatus.loaded);
      expect(controller.error, isNull);
    });

    test('sets error status on DietFetchFailure, distinct from no results', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchErrorToThrow = const DietFetchFailure('server error');
      final controller = _controller(repository);
      await controller.load();

      await controller.search('飯');

      expect(controller.status, DictionaryStatus.error);
      expect(controller.error, DictionaryError.fetchFailed);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final repository = FakeFoodDictionaryRepository()
        ..searchErrorToThrow = const DietReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load();

      await controller.search('飯');

      expect(controller.status, DictionaryStatus.needsReauth);
    });

    test('debounces rapid keystrokes into a single request for the final query', () async {
      final repository = _CountingFoodDictionaryRepository()
        ..searchResultsToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(
        repository,
        searchDebounce: const Duration(milliseconds: 20),
      );
      await controller.load();

      // Rapid keystrokes: none of these should fire a request before the
      // debounce settles, and only the final query should ever be sent.
      controller.search('飯');
      controller.search('飯/');
      final last = controller.search('飯/1');

      await last;

      expect(repository.searchCallCount, 1);
      expect(controller.results.single.name, '飯/1碗');
    });

    test('dispose leaves no pending debounce timer', () async {
      final repository = _CountingFoodDictionaryRepository();
      final controller = _controller(
        repository,
        searchDebounce: const Duration(milliseconds: 20),
      );
      await controller.load();

      controller.search('飯');
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(repository.searchCallCount, 0);
    });
  });

  group('DictionaryController.toggleFavorite', () {
    test('favorites an unfavorited item and refreshes favorites', () async {
      final repository = FakeFoodDictionaryRepository();
      final controller = _controller(repository);
      await controller.load();

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: false);

      expect(repository.favoritedId, 'rice-1');
    });

    test('unfavorites a favorited item', () async {
      final repository = FakeFoodDictionaryRepository();
      final controller = _controller(repository);
      await controller.load();

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: true);

      expect(repository.unfavoritedId, 'rice-1');
    });

    // These two used to assert that a failed toggle wrote error/needsReauth
    // into the shared status. That was harmless while nothing rendered status,
    // but the search screen's results area now does — so a failed favorite
    // toggle would have replaced the list the user is looking at with
    // "couldn't load foods", and clearing the search box would not bring it
    // back. The toggle now leaves the list-loading status alone.
    test('a failed toggle leaves the loaded list alone', () async {
      final repository = FakeFoodDictionaryRepository()
        ..toggleErrorToThrow = const DietFetchFailure('server error');
      final controller = _controller(repository);
      await controller.load();
      final favoritesBefore = controller.favorites;

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: false);

      expect(controller.status, DictionaryStatus.loaded);
      expect(controller.error, isNull);
      expect(controller.favorites, favoritesBefore);
    });

    test('a toggle rejected for auth also leaves the loaded list alone', () async {
      final repository = FakeFoodDictionaryRepository()
        ..toggleErrorToThrow = const DietReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load();

      await controller.toggleFavorite(_item('rice-1', '飯/1碗'), isFavorite: false);

      expect(controller.status, DictionaryStatus.loaded);
      expect(controller.error, isNull);
    });
  });
}
