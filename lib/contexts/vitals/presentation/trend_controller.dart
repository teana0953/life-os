import 'package:flutter/foundation.dart';

import '../application/get_vitals_trends.dart';
import '../domain/vitals_exceptions.dart';
import '../domain/vitals_series.dart';

enum TrendStatus { loading, loaded, error, needsReauth }

/// Reasons loading the trend range can fail, as understood by the trend card.
enum TrendError { fetchFailed, unknown }

/// Drives the dashboard trend card: loads the per-metric daily series for the
/// selected span (7 / 30 / 90 days, ending today) and reloads when the span
/// changes. The selected *metric* is card-local state (switching it only
/// re-plots, no reload); the span drives this controller. Mirrors the vitals /
/// exercise error classification.
class TrendController extends ChangeNotifier {
  final GetVitalsTrends _getVitalsTrends;

  /// Returns the current time; injectable so tests can pin the range. Only the
  /// date component is used.
  final DateTime Function() _clock;

  TrendController(this._getVitalsTrends, {DateTime Function() clock = DateTime.now})
    : _clock = clock;

  TrendStatus status = TrendStatus.loading;
  TrendError? error;
  VitalsRange? range;
  int spanDays = 30;

  /// Loads the range for the current [spanDays]: from = today − (spanDays − 1),
  /// to = today. Date arithmetic goes through UTC so a DST boundary can't shift
  /// the span by a day.
  Future<void> load(String idToken) async {
    status = TrendStatus.loading;
    error = null;
    notifyListeners();

    final now = _clock();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final fromUtc = todayUtc.subtract(Duration(days: spanDays - 1));
    final from = DateTime(fromUtc.year, fromUtc.month, fromUtc.day);
    final to = DateTime(todayUtc.year, todayUtc.month, todayUtc.day);

    try {
      range = await _getVitalsTrends(idToken, from, to);
      status = TrendStatus.loaded;
    } on VitalsReauthenticationRequired {
      status = TrendStatus.needsReauth;
    } on VitalsFetchFailure {
      status = TrendStatus.error;
      error = TrendError.fetchFailed;
    } catch (_) {
      status = TrendStatus.error;
      error = TrendError.unknown;
    }
    notifyListeners();
  }

  /// Switches the span (7 / 30 / 90) and reloads.
  Future<void> setSpan(String idToken, int days) async {
    spanDays = days;
    await load(idToken);
  }
}
