import 'package:flutter/foundation.dart';

import '../application/import_bowel.dart';
import '../application/import_diet.dart';
import '../application/import_water.dart';
import '../application/import_weight.dart';
import '../domain/chaodays_import_summary.dart';
import '../domain/import_exceptions.dart';

/// The four chaodays data types imported by [ChaodaysImportController], in
/// the fixed order they run.
enum ImportType { weight, diet, water, bowel }

enum TypeStatus { notAttempted, importing, success, failed }

/// One data type's progress: [status] plus, once [TypeStatus.success], the
/// resulting [summary].
class TypeState {
  final TypeStatus status;
  final ChaodaysImportSummary? summary;

  const TypeState._(this.status, this.summary);

  const TypeState.notAttempted() : this._(TypeStatus.notAttempted, null);
  const TypeState.importing() : this._(TypeStatus.importing, null);
  const TypeState.success(ChaodaysImportSummary summary)
    : this._(TypeStatus.success, summary);
  const TypeState.failed() : this._(TypeStatus.failed, null);
}

enum ImportStatus { idle, importing, done, authFailed, unavailable, needsReauth }

Map<ImportType, TypeState> _freshTypeStates() => {
  for (final type in ImportType.values) type: const TypeState.notAttempted(),
};

/// Drives the chaodays import screen: runs the four data-type imports
/// (weight, diet, water, bowel) in order against the given date range,
/// tracking overall [status] and each type's [TypeState] in [typeStates].
///
/// The chaodays credentials are passed through to [import] and never held by
/// this controller (or its use cases) beyond the call — there is no storage
/// dependency, so the password cannot be persisted.
class ChaodaysImportController extends ChangeNotifier {
  final ImportWeight _importWeight;
  final ImportDiet _importDiet;
  final ImportWater _importWater;
  final ImportBowel _importBowel;

  ChaodaysImportController(
    this._importWeight,
    this._importDiet,
    this._importWater,
    this._importBowel,
  );

  ImportStatus status = ImportStatus.idle;
  Map<ImportType, TypeState> typeStates = _freshTypeStates();

  Future<ChaodaysImportSummary> _runImport(
    ImportType type,
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) {
    switch (type) {
      case ImportType.weight:
        return _importWeight(
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
      case ImportType.diet:
        return _importDiet(
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
      case ImportType.water:
        return _importWater(
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
      case ImportType.bowel:
        return _importBowel(
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
    }
  }

  /// Imports [startDate]..[endDate] (both `YYYY-MM-DD`) for all four types,
  /// in order. Stops at the first failure:
  /// - Wrong chaodays credentials (shared by all four types, so the rest
  ///   would fail identically) → [ImportStatus.authFailed]; the remaining
  ///   types are left [TypeStatus.notAttempted] rather than marked failed.
  /// - A lifeos 401 → [ImportStatus.needsReauth].
  /// - chaodays unreachable, or any other failure → [ImportStatus.unavailable]
  ///   with that type marked [TypeStatus.failed].
  ///
  /// Otherwise, once all four succeed, ends at [ImportStatus.done].
  Future<void> import(
    String idToken, {
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    // Re-entrancy guard: ignore a second call while one is already running (a
    // fast double-tap can fire before the button's importing state is reflected).
    if (status == ImportStatus.importing) return;
    status = ImportStatus.importing;
    typeStates = _freshTypeStates();
    notifyListeners();

    for (final type in ImportType.values) {
      typeStates = {...typeStates, type: const TypeState.importing()};
      notifyListeners();

      try {
        final summary = await _runImport(
          type,
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
        typeStates = {...typeStates, type: TypeState.success(summary)};
        notifyListeners();
      } on ImportChaodaysAuthFailed {
        // All types share the same credentials, so a credential failure isn't
        // this type's fault — leave it not-attempted (not red-failed) and surface
        // one overall auth-failed message instead.
        typeStates = {...typeStates, type: const TypeState.notAttempted()};
        status = ImportStatus.authFailed;
        notifyListeners();
        return;
      } on ImportReauthenticationRequired {
        status = ImportStatus.needsReauth;
        notifyListeners();
        return;
      } catch (_) {
        typeStates = {...typeStates, type: const TypeState.failed()};
        status = ImportStatus.unavailable;
        notifyListeners();
        return;
      }
    }

    status = ImportStatus.done;
    notifyListeners();
  }
}
