import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart'
    show snackMealValue;
import 'package:life_os/contexts/health/presentation/manual_entry_controller.dart';

class FakeDietLogRepository implements DietLogRepository {
  FoodEntry? entryToReturn;
  Object? errorToThrow;
  String? receivedDay;
  String? receivedMeal;
  String? receivedName;
  Portions? receivedPortions;
  DateTime? receivedEatenAt;

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
    if (errorToThrow != null) throw errorToThrow!;
    receivedDay = day;
    receivedMeal = meal;
    receivedName = name;
    receivedPortions = portions;
    receivedEatenAt = eatenAt;
    return entryToReturn!;
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

FoodEntry _fakeEntry() => FoodEntry.fromJson({
  'id': 'entry-1',
  'day': '2026-07-18',
  'meal': 'lunch',
  'name': '蛋',
  'photo_ref': null,
  'source': 'manual',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': 0,
  'meat': 1,
  'fruit': 0,
  'veg': 0,
  'eaten_at': '2026-07-18T12:30:00.000Z',
  'logged_at': '2026-07-18T12:31:00.000Z',
});

void main() {
  group('ManualEntryController.start', () {
    test('resets the draft and defaults eaten-at to the injected clock', () {
      final controller = ManualEntryController(
        LogManualEntry(FakeDietLogRepository()),
      );
      final now = DateTime.utc(2026, 7, 18, 9);

      controller.start(clock: () => now);

      expect(controller.name, '');
      expect(controller.staple, 0);
      expect(controller.meat, 0);
      expect(controller.fruit, 0);
      expect(controller.veg, 0);
      expect(controller.meal, 'breakfast');
      expect(controller.eatenAt, now);
      expect(controller.status, ManualEntryStatus.idle);
    });

    test('seeds a standard meal from the seam instead of hard-resetting to breakfast', () {
      final controller = ManualEntryController(
        LogManualEntry(FakeDietLogRepository()),
      );

      controller.start(meal: 'lunch', clock: () => DateTime.utc(2026, 7, 18, 9));

      expect(controller.meal, 'lunch');
      expect(controller.snackLabel, '');
    });

    test('seeds a snack session via snackMealValue + snackLabel (D5 seam)', () {
      final controller = ManualEntryController(
        LogManualEntry(FakeDietLogRepository()),
      );

      controller.start(
        meal: snackMealValue,
        snackLabel: '點心2',
        clock: () => DateTime.utc(2026, 7, 18, 9),
      );

      expect(controller.meal, snackMealValue);
      expect(controller.snackLabel, '點心2');
    });
  });

  group('ManualEntryController setters', () {
    test('setName/setPortion/setMeal/setEatenAt update the draft', () {
      final controller = ManualEntryController(
        LogManualEntry(FakeDietLogRepository()),
      );
      controller.start(clock: () => DateTime.utc(2026, 7, 18, 9));

      controller.setName('蛋');
      controller.setPortion('meat', 1);
      controller.setMeal('lunch');
      controller.setEatenAt(DateTime.utc(2026, 7, 18, 12, 30));

      expect(controller.name, '蛋');
      expect(controller.meat, 1);
      expect(controller.staple, 0);
      expect(controller.meal, 'lunch');
      expect(controller.eatenAt, DateTime.utc(2026, 7, 18, 12, 30));
    });
  });

  group('ManualEntryController.save', () {
    test('saves name/portions/meal/eatenAt and reports success', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime.utc(2026, 7, 18, 9));
      controller.setName('蛋');
      controller.setPortion('meat', 1);
      controller.setMeal('lunch');

      final result = await controller.save('token-123', '2026-07-18');

      expect(result, isTrue);
      expect(controller.status, ManualEntryStatus.saved);
      expect(repository.receivedDay, '2026-07-18');
      expect(repository.receivedMeal, 'lunch');
      expect(repository.receivedName, '蛋');
      expect(repository.receivedPortions?.meat, 1);
    });

    test('uses the custom snack label as the meal when snack is chosen', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime.utc(2026, 7, 18, 9));
      controller.setPortion('staple', 2);
      controller.setMeal('snack');
      controller.setSnackLabel('午後點心');

      await controller.save('token-123', '2026-07-18');

      expect(repository.receivedMeal, '午後點心');
    });

    test('blocks an all-zero-portions save without calling the repository', () async {
      final repository = FakeDietLogRepository();
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime.utc(2026, 7, 18, 9));

      final result = await controller.save('token-123', '2026-07-18');

      expect(result, isFalse);
      expect(controller.status, ManualEntryStatus.error);
      expect(controller.error, ManualEntryError.allZeroPortions);
      expect(repository.receivedDay, isNull);
    });

    test('sets a typed error and does not throw on failure', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime.utc(2026, 7, 18, 9));
      controller.setPortion('staple', 1);

      final result = await controller.save('token-123', '2026-07-18');

      expect(result, isFalse);
      expect(controller.status, ManualEntryStatus.error);
      expect(controller.error, ManualEntryError.saveFailed);
    });

    test('sets reauthRequired error on DietReauthenticationRequired', () async {
      final repository = FakeDietLogRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime.utc(2026, 7, 18, 9));
      controller.setPortion('staple', 1);

      await controller.save('token-123', '2026-07-18');

      expect(controller.error, ManualEntryError.reauthRequired);
    });
  });
}
