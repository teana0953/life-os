import 'dart:async';
import 'dart:convert';

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
import 'package:life_os/shared/screen_batch/screen_batch_repository.dart';

import '../../../shared/screen_batch/batch_fixtures.dart';

const _baseUrl = 'https://api.test';

/// The seven granular paths a full round used to hit.
const _granularPaths = [
  '/api/weight-goal',
  '/api/vitals/range',
  '/api/menstrual',
  '/api/finance/budgets',
  '/api/finance/networth',
  '/api/split/balances',
  '/api/daily-target',
];

class _Rig {
  final List<Uri> requests = [];
  late final HomeDashboardController controller;

  /// Set between rounds to hold the NEXT batch request open. Mutable rather
  /// than a constructor argument so a test can let one round land and then
  /// hold the next: a gate armed from construction would hang the very first
  /// load, and a zero-delay fake would close the window before the test
  /// could act inside it.
  Completer<void>? summaryGate;

  List<String> get paths => requests.map((u) => u.path).toList();

  _Rig({
    Map<String, dynamic>? summaryBody,
    int summaryStatus = 200,
    Object? summaryThrows,
    Completer<void>? weightGoalGate,
  }) {
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path == '/api/home-summary') {
        final gate = summaryGate;
        if (gate != null) await gate.future;
        if (summaryThrows != null) throw summaryThrows;
        if (summaryStatus != 200) {
          return http.Response('{"error":"boom"}', summaryStatus);
        }
        return http.Response(
          jsonEncode(summaryBody ?? homeSummaryBody()),
          200,
        );
      }
      if (request.url.path == '/api/weight-goal') {
        if (weightGoalGate != null) await weightGoalGate.future;
        return http.Response(
          jsonEncode({...weightGoalPayload, 'current_weight_kg': 55.5}),
          200,
        );
      }
      return _granularResponse(request.url);
    });

    final finance = HttpFinanceRepository(baseUrl: _baseUrl, client: client);
    controller = HomeDashboardController(
      HttpScreenBatchRepository(baseUrl: _baseUrl, client: client),
      GetWeightGoal(
        HttpBodyProfileRepository(baseUrl: _baseUrl, client: client),
      ),
      GetVitalsTrends(HttpVitalsRepository(baseUrl: _baseUrl, client: client)),
      GetMenstrualOverview(
        HttpMenstrualRepository(baseUrl: _baseUrl, client: client),
      ),
      ListFinanceBudgets(finance),
      GetMonthlyNetWorth(finance),
      GetBalances(HttpSplitRepository(baseUrl: _baseUrl, client: client)),
      GetDailyTargetWithRemaining(
        HttpDailyTargetRepository(baseUrl: _baseUrl, client: client),
      ),
    );
  }
}

http.Response _granularResponse(Uri url) => switch (url.path) {
  '/api/vitals/range' => http.Response(
    jsonEncode(
      vitalsRangePayload(
        from: url.queryParameters['from']!,
        to: url.queryParameters['to']!,
      ),
    ),
    200,
  ),
  '/api/menstrual' => http.Response(jsonEncode(menstrualPayload), 200),
  '/api/finance/budgets' => http.Response(
    jsonEncode(budgetsPayload(url.queryParameters['month']!)),
    200,
  ),
  '/api/finance/networth' => http.Response(
    jsonEncode(netWorthPayload(url.queryParameters['month']!)),
    200,
  ),
  '/api/split/balances' => http.Response(
    jsonEncode(splitBalancesPayload),
    200,
  ),
  '/api/daily-target' => http.Response(
    jsonEncode(dailyTargetPayload(url.queryParameters['day']!)),
    200,
  ),
  _ => http.Response('{"error":"unexpected ${url.path}"}', 404),
};

void main() {
  final now = DateTime(2026, 8, 20, 7);

  group('one request replaces seven', () {
    test('a full round records exactly one request, to /api/home-summary', () async {
      final rig = _Rig();

      await rig.controller.load('token', now);

      expect(rig.paths, ['/api/home-summary']);
      for (final path in _granularPaths) {
        expect(rig.paths, isNot(contains(path)));
      }
    });

    // 07:00 at UTC+8 is the previous day in UTC. Run under both
    // `flutter test` and `TZ=UTC flutter test`.
    test('day is the local calendar day and trend_days is the year lookback', () async {
      final rig = _Rig();

      await rig.controller.load('token', now);

      final query = rig.requests.single.queryParameters;
      expect(query['day'], '2026-08-20');
      expect(query['trend_days'], '366');
    });

    test('the derived arms are reduced from their sections', () async {
      final rig = _Rig();

      await rig.controller.load('token', now);

      final data = rig.controller.data!;
      // The most recent systolic/diastolic pair in the series, not the first.
      expect(data.bloodPressure.value!.systolic, 124);
      expect(data.bloodPressure.value!.diastolic, 81);
      // The null-category (overall) budget, not the category one.
      expect(data.overallBudget.value!.id, 'b-all');
      expect(data.netWorth.value!.netWorth, 80000);
      expect(data.splitBalances.value!.single.userId, 'friend-1');
      expect(data.dailyTarget.value!.day, '2026-08-20');
      expect(rig.controller.status, HomeDashboardStatus.loaded);
      expect(rig.controller.lastLoadedAt, now);
    });

    test('one ok:false section marks that arm alone and still advances the '
        'stamp', () async {
      final body = homeSummaryBody()..['net_worth'] = failedSection();
      final rig = _Rig(summaryBody: body);

      await rig.controller.load('token', now);

      expect(rig.controller.status, HomeDashboardStatus.loaded);
      expect(rig.controller.lastLoadedAt, now);
      expect(rig.controller.data!.netWorth.status, ArmStatus.failed);
      expect(rig.controller.data!.weightGoal.status, ArmStatus.loaded);
    });
  });

  group('total failure', () {
    test('a first-ever round that fails as a whole shows the whole-dashboard '
        'card', () async {
      final rig = _Rig(summaryThrows: const _SocketFailure());

      await rig.controller.load('token', now);

      expect(rig.controller.status, HomeDashboardStatus.error);
      expect(rig.controller.data, isNull);
      expect(rig.controller.lastLoadedAt, isNull);
    });

    test('a 401 is a failed round, not a re-auth state this screen does not '
        'have', () async {
      final rig = _Rig(summaryStatus: 401);

      await rig.controller.load('token', now);

      expect(rig.controller.status, HomeDashboardStatus.error);
      expect(rig.controller.data, isNull);
    });

    test('every section ok:false on a 200 fails all seven arms', () async {
      final body = {
        for (final key in homeSummaryBody().keys) key: failedSection(),
      };
      final rig = _Rig(summaryBody: body);

      await rig.controller.load('token', now);

      expect(rig.controller.status, HomeDashboardStatus.error);
      expect(rig.controller.data, isNull);
    });
  });

  group('narrower loads stay granular (Invariant W preserved)', () {
    test('a per-tile retry requests its own endpoint, never the batch', () async {
      final rig = _Rig();
      await rig.controller.load('token', now);
      rig.requests.clear();

      await rig.controller.retryArm(DashboardArm.weightGoal, 'token', now);

      expect(rig.paths, ['/api/weight-goal']);
      expect(rig.controller.data!.weightGoal.value!.currentWeightKg, 55.5);
    });

    // The retry started AFTER the round, so its answer is the arm's answer
    // whatever the arrival order — and the round's other six still land.
    test('a retry started mid-round wins its arm while the other six land', () async {
      final rig = _Rig();
      // A landed round first: with no `data` the screen shows the
      // whole-dashboard card, whose retry is `load`, not a tile retry.
      await rig.controller.load('token', now);
      final summaryGate = Completer<void>();
      rig.summaryGate = summaryGate;

      final round = rig.controller.load('token', now);
      final retry = rig.controller.retryArm(
        DashboardArm.weightGoal,
        'token',
        now,
      );
      await retry;
      summaryGate.complete();
      await round;

      expect(rig.controller.data!.weightGoal.value!.currentWeightKg, 55.5);
      expect(rig.controller.data!.netWorth.value!.netWorth, 80000);
    });

    test('reset() mid-round discards the response', () async {
      final rig = _Rig();
      final summaryGate = Completer<void>();
      rig.summaryGate = summaryGate;

      final round = rig.controller.load('token', now);
      rig.controller.reset();
      summaryGate.complete();
      await round;

      expect(rig.controller.data, isNull);
      expect(rig.controller.status, HomeDashboardStatus.idle);
      expect(rig.controller.lastLoadedAt, isNull);
    });
  });
}

class _SocketFailure implements Exception {
  const _SocketFailure();
}
