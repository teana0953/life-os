import 'package:flutter/foundation.dart';

import '../application/add_period.dart';
import '../application/delete_period.dart';
import '../application/get_menstrual_overview.dart';
import '../application/update_period.dart';
import '../domain/menstrual_exceptions.dart';
import '../domain/menstrual_period.dart';

enum MenstrualStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the menstrual overview can fail, as understood by
/// `MenstrualScreen`.
enum MenstrualError { fetchFailed, unknown }

/// Drives the menstrual screen: loads the whole overview (periods + stats +
/// last period) and adds/updates/deletes a period immediately. Every mutation
/// re-reads the overview from the backend rather than computing locally —
/// mirroring `WaterController._apply`, not a draft-then-save flow. Not
/// day-keyed: [load] takes no day.
class MenstrualController extends ChangeNotifier {
  final GetMenstrualOverview _getOverview;
  final AddPeriod _addPeriod;
  final UpdatePeriod _updatePeriod;
  final DeletePeriod _deletePeriod;

  MenstrualController(
    this._getOverview,
    this._addPeriod,
    this._updatePeriod,
    this._deletePeriod,
  );

  MenstrualStatus status = MenstrualStatus.loading;
  MenstrualError? error;
  MenstrualOverview? overview;

  Future<void> load(String idToken) async {
    status = MenstrualStatus.loading;
    error = null;
    notifyListeners();

    try {
      overview = await _getOverview(idToken);
      status = MenstrualStatus.loaded;
    } on MenstrualReauthenticationRequired {
      status = MenstrualStatus.needsReauth;
    } on MenstrualFetchFailure {
      status = MenstrualStatus.error;
      error = MenstrualError.fetchFailed;
    } catch (_) {
      status = MenstrualStatus.error;
      error = MenstrualError.unknown;
    }
    notifyListeners();
  }

  /// Records a period, then re-reads the overview.
  Future<void> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) => _apply(
    idToken,
    () => _addPeriod(idToken, startDate: startDate, endDate: endDate),
  );

  /// Partially updates a period (change dates / clear end date), then re-reads.
  Future<void> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) => _apply(
    idToken,
    () => _updatePeriod(
      idToken,
      id,
      startDate: startDate,
      endDate: endDate,
      clearEndDate: clearEndDate,
    ),
  );

  /// Deletes a period, then re-reads the overview.
  Future<void> deletePeriod(String idToken, String id) =>
      _apply(idToken, () => _deletePeriod(idToken, id));

  Future<void> _apply(
    String idToken,
    Future<void> Function() mutation,
  ) async {
    status = MenstrualStatus.saving;
    notifyListeners();

    try {
      await mutation();
      await load(idToken);
      return;
    } on MenstrualReauthenticationRequired {
      status = MenstrualStatus.needsReauth;
    } on MenstrualFetchFailure {
      status = MenstrualStatus.error;
      error = MenstrualError.fetchFailed;
    } catch (_) {
      status = MenstrualStatus.error;
      error = MenstrualError.unknown;
    }
    notifyListeners();
  }
}
