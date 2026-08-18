import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/infrastructure/http_body_profile_repository.dart';
import 'package:life_os/contexts/finance/application/list_finance_budgets.dart';
import 'package:life_os/contexts/finance/application/networth_use_cases.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/infrastructure/http_daily_target_repository.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/infrastructure/http_menstrual_repository.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/infrastructure/http_split_repository.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/infrastructure/http_vitals_repository.dart';
import 'package:life_os/shared/config.dart';
import 'package:life_os/shared/http/timeout_client.dart';

/// The whole point of this guard is that the requests are real ones going
/// through real repositories over a real [TimeoutClient] — `test/support`'s
/// fake dashboard repositories never touch an `http.Client`, so a dashboard
/// wired with them would report the error state no matter what the timeout
/// did (or didn't) do.
HomeDashboardController _dashboardOver(http.Client client) {
  const baseUrl = 'https://example.test';
  final finance = HttpFinanceRepository(baseUrl: baseUrl, client: client);
  return HomeDashboardController(
    GetWeightGoal(HttpBodyProfileRepository(baseUrl: baseUrl, client: client)),
    GetVitalsTrends(HttpVitalsRepository(baseUrl: baseUrl, client: client)),
    GetMenstrualOverview(
      HttpMenstrualRepository(baseUrl: baseUrl, client: client),
    ),
    ListFinanceBudgets(finance),
    GetMonthlyNetWorth(finance),
    GetBalances(HttpSplitRepository(baseUrl: baseUrl, client: client)),
    GetDailyTargetWithRemaining(
      HttpDailyTargetRepository(baseUrl: baseUrl, client: client),
    ),
  );
}

void main() {
  // The 2026-08-17 incident: the backend stopped answering and the home
  // dashboard sat on its spinner indefinitely, because nothing downstream of
  // `http.Client` had a deadline. The recovery the user needs is the ordinary
  // error state with its retry button, and it must arrive on its own.
  test('a backend that never answers lands the dashboard in error', () {
    fakeAsync((async) {
      final controller = _dashboardOver(
        TimeoutClient(
          MockClient((_) => Completer<http.Response>().future),
          httpRequestTimeout,
        ),
      );

      controller.load('id-token', DateTime(2026, 8, 17, 21, 40));

      async.elapse(httpRequestTimeout - const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(controller.status, HomeDashboardStatus.loading);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(controller.status, HomeDashboardStatus.error);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
