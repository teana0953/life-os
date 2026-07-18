import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;
  DailyTargetWithRemaining? afterSetTarget;
  double? receivedBaseStaple;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return afterSetTarget ?? targetToReturn!;
  }

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) async {
    receivedBaseStaple = baseStaple;
    return DailyTarget.fromJson({
      'id': 'target-1',
      'day': day,
      'base_staple': baseStaple,
      'base_meat': baseMeat,
      'base_fruit': baseFruit,
      'base_veg': baseVeg,
      'bonus_staple': bonusStaple ?? 0,
      'bonus_meat': bonusMeat ?? 0,
      'bonus_fruit': bonusFruit ?? 0,
      'bonus_veg': bonusVeg ?? 0,
    });
  }
}

DailyTargetWithRemaining _target({double baseStaple = 0, double loggedStaple = 9}) =>
    DailyTargetWithRemaining.fromJson({
      'day': '2026-07-18',
      'base': {'staple': baseStaple, 'meat': 8, 'fruit': 5, 'veg': 2},
      'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': baseStaple, 'meat': 8, 'fruit': 5, 'veg': 2},
      'logged': {'staple': loggedStaple, 'meat': 3, 'fruit': 1, 'veg': 0},
      'remaining': {
        'staple': baseStaple - loggedStaple,
        'meat': 5,
        'fruit': 4,
        'veg': 2,
      },
    });

void main() {
  group('DailyTargetScreen', () {
    testWidgets('tapping the staple increment control raises the draft and remaining computes', (
      tester,
    ) async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = _target(baseStaple: 11.5, loggedStaple: 9);
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );
      await controller.load('token-123', '2026-07-18');
      repository.afterSetTarget = _target(baseStaple: 12, loggedStaple: 9);

      await tester.pumpWidget(
        l10nTestApp(
          home: DailyTargetScreen(
            controller: controller,
            idToken: 'token-123',
            day: '2026-07-18',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('daily-target-staple-increment')));
      await tester.pump();

      expect(controller.draftBaseStaple, 12);

      await tester.tap(find.byKey(const Key('save-target-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedBaseStaple, 12);
      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietRemainingOfCategory(3)), findsOneWidget);
    });

    testWidgets('calls onSaved after a successful save', (tester) async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = _target(baseStaple: 12, loggedStaple: 9);
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );
      await controller.load('token-123', '2026-07-18');
      var savedCalled = false;

      await tester.pumpWidget(
        l10nTestApp(
          home: DailyTargetScreen(
            controller: controller,
            idToken: 'token-123',
            day: '2026-07-18',
            onSaved: () => savedCalled = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('save-target-button')));
      await tester.pumpAndSettle();

      expect(savedCalled, isTrue);
    });
  });
}
