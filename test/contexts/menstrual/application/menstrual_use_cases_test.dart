import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';

class _RecordingMenstrualRepository implements MenstrualRepository {
  String? getOverviewToken;
  Map<String, Object?>? addArgs;
  Map<String, Object?>? updateArgs;
  String? deleteToken;
  String? deleteId;

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    getOverviewToken = idToken;
    return const MenstrualOverview(periods: [], stats: MenstrualStats());
  }

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    addArgs = {
      'idToken': idToken,
      'startDate': startDate,
      'endDate': endDate,
    };
    return MenstrualPeriod(id: 'p1', startDate: startDate, endDate: endDate);
  }

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    updateArgs = {
      'idToken': idToken,
      'id': id,
      'startDate': startDate,
      'endDate': endDate,
      'clearEndDate': clearEndDate,
    };
    return MenstrualPeriod(
      id: id,
      startDate: startDate ?? DateTime(2026, 6, 1),
      endDate: clearEndDate ? null : endDate,
    );
  }

  @override
  Future<bool> deletePeriod(String idToken, String id) async {
    deleteToken = idToken;
    deleteId = id;
    return true;
  }
}

void main() {
  test('GetMenstrualOverview delegates to the port', () async {
    final repo = _RecordingMenstrualRepository();
    await GetMenstrualOverview(repo)('tok');

    expect(repo.getOverviewToken, 'tok');
  });

  test('AddPeriod delegates to the port', () async {
    final repo = _RecordingMenstrualRepository();
    await AddPeriod(repo)(
      'tok',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 5),
    );

    expect(repo.addArgs, {
      'idToken': 'tok',
      'startDate': DateTime(2026, 6, 1),
      'endDate': DateTime(2026, 6, 5),
    });
  });

  test('UpdatePeriod delegates the partial params to the port', () async {
    final repo = _RecordingMenstrualRepository();
    await UpdatePeriod(repo)('tok', 'p1', clearEndDate: true);

    expect(repo.updateArgs, {
      'idToken': 'tok',
      'id': 'p1',
      'startDate': null,
      'endDate': null,
      'clearEndDate': true,
    });
  });

  test('DeletePeriod delegates to the port', () async {
    final repo = _RecordingMenstrualRepository();
    final deleted = await DeletePeriod(repo)('tok', 'p1');

    expect(repo.deleteToken, 'tok');
    expect(repo.deleteId, 'p1');
    expect(deleted, isTrue);
  });
}
