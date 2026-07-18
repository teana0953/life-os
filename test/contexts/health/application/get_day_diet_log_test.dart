import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeDietLogRepository implements DietLogRepository {
  DayDietLog? logToReturn;
  String? receivedIdToken;
  String? receivedDay;

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
    receivedIdToken = idToken;
    receivedDay = day;
    return logToReturn!;
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}
}

void main() {
  group('GetDayDietLog', () {
    test('returns the day log via the repository', () async {
      final repository = FakeDietLogRepository()
        ..logToReturn = DayDietLog.fromJson({
          'day': '2026-07-18',
          'meals': [],
          'totals': {
            'carbG': 0,
            'proteinG': 0,
            'fatG': 0,
            'sugarG': 0,
            'fiberG': 0,
            'kcal': 0,
          },
        });
      final getDayDietLog = GetDayDietLog(repository);

      final log = await getDayDietLog('token-123', '2026-07-18');

      expect(log.day, '2026-07-18');
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
    });
  });
}
