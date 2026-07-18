import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';

Map<String, dynamic> _baseEntryJson({
  String meal = 'lunch',
  String eatenAt = '2026-07-18T12:30:00.000Z',
}) => {
  'id': 'entry-1',
  'day': '2026-07-18',
  'meal': meal,
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
  'eaten_at': eatenAt,
  'logged_at': '2026-07-18T12:31:00.000Z',
};

void main() {
  group('FoodEntry.fromJson', () {
    test('parses all fields from backend shape', () {
      final entry = FoodEntry.fromJson(_baseEntryJson());

      expect(entry.id, 'entry-1');
      expect(entry.day, '2026-07-18');
      expect(entry.meal, 'lunch');
      expect(entry.name, '飯/1碗');
      expect(entry.source, FoodEntrySource.dict);
      expect(entry.unclassified, isFalse);
      expect(entry.staple, 6);
      expect(entry.eatenAt, DateTime.parse('2026-07-18T12:30:00.000Z'));
      expect(entry.loggedAt, DateTime.parse('2026-07-18T12:31:00.000Z'));
    });

    test('parses manual and ai_photo sources', () {
      expect(
        FoodEntry.fromJson({..._baseEntryJson(), 'source': 'manual'}).source,
        FoodEntrySource.manual,
      );
      expect(
        FoodEntry.fromJson({..._baseEntryJson(), 'source': 'ai_photo'}).source,
        FoodEntrySource.aiPhoto,
      );
    });
  });
}
