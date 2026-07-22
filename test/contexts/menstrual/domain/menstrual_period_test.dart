import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';

void main() {
  group('MenstrualPeriod.fromJson', () {
    test('parses a closed period with date-only start/end', () {
      final period = MenstrualPeriod.fromJson({
        'id': 'p1',
        'start_date': '2026-05-01',
        'end_date': '2026-05-05',
      });

      expect(period.id, 'p1');
      expect(period.startDate, DateTime(2026, 5, 1));
      expect(period.endDate, DateTime(2026, 5, 5));
      expect(period.isOpen, isFalse);
    });

    test('treats a null end_date as an open period', () {
      final period = MenstrualPeriod.fromJson({
        'id': 'p2',
        'start_date': '2026-06-01',
        'end_date': null,
      });

      expect(period.endDate, isNull);
      expect(period.isOpen, isTrue);
    });
  });

  group('MenstrualStats.fromJson', () {
    test('parses all statistics', () {
      final stats = MenstrualStats.fromJson({
        'average_cycle_days': 28,
        'average_period_days': 5,
        'predicted_next_start': '2026-07-24',
      });

      expect(stats.averageCycleDays, 28);
      expect(stats.averagePeriodDays, 5);
      expect(stats.predictedNextStart, DateTime(2026, 7, 24));
    });

    test('handles each field being null independently', () {
      final stats = MenstrualStats.fromJson({
        'average_cycle_days': null,
        'average_period_days': null,
        'predicted_next_start': null,
      });

      expect(stats.averageCycleDays, isNull);
      expect(stats.averagePeriodDays, isNull);
      expect(stats.predictedNextStart, isNull);
    });
  });

  group('MenstrualOverview.fromJson', () {
    test('parses periods, the always-present stats, and last_period', () {
      final overview = MenstrualOverview.fromJson({
        'periods': [
          {'id': 'p1', 'start_date': '2026-05-01', 'end_date': '2026-05-05'},
          {'id': 'p2', 'start_date': '2026-06-01', 'end_date': null},
        ],
        'stats': {
          'average_cycle_days': 28,
          'average_period_days': 5,
          'predicted_next_start': '2026-07-24',
        },
        'last_period': {
          'id': 'p2',
          'start_date': '2026-06-01',
          'end_date': null,
        },
      });

      expect(overview.periods, hasLength(2));
      expect(overview.stats.averageCycleDays, 28);
      expect(overview.lastPeriod!.id, 'p2');
    });

    test('a null last_period is allowed while stats stays an object', () {
      final overview = MenstrualOverview.fromJson({
        'periods': <dynamic>[],
        'stats': {
          'average_cycle_days': null,
          'average_period_days': null,
          'predicted_next_start': null,
        },
        'last_period': null,
      });

      expect(overview.periods, isEmpty);
      expect(overview.lastPeriod, isNull);
      expect(overview.stats.averageCycleDays, isNull);
    });
  });
}
