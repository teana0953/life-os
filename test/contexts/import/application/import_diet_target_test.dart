import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';

class _FakeImportRepository implements ImportRepository {
  String? capturedIdToken;
  String? capturedUid;
  String? capturedPassword;
  String? capturedStart;
  String? capturedEnd;

  final ChaodaysImportSummary summary = const ChaodaysImportSummary(
    imported: 6,
    skipped: 1,
    waterTargetsImported: 7,
  );

  @override
  Future<ChaodaysImportSummary> importDietTarget(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    capturedIdToken = idToken;
    capturedUid = chaodaysUid;
    capturedPassword = chaodaysPassword;
    capturedStart = startDate;
    capturedEnd = endDate;
    return summary;
  }

  @override
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => throw UnimplementedError();

  @override
  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => throw UnimplementedError();

  @override
  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => throw UnimplementedError();

  @override
  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) => throw UnimplementedError();
}

void main() {
  test('ImportDietTarget forwards to the repository and returns its summary', () async {
    final repository = _FakeImportRepository();
    final useCase = ImportDietTarget(repository);

    final summary = await useCase(
      'token-123',
      chaodaysUid: 'user1',
      chaodaysPassword: 'pass1',
      startDate: '2026-07-01',
      endDate: '2026-07-18',
    );

    expect(repository.capturedIdToken, 'token-123');
    expect(repository.capturedUid, 'user1');
    expect(repository.capturedPassword, 'pass1');
    expect(repository.capturedStart, '2026-07-01');
    expect(repository.capturedEnd, '2026-07-18');
    expect(summary, same(repository.summary));
  });
}
