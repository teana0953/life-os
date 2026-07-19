import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/delete_entry.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/application/update_food_entry.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/diet_shell_screen.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_screen.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_screen.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_screen.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

class FakeDietLogRepository implements DietLogRepository {
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
    return FoodEntry.fromJson({
      'id': 'entry-1',
      'day': day,
      'meal': meal,
      'name': 'food',
      'photo_ref': null,
      'source': 'dict',
      'unclassified': false,
      'carb_g': 0,
      'protein_g': 0,
      'fat_g': 0,
      'sugar_g': 0,
      'fiber_g': 0,
      'kcal': 0,
      'staple': 0,
      'meat': 0,
      'fruit': 0,
      'veg': 0,
      'eaten_at': DateTime.now().toUtc().toIso8601String(),
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  int getDayLogCallCount = 0;
  final List<String> receivedDays = [];

  /// When set, `getDayLog` returns a single breakfast meal group holding
  /// this one entry (used by the edit-sheet tests); otherwise an empty log.
  Map<String, dynamic>? entryToLog;

  String? receivedMonth;
  List<String> loggedDaysToReturn = const [];
  Object? loggedDaysError;

  String? updatedEntryId;
  Portions? updatedPortions;
  String? deletedEntryId;

  @override
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
  }) async {
    return FoodEntry.fromJson({
      'id': 'manual-entry-1',
      'day': day,
      'meal': meal,
      'name': name,
      'photo_ref': null,
      'source': 'manual',
      'unclassified': false,
      'carb_g': 0,
      'protein_g': 0,
      'fat_g': 0,
      'sugar_g': 0,
      'fiber_g': 0,
      'kcal': 0,
      'staple': portions.staple,
      'meat': portions.meat,
      'fruit': portions.fruit,
      'veg': portions.veg,
      'eaten_at': eatenAt.toUtc().toIso8601String(),
      'logged_at': eatenAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    getDayLogCallCount++;
    receivedDays.add(day);
    final entry = entryToLog;
    return DayDietLog.fromJson({
      'day': day,
      'meals': entry == null
          ? []
          : [
              {'meal': 'breakfast', 'entries': [entry]},
            ],
      'totals': {'carbG': 0, 'proteinG': 0, 'fatG': 0, 'sugarG': 0, 'fiberG': 0, 'kcal': 0},
    });
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {
    deletedEntryId = entryId;
  }

  @override
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) async {
    updatedEntryId = entryId;
    updatedPortions = portions;
    return FoodEntry.fromJson({
      'id': entryId,
      'day': '2026-07-18',
      'meal': meal ?? 'breakfast',
      'name': name,
      'photo_ref': null,
      'source': 'manual',
      'unclassified': false,
      'carb_g': 0,
      'protein_g': 0,
      'fat_g': 0,
      'sugar_g': 0,
      'fiber_g': 0,
      'kcal': 0,
      'staple': portions?.staple ?? 0,
      'meat': portions?.meat ?? 0,
      'fruit': portions?.fruit ?? 0,
      'veg': portions?.veg ?? 0,
      'eaten_at': (eatenAt ?? DateTime.utc(2026, 7, 18, 8)).toUtc().toIso8601String(),
      'logged_at': DateTime.utc(2026, 7, 18, 8, 1).toIso8601String(),
    });
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    receivedMonth = month;
    if (loggedDaysError != null) throw loggedDaysError!;
    return loggedDaysToReturn;
  }
}

Map<String, dynamic> _shellEntryJson({
  String id = 'entry-1',
  String name = '雞腿便當',
  double staple = 3,
  double meat = 3,
}) => {
  'id': id,
  'day': '2026-07-18',
  'meal': 'breakfast',
  'name': name,
  'photo_ref': null,
  'source': 'manual',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': staple,
  'meat': meat,
  'fruit': 0,
  'veg': 0,
  'eaten_at': '2026-07-18T08:00:00.000Z',
  'logged_at': '2026-07-18T08:01:00.000Z',
};

class FakeDailyTargetRepository implements DailyTargetRepository {
  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return DailyTargetWithRemaining.fromJson({
      'day': day,
      'base': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'logged': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'remaining': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
    });
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
    throw UnimplementedError();
  }
}

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [
    FoodItem.fromJson({
      'id': 'rice-1',
      'owner_user_id': null,
      'name': '飯/1碗',
      'carb_g': 60,
      'protein_g': 4,
      'fat_g': 0.5,
      'sugar_g': 0,
      'fiber_g': 1,
      'kcal': 280,
      'staple': 4,
      'meat': 0,
      'fruit': 0,
      'veg': 0,
      'base_grams': null,
    }),
  ];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
}

Future<FakeDietLogRepository> _pumpShell(
  WidgetTester tester, {
  FakeDietLogRepository? dietLogRepository,
}) async {
  final resolvedDietLogRepository = dietLogRepository ?? FakeDietLogRepository();
  final dailyTargetRepository = FakeDailyTargetRepository();
  final foodDictionaryRepository = FakeFoodDictionaryRepository();

  await tester.pumpWidget(
    l10nTestApp(
      home: DietShellScreen(
        authRepository: FakeAuthRepository(),
        todayController: TodayController(
          GetDayDietLog(resolvedDietLogRepository),
          GetDailyTargetWithRemaining(dailyTargetRepository),
        ),
        dictionaryController: DictionaryController(
          SearchDictionary(foodDictionaryRepository),
          ListFavorites(foodDictionaryRepository),
          FavoriteFood(foodDictionaryRepository),
          UnfavoriteFood(foodDictionaryRepository),
        ),
        dailyTargetController: DailyTargetController(
          GetDailyTargetWithRemaining(dailyTargetRepository),
          SetDailyTarget(dailyTargetRepository),
        ),
        logEntryController: LogEntryController(
          LogFoodFromDictionary(resolvedDietLogRepository),
        ),
        manualEntryController: ManualEntryController(
          LogManualEntry(resolvedDietLogRepository),
        ),
        editEntryController: EditEntryController(
          UpdateFoodEntry(resolvedDietLogRepository),
          DeleteEntry(resolvedDietLogRepository),
        ),
        getLoggedDays: GetLoggedDays(resolvedDietLogRepository),
        clock: () => DateTime.utc(2026, 7, 18, 9),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return resolvedDietLogRepository;
}

void main() {
  group('DietShellScreen', () {
    testWidgets('shows the Today section by default', (tester) async {
      await _pumpShell(tester);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietTabToday), findsWidgets);
    });

    testWidgets('switching to Dictionary shows the dictionary section', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabDictionary));
      await tester.pumpAndSettle();

      expect(find.text('飯/1碗'), findsOneWidget);
    });

    testWidgets('switching to Target shows the daily target section', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabTarget));
      await tester.pumpAndSettle();

      expect(find.text(loc.dietSetTargetTitle), findsOneWidget);
    });

    testWidgets('selecting a dictionary item opens the log-entry screen', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabDictionary));
      await tester.pumpAndSettle();
      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(find.byType(LogEntryScreen), findsOneWidget);
    });

    testWidgets(
      'the manual-entry affordance on Dictionary opens the manual-entry screen',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.text(loc.dietTabDictionary));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('dictionary-manual-entry-button')));
        await tester.pumpAndSettle();

        expect(find.byType(ManualEntryScreen), findsOneWidget);
      },
    );

    testWidgets(
      'saving a manual entry reloads Today',
      (tester) async {
        final dietLogRepository = await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final loadsBeforeSave = dietLogRepository.getDayLogCallCount;

        await tester.tap(find.text(loc.dietTabDictionary));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('dictionary-manual-entry-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('manual-portion-staple-field')),
          '1',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('manual-save-button')));
        await tester.pumpAndSettle();

        expect(find.byType(ManualEntryScreen), findsNothing);
        expect(dietLogRepository.getDayLogCallCount, greaterThan(loadsBeforeSave));
      },
    );
  });

  group('DietShellScreen day navigation', () {
    testWidgets(
      'the previous-day control reloads the prior day and shows "Yesterday"',
      (tester) async {
        final dietLogRepository = await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        expect(dietLogRepository.receivedDays.last, '2026-07-17');
        expect(find.text(loc.dietDayYesterday), findsOneWidget);
      },
    );

    testWidgets(
      'the next-day control is disabled on today and re-enables after going back',
      (tester) async {
        final dietLogRepository = await _pumpShell(tester);

        var nextButton = tester.widget<IconButton>(
          find.byKey(const Key('day-nav-next')),
        );
        expect(nextButton.onPressed, isNull);

        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        nextButton = tester.widget<IconButton>(
          find.byKey(const Key('day-nav-next')),
        );
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(find.byKey(const Key('day-nav-next')));
        await tester.pumpAndSettle();

        expect(dietLogRepository.receivedDays.last, '2026-07-18');
        nextButton = tester.widget<IconButton>(
          find.byKey(const Key('day-nav-next')),
        );
        expect(nextButton.onPressed, isNull);
      },
    );

    testWidgets(
      'day navigation and the calendar-open button expose localized tooltips',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(
          tester.widget<IconButton>(find.byKey(const Key('day-nav-previous'))).tooltip,
          loc.dietDayPrevTooltip,
        );
        expect(
          tester.widget<IconButton>(find.byKey(const Key('day-nav-next'))).tooltip,
          loc.dietDayNextTooltip,
        );
        expect(
          tester.widget<IconButton>(find.byKey(const Key('day-nav-calendar'))).tooltip,
          loc.dietCalendarOpenTooltip,
        );
      },
    );

    testWidgets(
      'day navigation correctly rolls a year boundary using pure calendar-date arithmetic',
      (tester) async {
        // Regression check for the DST fix: the previous-day/next-day
        // handlers now use `DateUtils.addDaysToDate` (year/month/day
        // component arithmetic) instead of `Duration(days: 1)` on an
        // absolute instant. Crossing Dec 31 -> Jan 1 exercises the
        // month/year rollover the same code path relies on; a naive
        // reimplementation that dropped back to `Duration` math would still
        // pass this on most machines (this repo's CI runs in UTC, so it
        // can't reproduce an actual DST transition), but this at least
        // pins the rollover behavior of the date-component arithmetic.
        final dietLogRepository = FakeDietLogRepository();
        final dailyTargetRepository = FakeDailyTargetRepository();
        final foodDictionaryRepository = FakeFoodDictionaryRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: DietShellScreen(
              authRepository: FakeAuthRepository(),
              todayController: TodayController(
                GetDayDietLog(dietLogRepository),
                GetDailyTargetWithRemaining(dailyTargetRepository),
              ),
              dictionaryController: DictionaryController(
                SearchDictionary(foodDictionaryRepository),
                ListFavorites(foodDictionaryRepository),
                FavoriteFood(foodDictionaryRepository),
                UnfavoriteFood(foodDictionaryRepository),
              ),
              dailyTargetController: DailyTargetController(
                GetDailyTargetWithRemaining(dailyTargetRepository),
                SetDailyTarget(dailyTargetRepository),
              ),
              logEntryController: LogEntryController(
                LogFoodFromDictionary(dietLogRepository),
              ),
              manualEntryController: ManualEntryController(
                LogManualEntry(dietLogRepository),
              ),
              editEntryController: EditEntryController(
                UpdateFoodEntry(dietLogRepository),
                DeleteEntry(dietLogRepository),
              ),
              getLoggedDays: GetLoggedDays(dietLogRepository),
              clock: () => DateTime.utc(2027, 1, 1, 9),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        expect(dietLogRepository.receivedDays.last, '2026-12-31');
      },
    );
  });

  group('DietShellScreen calendar', () {
    testWidgets(
      'opening the calendar marks logged days and picking one changes the view',
      (tester) async {
        final dietLogRepository = FakeDietLogRepository()
          ..loggedDaysToReturn = ['2026-07-15'];
        await _pumpShell(tester, dietLogRepository: dietLogRepository);

        await tester.tap(find.byKey(const Key('day-nav-calendar')));
        await tester.pumpAndSettle();

        expect(dietLogRepository.receivedMonth, '2026-07');
        expect(
          find.byKey(const Key('calendar-day-dot-2026-07-15')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('calendar-day-dot-2026-07-10')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('calendar-day-2026-07-15')));
        await tester.pumpAndSettle();

        expect(dietLogRepository.receivedDays.last, '2026-07-15');
        expect(find.byKey(const Key('calendar-close-button')), findsNothing);
      },
    );

    testWidgets('future days in the calendar are not selectable', (
      tester,
    ) async {
      final dietLogRepository = await _pumpShell(tester);

      await tester.tap(find.byKey(const Key('day-nav-calendar')));
      await tester.pumpAndSettle();
      final daysBefore = dietLogRepository.receivedDays.length;

      await tester.tap(find.byKey(const Key('calendar-day-2026-07-19')));
      await tester.pumpAndSettle();

      // Still open (a tap on a disabled cell doesn't pop the dialog) and no
      // new day was loaded.
      expect(find.byKey(const Key('calendar-close-button')), findsOneWidget);
      expect(dietLogRepository.receivedDays.length, daysBefore);
    });

    testWidgets('a failure to load logged days still leaves the calendar usable', (
      tester,
    ) async {
      final dietLogRepository = FakeDietLogRepository()
        ..loggedDaysError = Exception('boom');
      await _pumpShell(tester, dietLogRepository: dietLogRepository);

      await tester.tap(find.byKey(const Key('day-nav-calendar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-day-2026-07-10')), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-day-2026-07-10')));
      await tester.pumpAndSettle();

      expect(dietLogRepository.receivedDays.last, '2026-07-10');
    });

    testWidgets(
      'today and the viewed (selected) day get distinct, overlappable markers',
      (tester) async {
        await _pumpShell(tester);
        // Pinned clock's "today" is 2026-07-18; move the viewed day back one
        // so today and selected are two different cells.
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('day-nav-calendar')));
        await tester.pumpAndSettle();

        final theme = Theme.of(
          tester.element(find.byKey(const Key('calendar-day-marker-2026-07-18'))),
        );

        final todayMarker = tester.widget<Container>(
          find.byKey(const Key('calendar-day-marker-2026-07-18')),
        );
        final todayDecoration = todayMarker.decoration as BoxDecoration;
        expect(todayDecoration.border, isNotNull);
        expect(todayDecoration.color, isNull);

        final selectedMarker = tester.widget<Container>(
          find.byKey(const Key('calendar-day-marker-2026-07-17')),
        );
        final selectedDecoration = selectedMarker.decoration as BoxDecoration;
        expect(selectedDecoration.color, theme.colorScheme.primary);
        expect(selectedDecoration.border, isNull);
      },
    );

    testWidgets(
      'viewing today shows both the today ring and the selected fill on the same cell',
      (tester) async {
        await _pumpShell(tester);

        await tester.tap(find.byKey(const Key('day-nav-calendar')));
        await tester.pumpAndSettle();

        final theme = Theme.of(
          tester.element(find.byKey(const Key('calendar-day-marker-2026-07-18'))),
        );
        final marker = tester.widget<Container>(
          find.byKey(const Key('calendar-day-marker-2026-07-18')),
        );
        final decoration = marker.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        expect(decoration.color, theme.colorScheme.primary);
      },
    );

    testWidgets('the calendar shows a Sunday-first weekday header row', (
      tester,
    ) async {
      await _pumpShell(tester);

      await tester.tap(find.byKey(const Key('day-nav-calendar')));
      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(const Key('calendar-weekday-0')));
      final expected = MaterialLocalizations.of(context).narrowWeekdays;
      for (var i = 0; i < 7; i++) {
        final text = tester.widget<Text>(find.byKey(Key('calendar-weekday-$i')));
        expect(text.data, expected[i]);
      }
    });

    testWidgets('the calendar prev/next month buttons expose localized tooltips', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.byKey(const Key('day-nav-calendar')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<IconButton>(find.byKey(const Key('calendar-prev-month'))).tooltip,
        loc.dietCalendarPrevMonth,
      );
      expect(
        tester.widget<IconButton>(find.byKey(const Key('calendar-next-month'))).tooltip,
        loc.dietCalendarNextMonth,
      );
    });
  });

  group('DietShellScreen edit entry', () {
    testWidgets('tapping a logged entry opens the edit sheet prefilled', (
      tester,
    ) async {
      final dietLogRepository = FakeDietLogRepository()
        ..entryToLog = _shellEntryJson();
      await _pumpShell(tester, dietLogRepository: dietLogRepository);

      await tester.tap(find.text('雞腿便當'));
      await tester.pumpAndSettle();

      expect(find.byType(EditEntryScreen), findsOneWidget);
      final nameField = tester.widget<TextField>(
        find.byKey(const Key('edit-name-field')),
      );
      expect(nameField.controller?.text, '雞腿便當');
    });

    testWidgets('saving in the edit sheet updates the entry and reloads the day', (
      tester,
    ) async {
      final dietLogRepository = FakeDietLogRepository()
        ..entryToLog = _shellEntryJson();
      await _pumpShell(tester, dietLogRepository: dietLogRepository);
      final loadsBeforeSave = dietLogRepository.getDayLogCallCount;

      await tester.tap(find.text('雞腿便當'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-portion-staple-field')),
        '5',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-save-button')));
      await tester.pumpAndSettle();

      expect(dietLogRepository.updatedEntryId, 'entry-1');
      expect(dietLogRepository.updatedPortions?.staple, 5);
      expect(find.byType(EditEntryScreen), findsNothing);
      expect(dietLogRepository.getDayLogCallCount, greaterThan(loadsBeforeSave));
    });

    testWidgets('deleting in the edit sheet removes the entry and reloads the day', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dietLogRepository = FakeDietLogRepository()
        ..entryToLog = _shellEntryJson();
      await _pumpShell(tester, dietLogRepository: dietLogRepository);
      final loadsBeforeDelete = dietLogRepository.getDayLogCallCount;

      await tester.tap(find.text('雞腿便當'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-delete-confirm-button')));
      await tester.pumpAndSettle();

      expect(dietLogRepository.deletedEntryId, 'entry-1');
      expect(find.byType(EditEntryScreen), findsNothing);
      expect(dietLogRepository.getDayLogCallCount, greaterThan(loadsBeforeDelete));
    });
  });
}
