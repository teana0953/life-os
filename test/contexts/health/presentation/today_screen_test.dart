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
import 'package:life_os/contexts/health/domain/portions.dart';
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
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
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

Map<String, dynamic> _entryJson({
  required String meal,
  required String eatenAt,
  String? name = 'food',
  double staple = 1,
  double meat = 0,
  double fruit = 0,
  double veg = 0,
}) => {
  'id': 'entry-$meal',
  'day': '2026-07-18',
  'meal': meal,
  'name': name,
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 10,
  'protein_g': 2,
  'fat_g': 1,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 60,
  'staple': staple,
  'meat': meat,
  'fruit': fruit,
  'veg': veg,
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
    testWidgets('renders each meal group time using the injected local-time conversion', (
      tester,
    ) async {
      // Two entries out of listed order; the earlier one (00:10 UTC) must
      // win as the group's time, not entries.first (09:00 UTC).
      final dayLog = DayDietLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          {
            'meal': 'breakfast',
            'entries': [
              _entryJson(meal: 'breakfast', eatenAt: '2026-07-18T09:00:00.000Z'),
              _entryJson(meal: 'breakfast', eatenAt: '2026-07-18T00:10:00.000Z'),
            ],
          },
        ],
        'totals': {'carbG': 20, 'proteinG': 4, 'fatG': 2, 'sugarG': 0, 'fiberG': 0, 'kcal': 120},
      });
      final dietLogRepository = FakeDietLogRepository()..logToReturn = dayLog;
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayDietLog(dietLogRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );
      await controller.load('token-123', '2026-07-18');

      await tester.pumpWidget(
        l10nTestApp(
          home: TodayScreen(
            controller: controller,
            signOut: SignOut(FakeAuthRepository()),
            // Simulate a local timezone 8 hours ahead of UTC, independent of
            // the host machine's real timezone: a naive implementation that
            // skips `.toLocal()` (or uses `entries.first` instead of `min`)
            // would show 09:00 or 00:10 instead of 08:10.
            toLocalTime: (utc) => utc.add(const Duration(hours: 8)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('08:10'), findsOneWidget);
    });

    testWidgets('shows meal cards labeled with an emoji per standard meal, and a fallback for snacks', (
      tester,
    ) async {
      final dayLog = DayDietLog.fromJson({
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
          {
            'meal': 'dinner',
            'entries': [_entryJson(meal: 'dinner', eatenAt: '2026-07-18T18:00:00.000Z')],
          },
          {
            'meal': 'snack',
            'entries': [_entryJson(meal: 'snack', eatenAt: '2026-07-18T15:00:00.000Z')],
          },
        ],
        'totals': {'carbG': 40, 'proteinG': 8, 'fatG': 4, 'sugarG': 0, 'fiberG': 0, 'kcal': 240},
      });
      final dietLogRepository = FakeDietLogRepository()..logToReturn = dayLog;
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayDietLog(dietLogRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );
      await controller.load('token-123', '2026-07-18');

      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpToday(tester, controller);

      expect(find.text('🌅'), findsOneWidget);
      expect(find.text('🍱'), findsOneWidget);
      expect(find.text('🌙'), findsOneWidget);
      expect(find.text('🍎'), findsOneWidget);
    });

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

    testWidgets(
      'a logged food shows a "meat 1" portion pill and no lone "0" staple value',
      (tester) async {
        final dayLog = DayDietLog.fromJson({
          'day': '2026-07-18',
          'meals': [
            {
              'meal': 'breakfast',
              'entries': [
                _entryJson(
                  meal: 'breakfast',
                  eatenAt: '2026-07-18T08:00:00.000Z',
                  name: '蛋',
                  staple: 0,
                  meat: 1,
                ),
              ],
            },
          ],
          'totals': {'carbG': 10, 'proteinG': 2, 'fatG': 1, 'sugarG': 0, 'fiberG': 0, 'kcal': 60},
        });
        final dietLogRepository = FakeDietLogRepository()..logToReturn = dayLog;
        final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
        final controller = TodayController(
          GetDayDietLog(dietLogRepository),
          GetDailyTargetWithRemaining(targetRepository),
        );
        await controller.load('token-123', '2026-07-18');

        await _pumpToday(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text('${loc.dietCategoryMeat} 1'), findsOneWidget);
        expect(find.text('${loc.dietCategoryStaple} 0'), findsNothing);
      },
    );

    testWidgets(
      'a nameless (manual) entry shows a localized fallback title instead of a blank one',
      (tester) async {
        final dayLog = DayDietLog.fromJson({
          'day': '2026-07-18',
          'meals': [
            {
              'meal': 'breakfast',
              'entries': [
                _entryJson(
                  meal: 'breakfast',
                  eatenAt: '2026-07-18T08:00:00.000Z',
                  name: null,
                  staple: 0,
                  meat: 1,
                ),
              ],
            },
          ],
          'totals': {'carbG': 10, 'proteinG': 2, 'fatG': 1, 'sugarG': 0, 'fiberG': 0, 'kcal': 60},
        });
        final dietLogRepository = FakeDietLogRepository()..logToReturn = dayLog;
        final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
        final controller = TodayController(
          GetDayDietLog(dietLogRepository),
          GetDailyTargetWithRemaining(targetRepository),
        );
        await controller.load('token-123', '2026-07-18');

        await _pumpToday(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.dietManualEntryFallbackName), findsOneWidget);
      },
    );

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
