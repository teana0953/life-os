import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/health/presentation/today_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeDietLogRepository implements DietLogRepository {
  DayDietLog? logToReturn;
  Object? errorToThrow;

  @override
  Future<FoodEntry> logFromDictionary(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    if (errorToThrow != null) throw errorToThrow!;
    return logToReturn!;
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}
}

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async =>
      targetToReturn!;

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
    throw UnimplementedError();
  }
}

class FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Map<String, dynamic> _entryJson({required String meal, required String eatenAt}) => {
  'id': 'entry-$meal',
  'day': '2026-07-18',
  'meal': meal,
  'name': 'food',
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 10,
  'protein_g': 2,
  'fat_g': 1,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 60,
  'staple': 1,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'eaten_at': eatenAt,
  'logged_at': eatenAt,
};

DayDietLog _dayLog() => DayDietLog.fromJson({
  'day': '2026-07-18',
  'meals': [
    {
      'meal': 'breakfast',
      'entries': [_entryJson(meal: 'breakfast', eatenAt: '2026-07-18T08:00:00.000Z')],
    },
    {
      'meal': 'lunch',
      'entries': [_entryJson(meal: 'lunch', eatenAt: '2026-07-18T12:30:00.000Z')],
    },
  ],
  'totals': {'carbG': 20, 'proteinG': 4, 'fatG': 2, 'sugarG': 0, 'fiberG': 0, 'kcal': 120},
});

DailyTargetWithRemaining _target() => DailyTargetWithRemaining.fromJson({
  'day': '2026-07-18',
  'base': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
  'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
  'effective': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
  'logged': {'staple': 9, 'meat': 3, 'fruit': 1, 'veg': 0},
  'remaining': {'staple': 3, 'meat': 3, 'fruit': 3, 'veg': 3},
});

Future<void> _pumpToday(
  WidgetTester tester,
  TodayController controller, {
  AuthRepository? authRepository,
}) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: TodayScreen(
        controller: controller,
        signOut: SignOut(authRepository ?? FakeAuthRepository()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('TodayScreen', () {
    testWidgets('shows meals in eaten order: breakfast before lunch', (
      tester,
    ) async {
      final dietLogRepository = FakeDietLogRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayDietLog(dietLogRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );
      await controller.load('token-123', '2026-07-18');

      await _pumpToday(tester, controller);

      final breakfastLoc = lookupAppLocalizations(const Locale('en')).dietMealBreakfast;
      final lunchLoc = lookupAppLocalizations(const Locale('en')).dietMealLunch;
      final breakfastPos = tester.getTopLeft(find.text(breakfastLoc)).dy;
      final lunchPos = tester.getTopLeft(find.text(lunchLoc)).dy;
      expect(breakfastPos, lessThan(lunchPos));
    });

    testWidgets('shows staple progress as 9 of 12', (tester) async {
      final dietLogRepository = FakeDietLogRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayDietLog(dietLogRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );
      await controller.load('token-123', '2026-07-18');

      await _pumpToday(tester, controller);

      final expected = lookupAppLocalizations(
        const Locale('en'),
      ).dietProgressOfTarget(9, 12);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('shows an error state and a sign-out option when loading fails', (
      tester,
    ) async {
      final dietLogRepository = FakeDietLogRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayDietLog(dietLogRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );
      await controller.load('token-123', '2026-07-18');
      final authRepository = FakeAuthRepository();

      await _pumpToday(tester, controller, authRepository: authRepository);

      expect(find.byKey(const Key('today-error-message')), findsOneWidget);
      await tester.tap(find.byKey(const Key('today-sign-out-button')));
      await tester.pumpAndSettle();
      expect(authRepository.signOutCalled, isTrue);
    });
  });
}
