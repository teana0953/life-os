import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeDietLogRepository implements DietLogRepository {
  FoodEntry? entryToReturn;
  String? receivedIdToken;
  String? receivedDay;
  String? receivedMeal;
  String? receivedFoodItemId;
  double? receivedQuantity;
  double? receivedGrams;
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
    receivedIdToken = idToken;
    receivedDay = day;
    receivedMeal = meal;
    receivedFoodItemId = foodItemId;
    receivedQuantity = quantity;
    receivedGrams = grams;
    receivedEatenAt = eatenAt;
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

FoodEntry _entry() => FoodEntry.fromJson({
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
  group('LogFoodFromDictionary', () {
    test('logs by quantity', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final logFood = LogFoodFromDictionary(repository);

      final entry = await logFood(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        foodItemId: 'rice-1',
        quantity: 1.5,
      );

      expect(entry.staple, 6);
      expect(repository.receivedQuantity, 1.5);
      expect(repository.receivedGrams, isNull);
    });

    test('logs by grams', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final logFood = LogFoodFromDictionary(repository);

      await logFood(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        foodItemId: 'rice-1',
        grams: 33,
      );

      expect(repository.receivedGrams, 33);
      expect(repository.receivedQuantity, isNull);
    });

    test('passes through the eaten-at time', () async {
      final repository = FakeDietLogRepository()..entryToReturn = _entry();
      final logFood = LogFoodFromDictionary(repository);
      final eatenAt = DateTime.utc(2026, 7, 18, 12, 30);

      await logFood(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        foodItemId: 'rice-1',
        quantity: 1,
        eatenAt: eatenAt,
      );

      expect(repository.receivedEatenAt, eatenAt);
    });

    test(
      'throws ArgumentError when both quantity and grams are given',
      () async {
        final repository = FakeDietLogRepository()..entryToReturn = _entry();
        final logFood = LogFoodFromDictionary(repository);

        expect(
          () => logFood(
            'token-123',
            day: '2026-07-18',
            meal: 'lunch',
            foodItemId: 'rice-1',
            quantity: 1.5,
            grams: 33,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
