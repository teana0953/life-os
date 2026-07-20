import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
import 'package:life_os/shared/widgets/mascot.dart';

import '../../../support/l10n_test_app.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

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
    final json = {
      'id': 'entry-${loggedEntries.length + 1}',
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
      'eaten_at': (eatenAt ?? DateTime.now()).toUtc().toIso8601String(),
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    };
    loggedEntries.add(json);
    return FoodEntry.fromJson(json);
  }

  int getDayLogCallCount = 0;
  final List<String> receivedDays = [];

  /// When set, `getDayLog` returns a single breakfast meal group holding
  /// this one entry (used by the edit-sheet tests); otherwise `getDayLog`
  /// groups whatever's been saved through this fake (see [loggedEntries]),
  /// so continuous-logging tests can see the numbering-relevant day log a
  /// real save would have produced.
  Map<String, dynamic>? entryToLog;

  /// Every entry saved through [logFromDictionary]/[logManualEntry] so far,
  /// in save order — [getDayLog] groups these by `meal` (first-seen order)
  /// when [entryToLog] isn't set.
  final List<Map<String, dynamic>> loggedEntries = [];

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
    final json = {
      'id': 'manual-entry-${loggedEntries.length + 1}',
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
    };
    loggedEntries.add(json);
    return FoodEntry.fromJson(json);
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    getDayLogCallCount++;
    receivedDays.add(day);
    final entry = entryToLog;
    final meals = <Map<String, dynamic>>[];
    if (entry != null) {
      meals.add({
        'meal': 'breakfast',
        'entries': [entry],
      });
    } else {
      final byMeal = <String, List<Map<String, dynamic>>>{};
      for (final logged in loggedEntries) {
        (byMeal[logged['meal'] as String] ??= []).add(logged);
      }
      for (final group in byMeal.entries) {
        meals.add({'meal': group.key, 'entries': group.value});
      }
    }
    return DayDietLog.fromJson({
      'day': day,
      'meals': meals,
      'totals': {
        'carbG': 0,
        'proteinG': 0,
        'fatG': 0,
        'sugarG': 0,
        'fiberG': 0,
        'kcal': 0,
      },
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
      'eaten_at': (eatenAt ?? DateTime.utc(2026, 7, 18, 8))
          .toUtc()
          .toIso8601String(),
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

/// Builds a [DietShellScreen] wired to fakes, for a test to pump directly as
/// `home:` (via [_pumpShell]) or push on top of a launcher screen (the
/// home-button test, which needs a real "previous screen" to pop back to).
DietShellScreen _dietShell({
  required FakeDietLogRepository dietLogRepository,
  FakeDailyTargetRepository? dailyTargetRepository,
  FakeFoodDictionaryRepository? foodDictionaryRepository,
  DateTime Function() clock = _defaultClock,
}) {
  final resolvedDailyTargetRepository =
      dailyTargetRepository ?? FakeDailyTargetRepository();
  final resolvedFoodDictionaryRepository =
      foodDictionaryRepository ?? FakeFoodDictionaryRepository();
  return DietShellScreen(
    authRepository: FakeAuthRepository(),
    todayController: TodayController(
      GetDayDietLog(dietLogRepository),
      GetDailyTargetWithRemaining(resolvedDailyTargetRepository),
    ),
    dictionaryController: DictionaryController(
      SearchDictionary(resolvedFoodDictionaryRepository),
      ListFavorites(resolvedFoodDictionaryRepository),
      FavoriteFood(resolvedFoodDictionaryRepository),
      UnfavoriteFood(resolvedFoodDictionaryRepository),
    ),
    dailyTargetController: DailyTargetController(
      GetDailyTargetWithRemaining(resolvedDailyTargetRepository),
      SetDailyTarget(resolvedDailyTargetRepository),
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
    clock: clock,
  );
}

DateTime _defaultClock() => DateTime.utc(2026, 7, 18, 9);

Future<FakeDietLogRepository> _pumpShell(
  WidgetTester tester, {
  FakeDietLogRepository? dietLogRepository,
  Locale locale = const Locale('en'),
}) async {
  final resolvedDietLogRepository =
      dietLogRepository ?? FakeDietLogRepository();

  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: _dietShell(dietLogRepository: resolvedDietLogRepository),
    ),
  );
  await tester.pumpAndSettle();
  return resolvedDietLogRepository;
}

/// Opens the dictionary bottom sheet the only way it's reachable now (D1/D2
/// in design.md — no more Dictionary tab): tapping a meal's add control
/// (`add-to-meal-<meal>`) or the snack area's `add-snack`. Bumps the test
/// surface size so the add control — further down Today's scrollable list —
/// is on-screen and tappable, mirroring this file's pre-existing convention
/// for reaching those controls; restores it after the test.
Future<void> _openDictionarySheet(
  WidgetTester tester, {
  String addKey = 'add-to-meal-breakfast',
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pump();
  await tester.tap(find.byKey(Key(addKey)));
  await tester.pumpAndSettle();
}

void main() {
  group('DietShellScreen', () {
    testWidgets('shows the Today section by default', (tester) async {
      await _pumpShell(tester);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietTabToday), findsWidgets);
    });

    testWidgets(
      'a meal\'s add opens the dictionary as a bottom sheet over Today, not a tab switch',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester, addKey: 'add-to-meal-lunch');

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.text(loc.dietLoggingToMeal(loc.dietMealLunch)),
          findsOneWidget,
        );
        expect(find.text('飯/1碗'), findsOneWidget);
        // Today (underneath) is untouched — this isn't a tab index switch.
        expect(find.text(loc.dietTodayTitle), findsOneWidget);
      },
    );

    testWidgets(
      'the dictionary sheet is capped well short of the full screen height, '
      'with a grab handle and rounded top corners — not the near-fullscreen '
      'panel flagged as blocking in uiux review (D1/D2 in design.md)',
      (tester) async {
        await _pumpShell(tester);
        await _openDictionarySheet(tester);

        // Capped height: leaves Today visible behind the sheet instead of
        // the near-fullscreen panel `isScrollControlled: true` produces on
        // its own with no height cap. Located via the sheet's own
        // logging-meal-bar (unambiguous even though Today, kept alive
        // underneath, has its own unrelated `FractionallySizedBox`es in its
        // category progress bars).
        final sheetSizer = find.ancestor(
          of: find.byKey(const Key('logging-meal-bar')),
          matching: find.byType(FractionallySizedBox),
        );
        expect(sheetSizer, findsOneWidget);
        // `_openDictionarySheet` sets the test surface to this fixed size.
        const surfaceHeight = 1400.0;
        expect(tester.getSize(sheetSizer).height, lessThan(surfaceHeight * 0.95));

        // Grab handle + rounded top corners, matching the other logging
        // sheets' visual language.
        final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(bottomSheet.showDragHandle, isTrue);
        expect(bottomSheet.shape, isA<RoundedRectangleBorder>());
      },
    );

    testWidgets('switching to Target shows the daily target section', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(loc.dietTabTarget));
      await tester.pumpAndSettle();

      expect(find.text(loc.dietSetTargetTitle), findsOneWidget);
    });

    testWidgets(
      'selecting a dictionary item opens the log entry as a second bottom sheet, stacked over the dictionary sheet',
      (tester) async {
        await _pumpShell(tester);
        await _openDictionarySheet(tester);
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();

        expect(find.byType(LogEntryScreen), findsOneWidget);
        // Both sheets are open: the dictionary sheet underneath, the
        // quantity sheet stacked on top of it (D3 in design.md).
        expect(find.byType(BottomSheet), findsNWidgets(2));

        // The quantity-card sheet shares the same grab handle + rounded
        // top corners as the dictionary sheet (unify-sheet-style follow-up).
        final quantitySheet = tester.widget<BottomSheet>(
          find.ancestor(
            of: find.byType(LogEntryScreen),
            matching: find.byType(BottomSheet),
          ),
        );
        expect(quantitySheet.showDragHandle, isTrue);
        expect(quantitySheet.shape, isA<RoundedRectangleBorder>());
      },
    );

    testWidgets(
      'the manual-entry affordance on the dictionary sheet opens the manual-entry screen',
      (tester) async {
        await _pumpShell(tester);
        await _openDictionarySheet(tester);
        await tester.tap(
          find.byKey(const Key('dictionary-manual-entry-button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ManualEntryScreen), findsOneWidget);
      },
    );

    testWidgets('saving a manual entry reloads Today', (tester) async {
      final dietLogRepository = await _pumpShell(tester);
      final loadsBeforeSave = dietLogRepository.getDayLogCallCount;

      await _openDictionarySheet(tester);
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
      expect(
        dietLogRepository.getDayLogCallCount,
        greaterThan(loadsBeforeSave),
      );
    });
  });

  group('DietShellScreen bottom navigation', () {
    testWidgets(
      'shows only Today and Target, with no dictionary destination',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(find.text(loc.dietTabToday), findsWidgets);
        expect(find.text(loc.dietTabTarget), findsWidgets);
        expect(find.byIcon(Icons.menu_book), findsNothing);
      },
    );
  });

  group('DietShellScreen home button', () {
    testWidgets(
      'tapping the home button in the Today header pops back to the previous screen',
      (tester) async {
        final dietLogRepository = FakeDietLogRepository();

        await tester.pumpWidget(
          l10nTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open-diet-shell'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _dietShell(dietLogRepository: dietLogRepository),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('open-diet-shell')));
        await tester.pumpAndSettle();
        expect(find.byType(DietShellScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('today-home-button')));
        await tester.pumpAndSettle();

        expect(find.byType(DietShellScreen), findsNothing);
        expect(find.byKey(const Key('open-diet-shell')), findsOneWidget);
      },
    );

    testWidgets('the home button exposes a localized tooltip', (tester) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('today-home-button')))
            .tooltip,
        loc.dietGoHomeTooltip,
      );
    });
  });

  group('DietShellScreen Today add affordances', () {
    testWidgets(
      'tapping a meal card\'s add control seeds the logging bar with that meal and shows Dictionary',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('add-to-meal-lunch')));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietLoggingToMeal(loc.dietMealLunch)),
          findsOneWidget,
        );
        expect(find.text('飯/1碗'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the snack area\'s add control starts the next snack session and shows Dictionary',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('add-snack')));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietLoggingToMeal(loc.dietSnackBaseName)),
          findsOneWidget,
        );
        expect(find.text('飯/1碗'), findsOneWidget);
      },
    );
  });

  group('DietShellScreen logging bar', () {
    // Taps the logging bar's meal ChoiceChip matching the given localized
    // segment label (breakfast/lunch/dinner/snack), by mapping the label
    // back to its `logging-meal-chip-<segment>` key.
    Finder segment(AppLocalizations loc, String text) {
      final String key;
      if (text == loc.dietMealBreakfast) {
        key = 'logging-meal-chip-breakfast';
      } else if (text == loc.dietMealLunch) {
        key = 'logging-meal-chip-lunch';
      } else if (text == loc.dietMealDinner) {
        key = 'logging-meal-chip-dinner';
      } else if (text == loc.dietSnackBaseName) {
        key = 'logging-meal-chip-snack';
      } else {
        throw ArgumentError('unknown logging bar segment label: $text');
      }
      return find.byKey(Key(key));
    }

    testWidgets('a pick defaults to the current (breakfast) meal', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await _openDictionarySheet(tester);
      expect(
        find.text(loc.dietLoggingToMeal(loc.dietMealBreakfast)),
        findsOneWidget,
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(
        find.text(loc.dietAddToMealButton(loc.dietMealBreakfast)),
        findsOneWidget,
      );
    });

    testWidgets('switching the segment seeds the newly selected meal', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await _openDictionarySheet(tester);
      await tester.tap(segment(loc, loc.dietMealLunch));
      await tester.pumpAndSettle();

      expect(
        find.text(loc.dietLoggingToMeal(loc.dietMealLunch)),
        findsOneWidget,
      );

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();

      expect(
        find.text(loc.dietAddToMealButton(loc.dietMealLunch)),
        findsOneWidget,
      );
    });

    testWidgets(
      'saving shows an "added to <meal>" snackbar and keeps the meal so a second pick is still that meal',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);
        await tester.tap(segment(loc, loc.dietMealLunch));
        await tester.pumpAndSettle();

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        expect(find.byType(LogEntryScreen), findsNothing);
        expect(
          find.text(loc.dietAddedToMealSnackbar(loc.dietMealLunch)),
          findsOneWidget,
        );

        // A second pick is still seeded as lunch — the meal wasn't reset by
        // saving (D3 in design.md).
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        expect(
          find.text(loc.dietAddToMealButton(loc.dietMealLunch)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the "added" snackbar renders in the dictionary sheet\'s own Scaffold, not the shell\'s (D3 in design.md)',
      (tester) async {
        await _pumpShell(tester);
        await _openDictionarySheet(tester);

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        // Exactly one Scaffold is an ancestor of the dictionary sheet's own
        // logging bar — the sheet's own Scaffold (D3 in design.md); the
        // shell's Scaffold sits on a sibling branch under the shared
        // Navigator's Overlay, not an ancestor of anything inside the sheet.
        final dictionarySheetScaffold = find.ancestor(
          of: find.byKey(const Key('logging-meal-bar')),
          matching: find.byType(Scaffold),
        );
        expect(dictionarySheetScaffold, findsOneWidget);

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.descendant(
            of: dictionarySheetScaffold,
            matching: find.byType(SnackBar),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a second save while the first snackbar is still showing replaces it instead of queuing behind it',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);

        // First save, as breakfast.
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();
        expect(
          find.text(loc.dietAddedToMealSnackbar(loc.dietMealBreakfast)),
          findsOneWidget,
        );

        // Second save, as lunch, well within the first snackbar's (now
        // shortened) display window.
        await tester.tap(segment(loc, loc.dietMealLunch));
        await tester.pumpAndSettle();
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        // Only the latest confirmation is showing — the first one was
        // dismissed rather than left queued behind the second.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(loc.dietAddedToMealSnackbar(loc.dietMealLunch)),
          findsOneWidget,
        );
        expect(
          find.text(loc.dietAddedToMealSnackbar(loc.dietMealBreakfast)),
          findsNothing,
        );
      },
    );

    testWidgets('Done pops the dictionary sheet back to Today', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await _openDictionarySheet(tester);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.byKey(const Key('logging-meal-bar-done-button')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(loc.dietTodayTitle), findsOneWidget);
    });

    testWidgets(
      'switching to snack defaults to the base snack name and seeds the card via the snackMealValue+label seam',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietLoggingToMeal(loc.dietSnackBaseName)),
          findsOneWidget,
        );

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietAddToMealButton(loc.dietSnackBaseName)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the recompute gate: re-tapping the already-selected snack segment does not advance the number or split the batch',
      (tester) async {
        final dietLogRepository = FakeDietLogRepository();
        await _pumpShell(tester, dietLogRepository: dietLogRepository);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        // Today reloaded and now has a "Snack" group; re-tapping the
        // already-selected snack segment must NOT recompute (would
        // otherwise split this session into a second "Snack2" group).
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();

        expect(
          find.text(loc.dietLoggingToMeal(loc.dietSnackBaseName)),
          findsOneWidget,
        );

        // A second pick within the same session is still the base name.
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        expect(
          find.text(loc.dietAddToMealButton(loc.dietSnackBaseName)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a new snack session started after the day already has that snack group numbers up',
      (tester) async {
        final dietLogRepository = FakeDietLogRepository();
        await _pumpShell(tester, dietLogRepository: dietLogRepository);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        // Leave the snack segment, then re-enter: a real non-snack->snack
        // transition, so the number should advance.
        await tester.tap(segment(loc, loc.dietMealDinner));
        await tester.pumpAndSettle();
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();

        final numberedName = '${loc.dietSnackBaseName}2';
        expect(
          find.text(loc.dietLoggingToMeal(numberedName)),
          findsOneWidget,
        );

        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        expect(
          find.text(loc.dietAddToMealButton(numberedName)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping add-snack directly (not the in-sheet segment) also seeds the next number once the day already has a snack group',
      (tester) async {
        final dietLogRepository = FakeDietLogRepository();
        await _pumpShell(tester, dietLogRepository: dietLogRepository);
        final loc = lookupAppLocalizations(const Locale('en'));

        // First snack session, saved under the base name, then Done back to
        // Today.
        await _openDictionarySheet(tester, addKey: 'add-snack');
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('logging-meal-bar-done-button')));
        await tester.pumpAndSettle();

        // A fresh tap on Today's add-snack control, with the day already
        // holding one snack group, seeds the numbered name right away.
        await _openDictionarySheet(tester, addKey: 'add-snack');

        final numberedName = '${loc.dietSnackBaseName}2';
        expect(find.text(loc.dietLoggingToMeal(numberedName)), findsOneWidget);
      },
    );

    testWidgets('renaming the current snack session updates the seeded label', (
      tester,
    ) async {
      await _pumpShell(tester);
      final loc = lookupAppLocalizations(const Locale('en'));

      await _openDictionarySheet(tester);
      await tester.tap(segment(loc, loc.dietSnackBaseName));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logging-meal-bar-rename-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('logging-meal-bar-rename-field')),
        '下午茶',
      );
      await tester.tap(find.byKey(const Key('logging-meal-bar-rename-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(loc.dietLoggingToMeal('下午茶')), findsOneWidget);

      await tester.tap(find.text('飯/1碗'));
      await tester.pumpAndSettle();
      expect(
        find.text(loc.dietAddToMealButton('下午茶')),
        findsOneWidget,
      );
    });

    testWidgets(
      'the rename confirm and cancel buttons expose localized tooltips',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('logging-meal-bar-rename-button')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('logging-meal-bar-rename-confirm')),
              )
              .tooltip,
          loc.dietSnackRenameConfirmTooltip,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('logging-meal-bar-rename-cancel')),
              )
              .tooltip,
          loc.dietSnackRenameCancelTooltip,
        );
      },
    );

    testWidgets(
      'canceling a rename restores the original snack name and leaves the session meal unchanged',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await _openDictionarySheet(tester);
        await tester.tap(segment(loc, loc.dietSnackBaseName));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('logging-meal-bar-rename-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('logging-meal-bar-rename-field')),
          '下午茶',
        );
        await tester.tap(find.byKey(const Key('logging-meal-bar-rename-cancel')));
        await tester.pumpAndSettle();

        // The rename field closed without applying the edit; the bar still
        // names the original (base) snack.
        expect(find.byKey(const Key('logging-meal-bar-rename-field')), findsNothing);
        expect(
          find.text(loc.dietLoggingToMeal(loc.dietSnackBaseName)),
          findsOneWidget,
        );

        // A pick still seeds the original name — the cancelled edit wasn't
        // carried into a new session.
        await tester.tap(find.text('飯/1碗'));
        await tester.pumpAndSettle();
        expect(
          find.text(loc.dietAddToMealButton(loc.dietSnackBaseName)),
          findsOneWidget,
        );

        // Reopening rename mode shows the restored name, not the abandoned
        // "下午茶" edit.
        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('logging-meal-bar-rename-button')));
        await tester.pumpAndSettle();
        final renameField = tester.widget<TextField>(
          find.byKey(const Key('logging-meal-bar-rename-field')),
        );
        expect(renameField.controller?.text, loc.dietSnackBaseName);
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
          tester
              .widget<IconButton>(find.byKey(const Key('day-nav-previous')))
              .tooltip,
          loc.dietDayPrevTooltip,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('day-nav-next')))
              .tooltip,
          loc.dietDayNextTooltip,
        );
        expect(
          tester
              .widget<Tooltip>(
                find.ancestor(
                  of: find.byKey(const Key('day-nav-label')),
                  matching: find.byType(Tooltip),
                ),
              )
              .message,
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

  group('DietShellScreen header', () {
    testWidgets(
      'shows the mascot, the today title, and a "Today" chip alongside the full date',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final expectedDate = DateFormat(
          'EEE, MMM d',
          'en',
        ).format(DateTime(2026, 7, 18));

        expect(find.byType(Mascot), findsOneWidget);
        expect(find.text(loc.dietTodayTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayToday),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets(
      'switches to the history title and a "Yesterday" chip after going back a day',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final expectedDate = DateFormat(
          'EEE, MMM d',
          'en',
        ).format(DateTime(2026, 7, 17));

        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        expect(find.text(loc.dietHistoryTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayYesterday),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets(
      'shows no today/yesterday chip for an older day, but keeps showing the full date',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));
        final expectedDate = DateFormat(
          'EEE, MMM d',
          'en',
        ).format(DateTime(2026, 7, 10));

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('calendar-day-2026-07-10')));
        await tester.pumpAndSettle();

        expect(find.text(loc.dietHistoryTitle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayToday),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('day-nav-label')),
            matching: find.text(loc.dietDayYesterday),
          ),
          findsNothing,
        );
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets(
      'formats the full date per the active locale (Traditional Chinese)',
      (tester) async {
        await _pumpShell(
          tester,
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
        );
        final expectedDate = DateFormat(
          'M月d日 EEEE',
          'zh_Hant',
        ).format(DateTime(2026, 7, 18));

        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets('tapping the date pill still opens the calendar', (
      tester,
    ) async {
      final dietLogRepository = FakeDietLogRepository()
        ..loggedDaysToReturn = ['2026-07-15'];
      await _pumpShell(tester, dietLogRepository: dietLogRepository);

      await tester.tap(find.byKey(const Key('day-nav-label')));
      await tester.pumpAndSettle();

      expect(dietLogRepository.receivedMonth, '2026-07');
      expect(find.byKey(const Key('calendar-day-2026-07-15')), findsOneWidget);
    });

    testWidgets(
      'centers the header within a maxWidth column on a wide (tablet/desktop) screen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpShell(tester);

        final constrainedBoxFinder = find.ancestor(
          of: find.byKey(const Key('day-nav-label')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox && widget.constraints.maxWidth == 600,
          ),
        );
        expect(constrainedBoxFinder, findsOneWidget);
        expect(
          tester.getSize(constrainedBoxFinder).width,
          lessThanOrEqualTo(600),
        );
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

        await tester.tap(find.byKey(const Key('day-nav-label')));
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

      await tester.tap(find.byKey(const Key('day-nav-label')));
      await tester.pumpAndSettle();
      final daysBefore = dietLogRepository.receivedDays.length;

      await tester.tap(find.byKey(const Key('calendar-day-2026-07-19')));
      await tester.pumpAndSettle();

      // Still open (a tap on a disabled cell doesn't pop the dialog) and no
      // new day was loaded.
      expect(find.byKey(const Key('calendar-close-button')), findsOneWidget);
      expect(dietLogRepository.receivedDays.length, daysBefore);
    });

    testWidgets(
      'a failure to load logged days still leaves the calendar usable',
      (tester) async {
        final dietLogRepository = FakeDietLogRepository()
          ..loggedDaysError = Exception('boom');
        await _pumpShell(tester, dietLogRepository: dietLogRepository);

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('calendar-day-2026-07-10')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('calendar-day-2026-07-10')));
        await tester.pumpAndSettle();

        expect(dietLogRepository.receivedDays.last, '2026-07-10');
      },
    );

    testWidgets(
      'today and the viewed (selected) day get distinct, overlappable markers',
      (tester) async {
        await _pumpShell(tester);
        // Pinned clock's "today" is 2026-07-18; move the viewed day back one
        // so today and selected are two different cells.
        await tester.tap(find.byKey(const Key('day-nav-previous')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        final theme = Theme.of(
          tester.element(
            find.byKey(const Key('calendar-day-marker-2026-07-18')),
          ),
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

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        final theme = Theme.of(
          tester.element(
            find.byKey(const Key('calendar-day-marker-2026-07-18')),
          ),
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

      await tester.tap(find.byKey(const Key('day-nav-label')));
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byKey(const Key('calendar-weekday-0')),
      );
      final expected = MaterialLocalizations.of(context).narrowWeekdays;
      for (var i = 0; i < 7; i++) {
        final text = tester.widget<Text>(
          find.byKey(Key('calendar-weekday-$i')),
        );
        expect(text.data, expected[i]);
      }
    });

    testWidgets(
      'the calendar prev/next month buttons expose localized tooltips',
      (tester) async {
        await _pumpShell(tester);
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('day-nav-label')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendar-prev-month')))
              .tooltip,
          loc.dietCalendarPrevMonth,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendar-next-month')))
              .tooltip,
          loc.dietCalendarNextMonth,
        );
      },
    );
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

      // The edit sheet shares the same grab handle + rounded top corners as
      // the dictionary sheet (unify-sheet-style follow-up).
      final editSheet = tester.widget<BottomSheet>(
        find.ancestor(
          of: find.byType(EditEntryScreen),
          matching: find.byType(BottomSheet),
        ),
      );
      expect(editSheet.showDragHandle, isTrue);
      expect(editSheet.shape, isA<RoundedRectangleBorder>());
    });

    testWidgets(
      'saving in the edit sheet updates the entry and reloads the day',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
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
        expect(
          dietLogRepository.getDayLogCallCount,
          greaterThan(loadsBeforeSave),
        );
      },
    );

    testWidgets(
      'deleting in the edit sheet removes the entry and reloads the day',
      (tester) async {
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
        expect(
          dietLogRepository.getDayLogCallCount,
          greaterThan(loadsBeforeDelete),
        );
      },
    );
  });
}
