import 'package:flutter/foundation.dart';

import '../application/get_day_diet_log.dart';
import '../application/get_daily_target_with_remaining.dart';
import '../domain/day_diet_log.dart';
import '../domain/daily_target.dart';
import '../domain/diet_exceptions.dart';

enum TodayStatus { loading, loaded, error, needsReauth }

/// Reasons loading today's diet data can fail, as understood by
/// [TodayScreen]. [TodayController] has no [BuildContext] and so cannot hold
/// a localized message directly — the screen maps this to text at build
/// time.
enum TodayError { fetchFailed, unknown }

/// Drives the Today section: the day's diet log (meals in eaten order) and
/// per-category portion progress against the day's target.
class TodayController extends ChangeNotifier {
  final GetDayDietLog _getDayDietLog;
  final GetDailyTargetWithRemaining _getDailyTargetWithRemaining;

  TodayController(this._getDayDietLog, this._getDailyTargetWithRemaining);

  TodayStatus status = TodayStatus.loading;
  DayDietLog? dayLog;
  DailyTargetWithRemaining? target;
  TodayError? error;

  Future<void> load(String idToken, String day) async {
    status = TodayStatus.loading;
    error = null;
    notifyListeners();

    try {
      dayLog = await _getDayDietLog(idToken, day);
      target = await _getDailyTargetWithRemaining(idToken, day);
      status = TodayStatus.loaded;
    } on DietReauthenticationRequired {
      status = TodayStatus.needsReauth;
    } on DietFetchFailure {
      status = TodayStatus.error;
      error = TodayError.fetchFailed;
    } catch (_) {
      status = TodayStatus.error;
      error = TodayError.unknown;
    }
    notifyListeners();
  }
}
