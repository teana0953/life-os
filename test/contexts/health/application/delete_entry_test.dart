import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/delete_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeDietLogRepository implements DietLogRepository {
  String? receivedIdToken;
  String? receivedEntryId;

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
    receivedIdToken = idToken;
    receivedEntryId = entryId;
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
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

void main() {
  group('DeleteEntry', () {
    test('deletes the entry via the repository', () async {
      final repository = FakeDietLogRepository();
      final deleteEntry = DeleteEntry(repository);

      await deleteEntry('token-123', 'entry-1');

      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedEntryId, 'entry-1');
    });
  });
}
