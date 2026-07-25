import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/application/import_water.dart';
import 'package:life_os/contexts/import/application/import_weight.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_exceptions.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_controller.dart';

/// A fake [ImportRepository] whose five methods can each be configured to
/// succeed with a summary or throw a given error, and which records the call
/// order across all five types.
class FakeImportRepository implements ImportRepository {
  final List<String> calls = [];

  Object? weightError;
  Object? dietError;
  Object? waterError;
  Object? bowelError;
  Object? dietTargetError;

  ChaodaysImportSummary weightSummary = const ChaodaysImportSummary(
    imported: 1,
    skipped: 0,
  );
  ChaodaysImportSummary dietSummary = const ChaodaysImportSummary(
    imported: 2,
    skipped: 1,
    glucoseImported: 3,
  );
  ChaodaysImportSummary waterSummary = const ChaodaysImportSummary(
    imported: 4,
    skipped: 0,
  );
  ChaodaysImportSummary bowelSummary = const ChaodaysImportSummary(
    imported: 5,
    skipped: 2,
  );
  ChaodaysImportSummary dietTargetSummary = const ChaodaysImportSummary(
    imported: 6,
    skipped: 1,
    waterTargetsImported: 7,
  );

  @override
  Future<ChaodaysImportSummary> importWeight(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('weight');
    if (weightError != null) throw weightError!;
    return weightSummary;
  }

  @override
  Future<ChaodaysImportSummary> importDiet(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('diet');
    if (dietError != null) throw dietError!;
    return dietSummary;
  }

  @override
  Future<ChaodaysImportSummary> importWater(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('water');
    if (waterError != null) throw waterError!;
    return waterSummary;
  }

  @override
  Future<ChaodaysImportSummary> importBowel(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('bowel');
    if (bowelError != null) throw bowelError!;
    return bowelSummary;
  }

  @override
  Future<ChaodaysImportSummary> importDietTarget(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('dietTarget');
    if (dietTargetError != null) throw dietTargetError!;
    return dietTargetSummary;
  }
}

ChaodaysImportController _controller(FakeImportRepository repository) =>
    ChaodaysImportController(
      ImportWeight(repository),
      ImportDiet(repository),
      ImportWater(repository),
      ImportBowel(repository),
      ImportDietTarget(repository),
    );

Future<void> _import(ChaodaysImportController controller) => controller.import(
  'token',
  chaodaysUid: 'user1',
  chaodaysPassword: 'pass1',
  startDate: '2026-07-01',
  endDate: '2026-07-18',
);

void main() {
  group('ChaodaysImportController.import', () {
    test('runs all five types in order and ends done with each summary', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);

      await _import(controller);

      expect(repository.calls, ['weight', 'diet', 'water', 'bowel', 'dietTarget']);
      expect(controller.status, ImportStatus.done);
      expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.success);
      expect(controller.typeStates[ImportType.weight]!.summary!.imported, 1);
      expect(controller.typeStates[ImportType.diet]!.summary!.imported, 2);
      expect(controller.typeStates[ImportType.diet]!.summary!.glucoseImported, 3);
      expect(controller.typeStates[ImportType.water]!.summary!.imported, 4);
      expect(controller.typeStates[ImportType.bowel]!.summary!.imported, 5);
      expect(controller.typeStates[ImportType.dietTarget]!.summary!.imported, 6);
      expect(
        controller.typeStates[ImportType.dietTarget]!.summary!.waterTargetsImported,
        7,
      );
    });

    test('every type starts notAttempted before import runs', () {
      final controller = _controller(FakeImportRepository());

      for (final type in ImportType.values) {
        expect(controller.typeStates[type]!.status, TypeStatus.notAttempted);
      }
      expect(controller.status, ImportStatus.idle);
    });

    test(
      'a chaodays auth failure on the first type aborts with status '
      'authFailed and leaves the remaining types notAttempted (not failed)',
      () async {
        final repository = FakeImportRepository()
          ..weightError = const ImportChaodaysAuthFailed();
        final controller = _controller(repository);

        await _import(controller);

        expect(repository.calls, ['weight']);
        expect(controller.status, ImportStatus.authFailed);
        // Shared-credential failure isn't any single type's fault: none is marked
        // failed; the overall authFailed status carries the message instead.
        expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.notAttempted);
        expect(controller.typeStates[ImportType.diet]!.status, TypeStatus.notAttempted);
        expect(controller.typeStates[ImportType.water]!.status, TypeStatus.notAttempted);
        expect(controller.typeStates[ImportType.bowel]!.status, TypeStatus.notAttempted);
      },
    );

    test('a lifeos 401 aborts with status needsReauth', () async {
      final repository = FakeImportRepository()
        ..dietError = const ImportReauthenticationRequired();
      final controller = _controller(repository);

      await _import(controller);

      expect(repository.calls, ['weight', 'diet']);
      expect(controller.status, ImportStatus.needsReauth);
      expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.success);
      expect(controller.typeStates[ImportType.water]!.status, TypeStatus.notAttempted);
    });

    test(
      'chaodays being unreachable aborts with status unavailable and marks '
      'that type failed',
      () async {
        final repository = FakeImportRepository()
          ..waterError = const ImportChaodaysUnavailable();
        final controller = _controller(repository);

        await _import(controller);

        expect(repository.calls, ['weight', 'diet', 'water']);
        expect(controller.status, ImportStatus.unavailable);
        expect(controller.typeStates[ImportType.water]!.status, TypeStatus.failed);
        expect(controller.typeStates[ImportType.bowel]!.status, TypeStatus.notAttempted);
      },
    );

    test('a fresh import call resets prior per-type state', () async {
      final repository = FakeImportRepository()
        ..weightError = const ImportChaodaysAuthFailed();
      final controller = _controller(repository);
      await _import(controller);
      expect(controller.status, ImportStatus.authFailed);

      repository.weightError = null;
      await _import(controller);

      expect(controller.status, ImportStatus.done);
      expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.success);
      expect(controller.typeStates[ImportType.bowel]!.status, TypeStatus.success);
    });

    test('reports importing while a type is in flight', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);

      final future = _import(controller);
      expect(controller.status, ImportStatus.importing);

      await future;
      expect(controller.status, ImportStatus.done);
    });
  });
}
