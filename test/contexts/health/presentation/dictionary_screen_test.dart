import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  List<FoodItem> favoritesToReturn = [];
  List<FoodItem> searchResultsToReturn = [];

  @override
  Future<List<FoodItem>> search(String idToken, String query) async =>
      searchResultsToReturn;

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => favoritesToReturn;

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
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
  group('DictionaryScreen', () {
    testWidgets('favorite appears in the favorites list', (tester) async {
      final repository = FakeFoodDictionaryRepository()
        ..favoritesToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);
      await controller.load('token-123');

      await tester.pumpWidget(
        l10nTestApp(home: DictionaryScreen(controller: controller)),
      );
      await tester.pump();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietFavoritesTitle), findsOneWidget);
      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('searching shows matching results', (tester) async {
      final repository = FakeFoodDictionaryRepository()
        ..searchResultsToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);
      await controller.load('token-123');

      await tester.pumpWidget(
        l10nTestApp(home: DictionaryScreen(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('dictionary-search-field')), '飯');
      await tester.pumpAndSettle();

      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('tapping an item calls onSelectItem', (tester) async {
      final repository = FakeFoodDictionaryRepository()
        ..favoritesToReturn = [_item('rice-1', '飯/1碗')];
      final controller = _controller(repository);
      await controller.load('token-123');
      FoodItem? selected;

      await tester.pumpWidget(
        l10nTestApp(
          home: DictionaryScreen(
            controller: controller,
            onSelectItem: (item) => selected = item,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('飯/1碗'));
      await tester.pump();

      expect(selected?.id, 'rice-1');
    });

    testWidgets(
      'shows a manual-entry affordance that calls onManualEntry when tapped',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        final controller = _controller(repository);
        await controller.load('token-123');
        var tapped = false;

        await tester.pumpWidget(
          l10nTestApp(
            home: DictionaryScreen(
              controller: controller,
              onManualEntry: () => tapped = true,
            ),
          ),
        );
        await tester.pump();

        final loc = lookupAppLocalizations(const Locale('en'));
        final affordance = find.byKey(const Key('dictionary-manual-entry-button'));
        expect(affordance, findsOneWidget);
        expect(find.text(loc.dietManualEntryAffordance), findsOneWidget);

        await tester.tap(affordance);
        await tester.pump();

        expect(tapped, isTrue);
      },
    );
  });
}
