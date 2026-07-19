import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';

class FakeDietLogRepository implements DietLogRepository {
  FoodEntry? entryToReturn;
  Object? errorToThrow;
  double? receivedQuantity;
  double? receivedGrams;
  String? receivedMeal;

  @override
  Future<FoodEntry> logFromDictionary(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    receivedQuantity = quantity;
    receivedGrams = grams;
    receivedMeal = meal;
    return entryToReturn!;
  }

  @override
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}

  @override
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

FoodItem _riceBowl() => FoodItem.fromJson({
  'id': 'rice-bowl',
  'owner_user_id': null,
  'name': '飯/1碗',
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

FoodItem _rice50g() => FoodItem.fromJson({
  'id': 'rice-50g',
  'owner_user_id': null,
  'name': '飯/50g',
  'carb_g': 15,
  'protein_g': 1,
  'fat_g': 0.1,
  'sugar_g': 0,
  'fiber_g': 0.2,
  'kcal': 70,
  'staple': 1,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'base_grams': 50,
});

FoodEntry _fakeEntry() => FoodEntry.fromJson({
  'id': 'entry-1',
  'day': '2026-07-18',
  'meal': 'lunch',
  'name': '飯/1碗',
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 90,
  'protein_g': 6,
  'fat_g': 0.75,
  'sugar_g': 0,
  'fiber_g': 1.5,
  'kcal': 420,
  'staple': 6,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'eaten_at': '2026-07-18T12:30:00.000Z',
  'logged_at': '2026-07-18T12:31:00.000Z',
});

void main() {
  group('LogEntryController.start', () {
    test('resets state and defaults eaten-at to the injected clock', () {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      final now = DateTime.utc(2026, 7, 18, 9);

      controller.start(_riceBowl(), clock: () => now);

      expect(controller.item?.id, 'rice-bowl');
      expect(controller.meal, 'breakfast');
      expect(controller.useGrams, isFalse);
      expect(controller.quantity, 1);
      expect(controller.eatenAt, now);
    });
  });

  group('LogEntryController preview', () {
    test('scales portions by quantity — 飯/1碗 x1.5 -> 6 staple', () {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));

      controller.setQuantity(1.5);

      expect(controller.preview?.staple, 6);
    });

    test('previews via grams when useGrams is set — 33g of 飯/50g -> ~0.66', () {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_rice50g(), clock: () => DateTime.utc(2026, 7, 18));

      controller.setUseGrams(true);
      controller.setGrams(33);

      expect(controller.preview?.staple, closeTo(0.66, 0.001));
    });

    test('preview is null when grams entered but item has no base grams', () {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));

      controller.setUseGrams(true);
      controller.setGrams(33);

      expect(controller.preview, isNull);
    });
  });

  group('LogEntryController.save', () {
    test('saves by quantity and reports success', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final controller = LogEntryController(LogFoodFromDictionary(repository));
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      controller.setQuantity(1.5);

      final result = await controller.save('token-123', '2026-07-18');

      expect(result, isTrue);
      expect(controller.status, LogEntryStatus.saved);
      expect(repository.receivedQuantity, 1.5);
      expect(repository.receivedGrams, isNull);
    });

    test('saves by grams when useGrams is set', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final controller = LogEntryController(LogFoodFromDictionary(repository));
      controller.start(_rice50g(), clock: () => DateTime.utc(2026, 7, 18));
      controller.setUseGrams(true);
      controller.setGrams(33);

      await controller.save('token-123', '2026-07-18');

      expect(repository.receivedGrams, 33);
      expect(repository.receivedQuantity, isNull);
    });

    test('uses the custom snack label as the meal when snack is chosen', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final controller = LogEntryController(LogFoodFromDictionary(repository));
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      controller.setMeal('snack');
      controller.setSnackLabel('午後點心');

      await controller.save('token-123', '2026-07-18');

      expect(repository.receivedMeal, '午後點心');
    });

    test('sets a typed error and does not throw on failure', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final controller = LogEntryController(LogFoodFromDictionary(repository));
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));

      final result = await controller.save('token-123', '2026-07-18');

      expect(result, isFalse);
      expect(controller.status, LogEntryStatus.error);
      expect(controller.error, LogEntryError.saveFailed);
    });

    test('sets reauthRequired error on DietReauthenticationRequired', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final controller = LogEntryController(LogFoodFromDictionary(repository));
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));

      await controller.save('token-123', '2026-07-18');

      expect(controller.error, LogEntryError.reauthRequired);
    });
  });
}
