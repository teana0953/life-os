import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
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

  /// Applies the batched `vitals_trend` section, but only when it describes
  /// the span this card is showing *now* — returns whether it did.
  ///
  /// [requestedSpanDays] is the `trend_days` the round went out with. A span
  /// switched while the request was in flight makes the response describe a
  /// window the card no longer shows, and painting it would leave the
  /// selector saying one thing and the chart another; the caller loads this
  /// one card granularly instead.
  bool applyBatchSection(
    SectionOutcome<VitalsRange> section, {
    required int requestedSpanDays,
  }) {
    if (requestedSpanDays != spanDays) return false;
    error = null;
    switch (section) {
      case SectionOk<VitalsRange>(:final value):
        range = value;
        status = TrendStatus.loaded;
      case SectionUnavailable<VitalsRange>():
        status = TrendStatus.error;
        error = TrendError.fetchFailed;
      case SectionReauth<VitalsRange>():
        status = TrendStatus.needsReauth;
    }
    notifyListeners();
    return true;
  }

  /// Switches the span (7 / 30 / 90) and reloads.
  Future<void> setSpan(String idToken, int days) async {
    spanDays = days;
    await load(idToken);
  }
}
