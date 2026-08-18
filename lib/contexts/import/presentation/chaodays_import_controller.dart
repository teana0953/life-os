import 'dart:async' show TimeoutException;

import 'package:flutter/foundation.dart';

import '../../../shared/data_revision.dart';
import '../application/import_bowel.dart';
import '../application/import_diet.dart';
import '../application/import_diet_target.dart';
import '../application/import_menstrual.dart';
import '../application/import_water.dart';
import '../application/import_weight.dart';
import '../domain/chaodays_import_summary.dart';
import '../domain/import_exceptions.dart';

/// The six chaodays data types imported by [ChaodaysImportController], in
/// the fixed order they run.
enum ImportType { weight, diet, water, bowel, dietTarget, menstrual }

/// A single type's import state.
///
/// [pristine] and [notAttempted] both mean "this type did not run", but they
/// are told apart on purpose: [pristine] has nothing to report at all (never
/// run, or just cleared), while [notAttempted] is the positive statement "a
/// run happened and did not get to this one".
enum TypeStatus { pristine, notAttempted, importing, success, failed }

/// One data type's progress: [status] plus, once [TypeStatus.success], the
/// resulting [summary].
class TypeState {
  final TypeStatus status;
  final ChaodaysImportSummary? summary;

  const TypeState._(this.status, this.summary);

  const TypeState.pristine() : this._(TypeStatus.pristine, null);
  const TypeState.notAttempted() : this._(TypeStatus.notAttempted, null);
  const TypeState.importing() : this._(TypeStatus.importing, null);
  const TypeState.success(ChaodaysImportSummary summary)
    : this._(TypeStatus.success, summary);
  const TypeState.failed() : this._(TypeStatus.failed, null);
}

enum ImportStatus {
  idle,
  importing,
  done,
  authFailed,
  unavailable,
  timedOut,
  needsReauth,
}

Map<ImportType, TypeState> _freshTypeStates() => {
  for (final type in ImportType.values) type: const TypeState.pristine(),
};

/// Drives the chaodays import screen: runs the selected data-type imports
/// (out of weight, diet, water, bowel, diet target, menstrual) in order
/// against the given date range, tracking overall [status] and each type's
/// [TypeState] in [typeStates].
///
/// The chaodays credentials are passed through to [import] and never held by
/// this controller (or its use cases) beyond the call — there is no storage
/// dependency, so the password cannot be persisted.
class ChaodaysImportController extends ChangeNotifier {
  final ImportWeight _importWeight;
  final ImportDiet _importDiet;
  final ImportWater _importWater;
  final ImportBowel _importBowel;
  final ImportDietTarget _importDietTarget;
  final ImportMenstrual _importMenstrual;
  final DataRevision _dataRevision;

  ChaodaysImportController(
    this._importWeight,
    this._importDiet,
    this._importWater,
    this._importBowel,
    this._importDietTarget,
    this._importMenstrual,
    this._dataRevision,
  );

  ImportStatus status = ImportStatus.idle;
  Map<ImportType, TypeState> typeStates = _freshTypeStates();

  /// Drops [type]'s result back to [TypeStatus.pristine] — "nothing to report"
  /// — leaving every other type's state, and the overall [status], as they
  /// were. Called when the user changes that type's selection: the old result
  /// stops being about the run the user is now assembling, but the banner
  /// still describes the run that actually happened.
  void clearType(ImportType type) {
    typeStates = {...typeStates, type: const TypeState.pristine()};
    notifyListeners();
  }

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
      case ImportType.dietTarget:
        return _importDietTarget(
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
      case ImportType.menstrual:
        return _importMenstrual(
          idToken,
          chaodaysUid: chaodaysUid,
          chaodaysPassword: chaodaysPassword,
          startDate: startDate,
          endDate: endDate,
        );
    }
  }

  /// Imports [startDate]..[endDate] (both `YYYY-MM-DD`) for the selected
  /// [types], in [ImportType.values] order; unselected types don't run and
  /// keep the [TypeState] they already had. [types] is required and has no
  /// default: a default would let a caller that forgot it silently import
  /// everything.
  ///
  /// Stops at the first failure:
  /// - Wrong chaodays credentials (shared by all six types, so the rest
  ///   would fail identically) → [ImportStatus.authFailed]; the remaining
  ///   types are left [TypeStatus.notAttempted] rather than marked failed.
  /// - A lifeos 401 → [ImportStatus.needsReauth].
  /// - The request timed out client-side (`TimeoutClient`) → [ImportStatus.timedOut]
  ///   — unlike [ImportStatus.unavailable], the request may already have
  ///   reached and been applied by the backend, so the screen must not tell
  ///   the user this type simply "failed".
  /// - chaodays unreachable, or any other failure → [ImportStatus.unavailable]
  ///   with that type marked [TypeStatus.failed].
  ///
  /// Otherwise, once every selected type succeeds, ends at
  /// [ImportStatus.done].
  Future<void> import(
    String idToken, {
    required Set<ImportType> types,
    required String chaodaysUid,
    required String chaodaysPassword,
    required String startDate,
    required String endDate,
  }) async {
    // Re-entrancy guard: ignore a second call while one is already running (a
    // fast double-tap can fire before the button's importing state is reflected).
    if (status == ImportStatus.importing) return;
    // Copied up front: the caller (the screen) hands over the very set its
    // checkboxes mutate, and the loop below reads it lazily across awaits — so
    // without a copy a mid-run edit would silently re-route the rest of the run.
    final selected = types.toSet();
    status = ImportStatus.importing;
    // Only this run's types are reset — the ones it leaves out keep whatever
    // they were showing, since this run says nothing about them. They go to
    // `notAttempted` ("selected, not reached yet") rather than `pristine`,
    // which is reserved for "nothing to report at all".
    typeStates = {
      ...typeStates,
      for (final type in selected) type: const TypeState.notAttempted(),
    };
    notifyListeners();

    // Bumps the shared revision exactly once per run, iff at least one type
    // reached success — including a run that aborts partway, since lifeos
    // data still changed. Placed after the re-entrancy guard above (not
    // wrapping the whole method) so a swallowed concurrent call — which
    // returns before reaching here — can't bump again off this run's
    // successes.
    var anySucceeded = false;
    try {
      // Filtered off ImportType.values rather than iterating [types], so the
      // run order stays the fixed display order whatever order they were
      // selected in.
      for (final type in ImportType.values.where(selected.contains)) {
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
          anySucceeded = true;
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
        } on TimeoutException {
          typeStates = {...typeStates, type: const TypeState.failed()};
          status = ImportStatus.timedOut;
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
    } finally {
      if (anySucceeded) _dataRevision.bump();
    }
  }
}
