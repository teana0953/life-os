import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeDietLogRepository implements DietLogRepository {
  String? receivedMonth;
  List<String> daysToReturn = const [];

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
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    receivedMonth = month;
    return daysToReturn;
  }
}

void main() {
  group('GetLoggedDays', () {
    test('delegates to the repository with the given month', () async {
      final repository = FakeDietLogRepository()
        ..daysToReturn = ['2026-07-01', '2026-07-15'];
      final useCase = GetLoggedDays(repository);

      final days = await useCase('token-123', '2026-07');

      expect(repository.receivedMonth, '2026-07');
      expect(days, ['2026-07-01', '2026-07-15']);
    });
  });
}
