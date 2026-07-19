import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/delete_entry.dart';
import 'package:life_os/contexts/health/application/update_food_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart' show snackMealValue;

class FakeDietLogRepository implements DietLogRepository {
  Object? errorToThrow;
  FoodEntry? entryToReturn;

  String? receivedEntryId;
  String? receivedName;
  String? receivedMeal;
  DateTime? receivedEatenAt;
  Portions? receivedPortions;
  bool eatenAtWasPassed = false;

  String? deletedEntryId;

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
    throw UnimplementedError();
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
  Future<void> deleteEntry(String idToken, String entryId) async {
    if (errorToThrow != null) throw errorToThrow!;
    deletedEntryId = entryId;
  }

  @override
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    receivedEntryId = entryId;
    receivedName = name;
    receivedMeal = meal;
    receivedEatenAt = eatenAt;
    eatenAtWasPassed = true;
    receivedPortions = portions;
    return entryToReturn!;
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

FoodEntry _entry({
  String id = 'entry-1',
  String meal = 'lunch',
  String? name = '雞腿便當',
  double staple = 3,
  double meat = 3,
  double fruit = 0,
  double veg = 0,
  String eatenAt = '2026-07-18T12:30:00.000Z',
}) => FoodEntry.fromJson({
  'id': id,
  'day': '2026-07-18',
  'meal': meal,
  'name': name,
  'photo_ref': null,
  'source': 'manual',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': staple,
  'meat': meat,
  'fruit': fruit,
  'veg': veg,
  'eaten_at': eatenAt,
  'logged_at': eatenAt,
});

void main() {
  group('EditEntryController.start', () {
    test('seeds name/portions/meal/eatenAt from the entry', () {
      final repository = FakeDietLogRepository();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );

      controller.start(_entry());

      expect(controller.name, '雞腿便當');
      expect(controller.staple, 3);
      expect(controller.meat, 3);
      expect(controller.fruit, 0);
      expect(controller.veg, 0);
      expect(controller.meal, 'lunch');
      expect(controller.snackLabel, '');
      expect(controller.eatenAt, DateTime.utc(2026, 7, 18, 12, 30));
      expect(controller.status, EditEntryStatus.idle);
    });

    test('a custom (snack) meal round-trips as snackMealValue + snackLabel', () {
      final repository = FakeDietLogRepository();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );

      controller.start(_entry(meal: '午後點心'));

      expect(controller.meal, snackMealValue);
      expect(controller.snackLabel, '午後點心');
    });
  });

  group('EditEntryController.save', () {
    test(
      'a portions-only edit (time untouched) omits eaten_at so the day is not moved',
      () async {
        final repository = FakeDietLogRepository()..entryToReturn = _entry();
        final controller = EditEntryController(
          UpdateFoodEntry(repository),
          DeleteEntry(repository),
        );
        controller.start(_entry());

        controller.setPortion('staple', 4);
        final result = await controller.save('token-123');

        expect(result, isTrue);
        expect(repository.eatenAtWasPassed, isTrue);
        expect(repository.receivedEatenAt, isNull);
        expect(repository.receivedPortions?.staple, 4);
      },
    );

    test('sends eaten_at only when the user changed the time', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      controller.setEatenAt(DateTime.utc(2026, 7, 18, 8, 0));
      await controller.save('token-123');

      expect(repository.receivedEatenAt, DateTime.utc(2026, 7, 18, 8, 0));
    });

    test('sends the entry id, name, meal, and portions', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      controller.setName('新名字');
      controller.setMeal('dinner');
      final result = await controller.save('token-123');

      expect(result, isTrue);
      expect(controller.status, EditEntryStatus.saved);
      expect(repository.receivedEntryId, 'entry-1');
      expect(repository.receivedName, '新名字');
      expect(repository.receivedMeal, 'dinner');
    });

    test('uses the custom snack label as the meal when snack is chosen', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      controller.setMeal(snackMealValue);
      controller.setSnackLabel('晚間點心');
      await controller.save('token-123');

      expect(repository.receivedMeal, '晚間點心');
    });

    test('an empty name is sent as null (blanking keeps the original name)', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      controller.setName('');
      await controller.save('token-123');

      expect(repository.receivedName, isNull);
    });

    test('sets a typed error and does not throw on failure', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      final result = await controller.save('token-123');

      expect(result, isFalse);
      expect(controller.status, EditEntryStatus.error);
      expect(controller.error, EditEntryError.saveFailed);
    });

    test('sets reauthRequired error on DietReauthenticationRequired', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      await controller.save('token-123');

      expect(controller.error, EditEntryError.reauthRequired);
    });
  });

  group('EditEntryController.delete', () {
    test('deletes the started entry and reports success', () async {
      final repository = FakeDietLogRepository();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      final result = await controller.delete('token-123');

      expect(result, isTrue);
      expect(controller.status, EditEntryStatus.deleted);
      expect(repository.deletedEntryId, 'entry-1');
    });

    test('sets a typed error and does not throw on failure', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      final result = await controller.delete('token-123');

      expect(result, isFalse);
      expect(controller.status, EditEntryStatus.error);
      expect(controller.error, EditEntryError.saveFailed);
    });

    test('sets reauthRequired error on DietReauthenticationRequired', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());

      await controller.delete('token-123');

      expect(controller.error, EditEntryError.reauthRequired);
    });
  });
}
