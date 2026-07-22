import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_exceptions.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';

/// A stateful in-memory fake: add/update/delete mutate a period list so a
/// re-read after a mutation reflects the change (the controller re-reads).
class FakeMenstrualRepository implements MenstrualRepository {
  final List<MenstrualPeriod> _periods = [];
  int _nextId = 1;
  Object? failGetOverview;

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    if (failGetOverview != null) throw failGetOverview!;
    return MenstrualOverview(
      periods: List.of(_periods),
      stats: const MenstrualStats(),
      lastPeriod: _periods.isEmpty ? null : _periods.last,
    );
  }

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final period = MenstrualPeriod(
      id: 'p${_nextId++}',
      startDate: startDate,
      endDate: endDate,
    );
    _periods.add(period);
    return period;
  }

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    final index = _periods.indexWhere((p) => p.id == id);
    final existing = _periods[index];
    final updated = MenstrualPeriod(
      id: id,
      startDate: startDate ?? existing.startDate,
      endDate: clearEndDate ? null : (endDate ?? existing.endDate),
    );
    _periods[index] = updated;
    return updated;
  }

  @override
  Future<bool> deletePeriod(String idToken, String id) async {
    _periods.removeWhere((p) => p.id == id);
    return true;
  }
}

MenstrualController _controller(FakeMenstrualRepository repo) =>
    MenstrualController(
      GetMenstrualOverview(repo),
      AddPeriod(repo),
      UpdatePeriod(repo),
      DeletePeriod(repo),
    );

void main() {
  test('load fetches the overview', () async {
    final controller = _controller(FakeMenstrualRepository());

    await controller.load('tok');

    expect(controller.status, MenstrualStatus.loaded);
    expect(controller.overview!.periods, isEmpty);
  });

  test('addPeriod re-reads the overview so the new period appears', () async {
    final controller = _controller(FakeMenstrualRepository());
    await controller.load('tok');

    await controller.addPeriod('tok', startDate: DateTime(2026, 6, 1));

    expect(controller.status, MenstrualStatus.loaded);
    expect(controller.overview!.periods, hasLength(1));
    expect(controller.overview!.lastPeriod!.isOpen, isTrue);
  });

  test('updatePeriod with clearEndDate reopens the period after the re-read',
      () async {
    final controller = _controller(FakeMenstrualRepository());
    await controller.load('tok');
    await controller.addPeriod(
      'tok',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 5),
    );
    final id = controller.overview!.periods.single.id;

    await controller.updatePeriod('tok', id, clearEndDate: true);

    expect(controller.overview!.periods.single.endDate, isNull);
  });

  test('deletePeriod re-reads the overview so the period is gone', () async {
    final controller = _controller(FakeMenstrualRepository());
    await controller.load('tok');
    await controller.addPeriod('tok', startDate: DateTime(2026, 6, 1));
    final id = controller.overview!.periods.single.id;

    await controller.deletePeriod('tok', id);

    expect(controller.overview!.periods, isEmpty);
  });

  test('a 401 on load surfaces needsReauth', () async {
    final repo = FakeMenstrualRepository()
      ..failGetOverview = const MenstrualReauthenticationRequired();
    final controller = _controller(repo);

    await controller.load('tok');

    expect(controller.status, MenstrualStatus.needsReauth);
  });

  test('a fetch failure on load surfaces an error state', () async {
    final repo = FakeMenstrualRepository()
      ..failGetOverview = const MenstrualFetchFailure();
    final controller = _controller(repo);

    await controller.load('tok');

    expect(controller.status, MenstrualStatus.error);
    expect(controller.error, MenstrualError.fetchFailed);
  });
}
