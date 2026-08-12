import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/finance/application/list_finance_budgets.dart';
import 'package:life_os/contexts/finance/application/networth_use_cases.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';

import 'dashboard_repositories_fake.dart';

void main() {
  HomeDashboardController controllerFor(FakeDashboardRepositories repos) =>
      HomeDashboardController(
        GetWeightGoal(repos),
        GetVitalsTrends(repos),
        GetMenstrualOverview(repos),
        ListFinanceBudgets(repos),
        GetMonthlyNetWorth(repos),
        GetBalances(repos),
      );

  test('a successful load stamps lastLoadedAt with the `now` it was given', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);

    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

    expect(controller.status, HomeDashboardStatus.loaded);
    expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 9, 30));
  });

  test('a failed load leaves lastLoadedAt exactly where it was', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);
    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

    repos.fail = true;
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    expect(controller.status, HomeDashboardStatus.error);
    expect(
      controller.lastLoadedAt,
      DateTime(2026, 1, 1, 9, 30),
      reason: 'a failed round must not claim the data was just refreshed',
    );
  });

  test('a failed load keeps the data already on hand', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);
    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
    final loaded = controller.data;

    repos.fail = true;
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    expect(controller.data, same(loaded));
  });

  test(
    'reset() clears lastLoadedAt along with the data (sign-out leaves no '
    'per-user state behind)',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
      expect(controller.lastLoadedAt, isNotNull);

      controller.reset();

      expect(controller.data, isNull);
      expect(controller.status, HomeDashboardStatus.idle);
      expect(controller.lastLoadedAt, isNull);
    },
  );

  test(
    'a load started while one is already in flight rides the same round '
    'instead of firing a second fan-out',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      final gate = Completer<void>();
      repos.gate = gate;

      var firstSettled = false;
      var secondSettled = false;
      unawaited(
        controller.load('tok', DateTime(2026, 1, 1, 9, 30)).then((_) {
          firstSettled = true;
        }),
      );
      // Let the fan-out reach the gate.
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1);

      unawaited(
        controller.load('tok', DateTime(2026, 1, 1, 9, 31)).then((_) {
          secondSettled = true;
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1, reason: 'the second call must not start a round');
      expect(firstSettled, isFalse);
      expect(secondSettled, isFalse);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(firstSettled, isTrue);
      expect(secondSettled, isTrue);
      expect(repos.rounds, 1);
      // The round that ran is the first one — its `now`, not the second call's.
      expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 9, 30));
    },
  );

  test('a later load runs normally once the in-flight one has finished', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);

    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    expect(repos.rounds, 2);
    expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 11, 45));
  });
}
