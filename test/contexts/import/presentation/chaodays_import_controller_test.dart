import 'dart:async' show TimeoutException;

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/import/application/import_bowel.dart';
import 'package:life_os/contexts/import/application/import_diet.dart';
import 'package:life_os/contexts/import/application/import_diet_target.dart';
import 'package:life_os/contexts/import/application/import_menstrual.dart';
import 'package:life_os/contexts/import/application/import_water.dart';
import 'package:life_os/contexts/import/application/import_weight.dart';
import 'package:life_os/contexts/import/domain/chaodays_import_summary.dart';
import 'package:life_os/contexts/import/domain/import_exceptions.dart';
import 'package:life_os/contexts/import/domain/import_repository.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_controller.dart';
import 'package:life_os/shared/data_revision.dart';

/// A fake [ImportRepository] whose six methods can each be configured to
/// succeed with a summary or throw a given error, and which records the call
/// order across all six types.
class FakeImportRepository implements ImportRepository {
  final List<String> calls = [];

  Object? weightError;
  Object? dietError;
  Object? waterError;
  Object? bowelError;
  Object? dietTargetError;
  Object? menstrualError;

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
  ChaodaysImportSummary menstrualSummary = const ChaodaysImportSummary(
    imported: 9,
    skipped: 3,
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

  @override
  Future<ChaodaysImportSummary> importMenstrual(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    calls.add('menstrual');
    if (menstrualError != null) throw menstrualError!;
    return menstrualSummary;
  }
}

ChaodaysImportController _controller(
  FakeImportRepository repository, {
  DataRevision? dataRevision,
}) => ChaodaysImportController(
  ImportWeight(repository),
  ImportDiet(repository),
  ImportWater(repository),
  ImportBowel(repository),
  ImportDietTarget(repository),
  ImportMenstrual(repository),
  dataRevision ?? DataRevision(),
);

/// Runs an import over [types], defaulting to every type (the behaviour the
/// pre-selection tests below assert).
Future<void> _import(
  ChaodaysImportController controller, {
  Set<ImportType>? types,
}) => controller.import(
  'token',
  types: types ?? ImportType.values.toSet(),
  chaodaysUid: 'user1',
  chaodaysPassword: 'pass1',
  startDate: '2026-07-01',
  endDate: '2026-07-18',
);

void main() {
  group('ChaodaysImportController.import', () {
    test('runs all six types in order and ends done with each summary', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);

      await _import(controller);

      expect(repository.calls, [
        'weight',
        'diet',
        'water',
        'bowel',
        'dietTarget',
        'menstrual',
      ]);
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
      expect(controller.typeStates[ImportType.menstrual]!.summary!.imported, 9);
      expect(controller.typeStates[ImportType.menstrual]!.summary!.skipped, 3);
    });

    test('every type starts pristine before import runs', () {
      final controller = _controller(FakeImportRepository());

      for (final type in ImportType.values) {
        expect(controller.typeStates[type]!.status, TypeStatus.pristine);
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

    // Distinct from the ImportChaodaysUnavailable case above: a client-side
    // timeout does not mean the request failed to reach the backend, so it
    // gets its own status rather than folding into `unavailable` (whose copy
    // implies a plain failure the user could just retry).
    test(
      'a client-side timeout aborts with status timedOut, not unavailable',
      () async {
        final repository = FakeImportRepository()
          ..waterError = TimeoutException(
            'HTTP request timed out',
            const Duration(seconds: 15),
          );
        final controller = _controller(repository);

        await _import(controller);

        expect(repository.calls, ['weight', 'diet', 'water']);
        expect(controller.status, ImportStatus.timedOut);
        expect(controller.typeStates[ImportType.water]!.status, TypeStatus.failed);
        expect(controller.typeStates[ImportType.bowel]!.status, TypeStatus.notAttempted);
      },
    );

    test('a failing menstrual import marks that type failed', () async {
      final repository = FakeImportRepository()
        ..menstrualError = const ImportChaodaysUnavailable();
      final controller = _controller(repository);

      await _import(controller);

      expect(controller.status, ImportStatus.unavailable);
      expect(controller.typeStates[ImportType.menstrual]!.status, TypeStatus.failed);
      expect(controller.typeStates[ImportType.dietTarget]!.status, TypeStatus.success);
    });

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

  group('ChaodaysImportController.import type selection', () {
    test('runs only the selected type and leaves the rest untouched', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);

      await _import(controller, types: {ImportType.diet});

      expect(repository.calls, ['diet']);
      expect(controller.status, ImportStatus.done);
      expect(controller.typeStates[ImportType.diet]!.status, TypeStatus.success);
      // Never part of any run, so still exactly as they started.
      for (final type in ImportType.values.where((t) => t != ImportType.diet)) {
        expect(controller.typeStates[type]!.status, TypeStatus.pristine);
      }
    });

    test('runs the selected types in ImportType.values order, not selection order', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);

      // Selected "diet target first", but the display/run order is fixed.
      await _import(controller, types: {ImportType.dietTarget, ImportType.weight});

      expect(repository.calls, ['weight', 'dietTarget']);
      expect(controller.status, ImportStatus.done);
      expect(controller.typeStates[ImportType.diet]!.status, TypeStatus.pristine);
    });

    test('runs menstrual, and only menstrual, when it is the only one selected', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);

      await _import(controller, types: {ImportType.menstrual});

      expect(repository.calls, ['menstrual']);
      expect(controller.status, ImportStatus.done);
      expect(controller.typeStates[ImportType.menstrual]!.summary!.imported, 9);
      for (final type in ImportType.values.where((t) => t != ImportType.menstrual)) {
        expect(controller.typeStates[type]!.status, TypeStatus.pristine);
      }
    });

    test(
      'a failing selected type still aborts the run, leaving later selected '
      'types unrun',
      () async {
        final repository = FakeImportRepository()
          ..waterError = const ImportChaodaysUnavailable();
        final controller = _controller(repository);

        await _import(controller, types: {ImportType.water, ImportType.bowel});

        expect(repository.calls, ['water']);
        expect(controller.status, ImportStatus.unavailable);
        expect(controller.typeStates[ImportType.water]!.status, TypeStatus.failed);
        expect(controller.typeStates[ImportType.bowel]!.status, TypeStatus.notAttempted);
      },
    );

    test(
      'a new run resets only the types it will run, keeping the rest',
      () async {
        final repository = FakeImportRepository();
        final controller = _controller(repository);
        await _import(controller);
        expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.success);

        repository.waterError = const ImportChaodaysUnavailable();
        await _import(controller, types: {ImportType.water, ImportType.bowel});

        expect(controller.typeStates[ImportType.water]!.status, TypeStatus.failed);
        // Selected for this run but never reached: the old success is cleared
        // to notAttempted ("queued, didn't get there"), not to pristine.
        expect(
          controller.typeStates[ImportType.bowel]!.status,
          TypeStatus.notAttempted,
        );
        // Left out of this run entirely, so its earlier result still stands
        // rather than being wiped by a run it was no part of.
        expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.success);
        expect(controller.typeStates[ImportType.weight]!.summary!.imported, 1);
      },
    );

    test('a selection mutated after the call started does not change the run', () async {
      final repository = FakeImportRepository();
      final controller = _controller(repository);
      final types = {ImportType.weight, ImportType.diet};

      // The screen hands over its own live set, so the controller has to work
      // off a copy: mutating the caller's set mid-run must not re-route it.
      var mutated = false;
      controller.addListener(() {
        if (mutated) return;
        mutated = true;
        types
          ..remove(ImportType.diet)
          ..add(ImportType.bowel);
      });

      await _import(controller, types: types);

      expect(repository.calls, ['weight', 'diet']);
    });

    test('bumps the revision when a selected type succeeds', () async {
      final dataRevision = DataRevision();
      final controller = _controller(
        FakeImportRepository(),
        dataRevision: dataRevision,
      );

      await _import(controller, types: {ImportType.bowel});

      expect(dataRevision.revision, 1);
    });

    test('does not bump when the only selected type fails', () async {
      final dataRevision = DataRevision();
      final repository = FakeImportRepository()
        ..bowelError = const ImportChaodaysUnavailable();
      final controller = _controller(repository, dataRevision: dataRevision);

      await _import(controller, types: {ImportType.bowel});

      expect(controller.status, ImportStatus.unavailable);
      expect(dataRevision.revision, 0);
    });
  });

  group('ChaodaysImportController.clearType', () {
    test('clears that type back to pristine and leaves the others alone', () async {
      final controller = _controller(FakeImportRepository());
      await _import(controller);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.clearType(ImportType.diet);

      expect(controller.typeStates[ImportType.diet]!.status, TypeStatus.pristine);
      expect(controller.typeStates[ImportType.diet]!.summary, isNull);
      for (final type in ImportType.values.where((t) => t != ImportType.diet)) {
        expect(controller.typeStates[type]!.status, TypeStatus.success);
      }
      // The screen only redraws on a notification.
      expect(notifications, 1);
    });

    test('leaves the overall status alone', () async {
      final repository = FakeImportRepository()
        ..weightError = const ImportChaodaysUnavailable();
      final controller = _controller(repository);
      await _import(controller);
      expect(controller.status, ImportStatus.unavailable);

      controller.clearType(ImportType.weight);

      // The banner reports how the last run went; changing one row's selection
      // doesn't make that untrue, and the message has to stay while the user
      // corrects the credentials and retries.
      expect(controller.status, ImportStatus.unavailable);
    });
  });

  group('ChaodaysImportController data revision bump', () {
    test('bumps once on a fully successful run', () async {
      final dataRevision = DataRevision();
      final controller = _controller(
        FakeImportRepository(),
        dataRevision: dataRevision,
      );

      await _import(controller);

      expect(controller.status, ImportStatus.done);
      expect(dataRevision.revision, 1);
    });

    test(
      'bumps once on a run that aborts partway after some types succeeded',
      () async {
        final dataRevision = DataRevision();
        final repository = FakeImportRepository()
          ..waterError = const ImportChaodaysUnavailable();
        final controller = _controller(repository, dataRevision: dataRevision);

        await _import(controller);

        expect(controller.status, ImportStatus.unavailable);
        expect(controller.typeStates[ImportType.weight]!.status, TypeStatus.success);
        expect(dataRevision.revision, 1);
      },
    );

    test('does not bump when the first type fails and nothing succeeds', () async {
      final dataRevision = DataRevision();
      final repository = FakeImportRepository()
        ..weightError = const ImportChaodaysAuthFailed();
      final controller = _controller(repository, dataRevision: dataRevision);

      await _import(controller);

      expect(controller.status, ImportStatus.authFailed);
      expect(dataRevision.revision, 0);
    });

    test('bumps at most once per run, even across multiple runs', () async {
      final dataRevision = DataRevision();
      final controller = _controller(
        FakeImportRepository(),
        dataRevision: dataRevision,
      );

      await _import(controller);
      expect(dataRevision.revision, 1);

      await _import(controller);
      expect(dataRevision.revision, 2);
    });

    test(
      'a second concurrent import() swallowed by the re-entrancy guard does '
      'not bump',
      () async {
        final dataRevision = DataRevision();
        final controller = _controller(
          FakeImportRepository(),
          dataRevision: dataRevision,
        );

        final first = _import(controller);
        // Fired while `first` is still in flight — the re-entrancy guard
        // returns immediately without touching the shared revision, so this
        // must not add a second bump once `first` finishes.
        final second = _import(controller);

        await Future.wait([first, second]);

        expect(controller.status, ImportStatus.done);
        expect(dataRevision.revision, 1);
      },
    );
  });
}
