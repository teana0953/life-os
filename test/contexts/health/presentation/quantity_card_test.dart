import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/quantity_card.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeDietLogRepository implements DietLogRepository {
  double? receivedQuantity;
  double? receivedGrams;
  DateTime? receivedEatenAt;

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
    receivedQuantity = quantity;
    receivedGrams = grams;
    receivedEatenAt = eatenAt;
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
      'staple': quantity ?? 0,
      'meat': 0,
      'fruit': 0,
      'veg': 0,
      'eaten_at': (eatenAt ?? DateTime.now()).toUtc().toIso8601String(),
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
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
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}

  @override
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

FoodItem _riceBowl() => FoodItem.fromJson({
  'id': 'rice-bowl',
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
});

FoodItem _rice50g() => FoodItem.fromJson({
  'id': 'rice-50g',
  'owner_user_id': null,
  'name': '飯/50g',
  'carb_g': 15,
  'protein_g': 1,
  'fat_g': 0.1,
  'sugar_g': 0,
  'fiber_g': 0.2,
  'kcal': 70,
  'staple': 1,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'base_grams': 50,
});

Future<TimeOfDay?> _defaultPickTime(
  BuildContext context,
  TimeOfDay initialTime,
) {
  return showTimePicker(context: context, initialTime: initialTime);
}

Future<void> _pumpCard(
  WidgetTester tester,
  LogEntryController controller, {
  String idToken = 'token-123',
  String day = '2026-07-18',
  VoidCallback? onSaved,
  Future<TimeOfDay?> Function(BuildContext, TimeOfDay) pickTime =
      _defaultPickTime,
}) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuantityCard(
            controller: controller,
            idToken: idToken,
            day: day,
            onSaved: onSaved,
            pickTime: pickTime,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Types [value] into the quantity stepper's numeric-entry dialog (opened by
/// tapping the value) and confirms it — the D2 tap-to-type path that keeps
/// arbitrary decimals (e.g. 1.25) reachable.
Future<void> _typeQuantity(WidgetTester tester, String value) async {
  await tester.tap(find.byKey(const Key('quantity-value')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('quantity-edit-field')), value);
  await tester.tap(find.byKey(const Key('quantity-edit-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  group('QuantityCard', () {
    testWidgets('preview scales with quantity — 飯/1碗 x1.5 -> 6 staple', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      await _typeQuantity(tester, '1.5');

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        find.descendant(
          of: find.byKey(const Key('preview-row')),
          matching: find.text('${loc.dietCategoryStaple} 6'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('preview-math-label')),
        findsOneWidget,
      );
      expect(find.text(loc.dietPreviewMathLabel(4, 1.5)), findsOneWidget);
    });

    testWidgets('a typed 1.25 is accepted with no precision lost', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      await _typeQuantity(tester, '1.25');

      expect(controller.quantity, 1.25);
      expect(find.text('1.25'), findsOneWidget);
    });

    testWidgets('stepping the quantity by 0.5 updates the preview', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('quantity-increment')));
      await tester.pump();

      expect(controller.quantity, 1.5);
      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        find.descendant(
          of: find.byKey(const Key('preview-row')),
          matching: find.text('${loc.dietCategoryStaple} 6'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides the gram option when the item has no base grams', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('use-grams-toggle')), findsNothing);
      expect(find.byKey(const Key('quantity-value')), findsOneWidget);
      expect(find.byKey(const Key('grams-field')), findsNothing);
    });

    testWidgets('shows the gram option when the item has base grams', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_rice50g(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('use-grams-toggle')), findsOneWidget);
    });

    testWidgets('previews via grams — 33g of 飯/50g -> ~0.66 staple', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_rice50g(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('use-grams-toggle')),
          matching: find.text(loc.dietGramsLabel),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byKey(const Key('grams-field')), '33');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('preview-row')),
          matching: find.text('${loc.dietCategoryStaple} 0.66'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('save calls the use case with the entered quantity', (
      tester,
    ) async {
      final repository = FakeDietLogRepository();
      final controller = LogEntryController(LogFoodFromDictionary(repository));
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      var saved = false;
      await _pumpCard(tester, controller, onSaved: () => saved = true);

      await _typeQuantity(tester, '1.5');
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedQuantity, 1.5);
      expect(saved, isTrue);
    });

    testWidgets(
      'has no meal chips and no snack-label field — the meal comes from the session',
      (tester) async {
        final controller = LogEntryController(
          LogFoodFromDictionary(FakeDietLogRepository()),
        );
        controller.start(
          _riceBowl(),
          meal: snackMealValue,
          snackLabel: '點心',
          clock: () => DateTime.utc(2026, 7, 18),
        );
        await _pumpCard(tester, controller);

        expect(find.byKey(const Key('meal-chip-breakfast')), findsNothing);
        expect(find.byKey(const Key('meal-chip-lunch')), findsNothing);
        expect(find.byKey(const Key('meal-chip-dinner')), findsNothing);
        expect(find.byKey(const Key('meal-chip-snack')), findsNothing);
        expect(find.byKey(const Key('snack-label-field')), findsNothing);
      },
    );

    testWidgets('the add button names the session\'s standard meal', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(
        _riceBowl(),
        meal: 'lunch',
        clock: () => DateTime.utc(2026, 7, 18),
      );
      await _pumpCard(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(
        find.text(loc.dietAddToMealButton(loc.dietMealLunch)),
        findsOneWidget,
      );
    });

    testWidgets(
      'the add button names the session\'s snack label, not the raw snack meal value',
      (tester) async {
        final controller = LogEntryController(
          LogFoodFromDictionary(FakeDietLogRepository()),
        );
        controller.start(
          _riceBowl(),
          meal: snackMealValue,
          snackLabel: '點心2',
          clock: () => DateTime.utc(2026, 7, 18),
        );
        await _pumpCard(tester, controller);
        final loc = lookupAppLocalizations(const Locale('en'));

        expect(
          find.text(loc.dietAddToMealButton('點心2')),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows the eaten-at time defaulted from the clock', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime(2026, 7, 18, 9, 5));
      await _pumpCard(tester, controller);

      final eatenAtText = tester.widget<Text>(
        find.byKey(const Key('eaten-at-text')),
      );
      expect(eatenAtText.data, '09:05');
    });

    testWidgets('tapping the eaten-at control opens a time picker', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime(2026, 7, 18, 9, 5));
      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('eaten-at-button')));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'choosing a time updates the displayed eaten-at and the value passed to save',
      (tester) async {
        final repository = FakeDietLogRepository();
        final controller = LogEntryController(
          LogFoodFromDictionary(repository),
        );
        controller.start(_riceBowl(), clock: () => DateTime(2026, 7, 18, 9, 5));
        await _pumpCard(
          tester,
          controller,
          pickTime: (context, initialTime) async =>
              const TimeOfDay(hour: 7, minute: 15),
        );

        await tester.tap(find.byKey(const Key('eaten-at-button')));
        await tester.pumpAndSettle();

        final eatenAtText = tester.widget<Text>(
          find.byKey(const Key('eaten-at-text')),
        );
        expect(eatenAtText.data, '07:15');

        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        expect(repository.receivedEatenAt, DateTime(2026, 7, 18, 7, 15));
      },
    );

    testWidgets(
      'shows a dictionary-basis line from the unit segment after / in the name',
      (tester) async {
        final controller = LogEntryController(
          LogFoodFromDictionary(FakeDietLogRepository()),
        );
        controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.byKey(const Key('quantity-basis-line')), findsOneWidget);
        expect(find.text(loc.dietBasisEquals('1碗')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('quantity-basis-line')),
            matching: find.text('${loc.dietCategoryStaple} 4'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('skips the basis line when the name has no / unit segment', (
      tester,
    ) async {
      final noSlashItem = FoodItem.fromJson({
        'id': 'apple-1',
        'owner_user_id': null,
        'name': '蘋果',
        'carb_g': 20,
        'protein_g': 0,
        'fat_g': 0,
        'sugar_g': 15,
        'fiber_g': 2,
        'kcal': 80,
        'staple': 0,
        'meat': 0,
        'fruit': 1,
        'veg': 0,
        'base_grams': null,
      });
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(noSlashItem, clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('quantity-basis-line')), findsNothing);
    });

    testWidgets('skips the basis line when the item has no portions', (
      tester,
    ) async {
      final zeroPortionItem = FoodItem.fromJson({
        'id': 'water-1',
        'owner_user_id': null,
        'name': '水/1杯',
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
        'base_grams': null,
      });
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(zeroPortionItem, clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('quantity-basis-line')), findsNothing);
    });
  });
}
