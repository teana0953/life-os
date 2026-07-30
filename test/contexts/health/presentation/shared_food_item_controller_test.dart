import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/create_shared_food_item.dart';
import 'package:life_os/contexts/health/application/update_shared_food_item.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
import 'package:life_os/contexts/health/presentation/shared_food_item_controller.dart';

FoodItem _riceItem() => const FoodItem(
  id: 'rice-1',
  ownerUserId: null,
  name: '飯/1碗',
  carbG: 60,
  proteinG: 4,
  fatG: 0.5,
  sugarG: 0,
  fiberG: 1,
  kcal: 280,
  staple: 4,
  meat: 0,
  fruit: 0,
  veg: 0,
  baseAmount: null,
  measureUnit: null,
);

const _input = SharedFoodItemInput(
  name: '飯/1碗',
  carbG: 60,
  proteinG: 4,
  fatG: 0.5,
  sugarG: 0,
  fiberG: 1,
  kcal: 280,
  staple: 4,
  meat: 0,
  fruit: 0,
  veg: 0,
  baseAmount: null,
  measureUnit: null,
);

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  Object? errorToThrow;
  Completer<FoodItem>? gate;
  int createCallCount = 0;
  int updateCallCount = 0;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}

  @override
  Future<FoodItem> createSharedItem(
    String idToken,
    SharedFoodItemInput input,
  ) async {
    createCallCount++;
    if (gate != null) return gate!.future;
    if (errorToThrow != null) throw errorToThrow!;
    return _riceItem();
  }

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) async {
    updateCallCount++;
    if (gate != null) return gate!.future;
    if (errorToThrow != null) throw errorToThrow!;
    return _riceItem();
  }
}

void main() {
  group('SharedFoodItemController.create', () {
    test('succeeds and returns the created item', () async {
      final repository = FakeFoodDictionaryRepository();
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );

      final result = await controller.create('token', _input);

      expect(result?.id, 'rice-1');
      expect(controller.status, SharedFoodItemControllerStatus.idle);
      expect(controller.error, isNull);
    });

    test('sets a typed generic error on failure and returns null', () async {
      final repository = FakeFoodDictionaryRepository()
        ..errorToThrow = const DietFetchFailure('failed');
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );

      final result = await controller.create('token', _input);

      expect(result, isNull);
      expect(controller.error, SharedFoodItemError.saveFailed);
      expect(controller.status, SharedFoodItemControllerStatus.idle);
    });

    test('sets a typed forbidden error, distinct from a generic failure', () async {
      final repository = FakeFoodDictionaryRepository()
        ..errorToThrow = const DietForbidden();
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );

      final result = await controller.create('token', _input);

      expect(result, isNull);
      expect(controller.error, SharedFoodItemError.forbidden);
    });

    test('a second submit while one is in flight does not fire twice', () async {
      final repository = FakeFoodDictionaryRepository()..gate = Completer<FoodItem>();
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );

      final first = controller.create('token', _input);
      final second = controller.create('token', _input);
      repository.gate!.complete(_riceItem());
      await Future.wait(<Future<FoodItem?>>[first, second]);

      expect(repository.createCallCount, 1);
    });
  });

  group('SharedFoodItemController.update', () {
    test('succeeds and returns the updated item', () async {
      final repository = FakeFoodDictionaryRepository();
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );

      final result = await controller.update(
        'token',
        'rice-1',
        const SharedFoodItemPatch(name: 'New name'),
      );

      expect(result?.id, 'rice-1');
      expect(controller.error, isNull);
    });

    test('a second submit while one is in flight does not fire twice', () async {
      final repository = FakeFoodDictionaryRepository()..gate = Completer<FoodItem>();
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );

      final first = controller.update('token', 'rice-1', const SharedFoodItemPatch(name: 'a'));
      final second = controller.update('token', 'rice-1', const SharedFoodItemPatch(name: 'b'));
      repository.gate!.complete(_riceItem());
      await Future.wait<FoodItem?>([first, second]);

      expect(repository.updateCallCount, 1);
    });
  });
}
