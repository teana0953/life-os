import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/quantity_card.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeDietLogRepository implements DietLogRepository {
  double? receivedQuantity;
  double? receivedGrams;

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
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}
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

Future<void> _pumpCard(
  WidgetTester tester,
  LogEntryController controller, {
  String idToken = 'token-123',
  String day = '2026-07-18',
  VoidCallback? onSaved,
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
          ),
        ),
      ),
    ),
  );
  await tester.pump();
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

      await tester.enterText(find.byKey(const Key('quantity-field')), '1.5');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('preview-row')),
          matching: find.text('6'),
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

      expect(find.byKey(const Key('use-grams-switch')), findsNothing);
      expect(find.byKey(const Key('quantity-field')), findsOneWidget);
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

      expect(find.byKey(const Key('use-grams-switch')), findsOneWidget);
    });

    testWidgets('previews via grams — 33g of 飯/50g -> ~0.66 staple', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_rice50g(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('use-grams-switch')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('grams-field')), '33');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('preview-row')),
          matching: find.text('0.66'),
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

      await tester.enterText(find.byKey(const Key('quantity-field')), '1.5');
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-entry-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedQuantity, 1.5);
      expect(saved, isTrue);
    });

    testWidgets('shows a custom snack label field when snack is chosen', (
      tester,
    ) async {
      final controller = LogEntryController(
        LogFoodFromDictionary(FakeDietLogRepository()),
      );
      controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
      await _pumpCard(tester, controller);
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(find.byKey(const Key('snack-label-field')), findsNothing);

      await tester.tap(find.text(loc.dietAddSnack));
      await tester.pump();

      expect(find.byKey(const Key('snack-label-field')), findsOneWidget);
    });
  });
}
