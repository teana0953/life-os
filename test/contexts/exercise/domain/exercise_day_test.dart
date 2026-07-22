import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';

void main() {
  group('ExerciseActivity.fromJson', () {
    test('parses id, name, category, and intensity', () {
      final activity = ExerciseActivity.fromJson({
        'id': 'jogging',
        'name': '慢跑',
        'category': 'aerobic',
        'intensity': '8km/hr',
      });

      expect(activity.id, 'jogging');
      expect(activity.name, '慢跑');
      expect(activity.category, 'aerobic');
      expect(activity.intensity, '8km/hr');
    });

    test('defaults a missing intensity to empty', () {
      final activity = ExerciseActivity.fromJson({
        'id': 'yoga',
        'name': '瑜伽',
        'category': 'anaerobic',
      });

      expect(activity.intensity, '');
    });
  });

  group('ExerciseEntry.fromJson', () {
    test('parses snake_case fields including enrich fields', () {
      final entry = ExerciseEntry.fromJson({
        'id': 'e1',
        'activity_id': 'jogging',
        'activity_name': '慢跑',
        'category': 'aerobic',
        'duration_minutes': 30,
        'note': 'morning run',
        'created_at': '2026-07-18T09:00:00.000Z',
      });

      expect(entry.id, 'e1');
      expect(entry.activityId, 'jogging');
      expect(entry.activityName, '慢跑');
      expect(entry.category, 'aerobic');
      expect(entry.durationMinutes, 30);
      expect(entry.note, 'morning run');
      expect(entry.createdAt, DateTime.utc(2026, 7, 18, 9));
    });

    test('defaults a missing note to empty and tolerates absent enrich fields', () {
      final entry = ExerciseEntry.fromJson({
        'id': 'e2',
        'activity_id': 'squats',
        'duration_minutes': 15,
        'created_at': '2026-07-18T10:00:00.000Z',
      });

      expect(entry.note, '');
      expect(entry.activityName, isNull);
      expect(entry.category, isNull);
    });
  });

  group('ExerciseDay.fromJson', () {
    test('parses the day, its entries, and the total', () {
      final day = ExerciseDay.fromJson({
        'day': '2026-07-18',
        'entries': [
          {
            'id': 'e1',
            'activity_id': 'jogging',
            'activity_name': '慢跑',
            'category': 'aerobic',
            'duration_minutes': 30,
            'note': '',
            'created_at': '2026-07-18T09:00:00.000Z',
          },
        ],
        'total_minutes': 30,
      });

      expect(day.day, '2026-07-18');
      expect(day.entries, hasLength(1));
      expect(day.entries.single.activityId, 'jogging');
      expect(day.totalMinutes, 30);
    });

    test('an unrecorded day has no entries and a zero total', () {
      final day = ExerciseDay.fromJson({
        'day': '2026-07-18',
        'entries': <dynamic>[],
        'total_minutes': 0,
      });

      expect(day.entries, isEmpty);
      expect(day.totalMinutes, 0);
    });
  });
}
