import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_exceptions.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';

class _FakeVitalsRepository implements VitalsRepository {
  DateTime? gotFrom;
  DateTime? gotTo;
  int getRangeCalls = 0;
  Object? getError;

  @override
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async {
    getRangeCalls++;
    gotFrom = from;
    gotTo = to;
    if (getError != null) throw getError!;
    return VitalsRange(
      from: from,
      to: to,
      series: VitalsSeries(
        weight: [SeriesPoint(day: from, value: 65)],
        bodyFat: const [],
        systolic: const [],
        diastolic: const [],
        pulse: const [],
        glucose: const [],
        spo2: const [],
      ),
    );
  }

  @override
  Future<VitalsDay> getDay(String idToken, String day) => throw UnimplementedError();

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) => throw UnimplementedError();
}

TrendController _controller(
  _FakeVitalsRepository repository, {
  DateTime Function()? clock,
}) => TrendController(
  GetVitalsTrends(repository),
  clock: clock ?? DateTime.now,
);

void main() {
  group('TrendController.load', () {
    test('computes from = today - (spanDays - 1) and to = today (default 30)',
        () async {
      final repository = _FakeVitalsRepository();
      final controller = _controller(
        repository,
        clock: () => DateTime(2026, 7, 22, 15, 30),
      );

      await controller.load('token');

      expect(controller.status, TrendStatus.loaded);
      expect(controller.spanDays, 30);
      // 30-day span ending 2026-07-22 → from 2026-06-23.
      expect(repository.gotFrom, DateTime(2026, 6, 23));
      expect(repository.gotTo, DateTime(2026, 7, 22));
      expect(controller.range!.series.weight.single.value, 65);
    });

    test('a 401 surfaces needsReauth', () async {
      final repository = _FakeVitalsRepository()
        ..getError = const VitalsReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token');

      expect(controller.status, TrendStatus.needsReauth);
    });

    test('a fetch failure surfaces an error state', () async {
      final repository = _FakeVitalsRepository()
        ..getError = const VitalsFetchFailure('boom');
      final controller = _controller(repository);

      await controller.load('token');

      expect(controller.status, TrendStatus.error);
      expect(controller.error, TrendError.fetchFailed);
    });
  });

  group('TrendController.setSpan', () {
    test('updates spanDays and reloads with the new from/to', () async {
      final repository = _FakeVitalsRepository();
      final controller = _controller(
        repository,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token');
      expect(repository.getRangeCalls, 1);

      await controller.setSpan('token', 7);

      expect(controller.spanDays, 7);
      expect(repository.getRangeCalls, 2);
      // 7-day span ending 2026-07-22 → from 2026-07-16.
      expect(repository.gotFrom, DateTime(2026, 7, 16));
      expect(repository.gotTo, DateTime(2026, 7, 22));
    });
  });
}
