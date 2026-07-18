import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeDietLogRepository implements DietLogRepository {
  FoodEntry? entryToReturn;
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
}

FoodEntry _entry() => FoodEntry.fromJson({
  'id': 'entry-1',
  'day': '2026-07-18',
  'meal': 'lunch',
  'name': null,
  'photo_ref': null,
  'source': 'manual',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': 2,
  'meat': 1,
  'fruit': 0,
  'veg': 0,
  'eaten_at': '2026-07-18T12:30:00.000Z',
  'logged_at': '2026-07-18T12:31:00.000Z',
});

void main() {
  group('LogManualEntry', () {
    test('passes name/portions/meal/eatenAt through to the repository', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final logManualEntry = LogManualEntry(repository);
      final eatenAt = DateTime.utc(2026, 7, 18, 12, 30);

      final entry = await logManualEntry(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        name: '蛋',
        portions: const Portions(staple: 2, meat: 1, fruit: 0, veg: 0),
        eatenAt: eatenAt,
      );

      expect(entry.staple, 2);
      expect(repository.receivedDay, '2026-07-18');
      expect(repository.receivedMeal, 'lunch');
      expect(repository.receivedName, '蛋');
      expect(repository.receivedPortions?.staple, 2);
      expect(repository.receivedPortions?.meat, 1);
      expect(repository.receivedEatenAt, eatenAt);
    });

    test('allows a null name', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final logManualEntry = LogManualEntry(repository);

      await logManualEntry(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        portions: const Portions(staple: 2, meat: 1, fruit: 0, veg: 0),
        eatenAt: DateTime.utc(2026, 7, 18, 12, 30),
      );

      expect(repository.receivedName, isNull);
    });

    test('throws ArgumentError when all portions are zero', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final logManualEntry = LogManualEntry(repository);

      expect(
        () => logManualEntry(
          'token-123',
          day: '2026-07-18',
          meal: 'lunch',
          portions: const Portions(staple: 0, meat: 0, fruit: 0, veg: 0),
          eatenAt: DateTime.utc(2026, 7, 18, 12, 30),
        ),
        throwsArgumentError,
      );
    });
  });
}
