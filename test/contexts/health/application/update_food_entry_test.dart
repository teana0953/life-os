import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/update_food_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeDietLogRepository implements DietLogRepository {
  String? receivedEntryId;
  String? receivedName;
  String? receivedMeal;
  DateTime? receivedEatenAt;
  Portions? receivedPortions;
  FoodEntry? entryToReturn;

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
    receivedEntryId = entryId;
    receivedName = name;
    receivedMeal = meal;
    receivedEatenAt = eatenAt;
    receivedPortions = portions;
    return entryToReturn!;
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
  group('UpdateFoodEntry', () {
    test('delegates to the repository with the given fields', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final useCase = UpdateFoodEntry(repository);

      final entry = await useCase(
        'token-123',
        'entry-1',
        name: '蛋',
        meal: 'lunch',
        portions: const Portions(staple: 0, meat: 1, fruit: 0, veg: 0),
      );

      expect(repository.receivedEntryId, 'entry-1');
      expect(repository.receivedName, '蛋');
      expect(repository.receivedMeal, 'lunch');
      expect(repository.receivedEatenAt, isNull);
      expect(repository.receivedPortions?.meat, 1);
      expect(entry.meat, 1);
    });

    test('passes eatenAt through only when given', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _fakeEntry();
      final useCase = UpdateFoodEntry(repository);

      await useCase(
        'token-123',
        'entry-1',
        eatenAt: DateTime.utc(2026, 7, 18, 9),
      );

      expect(repository.receivedEatenAt, DateTime.utc(2026, 7, 18, 9));
    });
  });
}
