import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_screen.dart';
import 'package:life_os/contexts/health/presentation/quantity_card.dart';

import '../../../support/l10n_test_app.dart';

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

void main() {
  group('LogEntryScreen', () {
    testWidgets(
      'wraps its content in padding that grows with the keyboard viewInsets',
      (tester) async {
        final controller = LogEntryController(
          LogFoodFromDictionary(FakeDietLogRepository()),
        );
        controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));

        // No wrapping `Scaffold` here (unlike production, where the sheet's
        // content sits directly under `showModalBottomSheet`'s own route,
        // not a `Scaffold`): a `Scaffold` with the default
        // `resizeToAvoidBottomInset: true` would consume the injected
        // `viewInsets.bottom` for its body before `LogEntryScreen` ever sees
        // it, defeating this structural check.
        await tester.pumpWidget(
          l10nTestApp(
            home: MediaQuery(
              data: const MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: Material(
                child: LogEntryScreen(
                  controller: controller,
                  idToken: 'token-123',
                  day: '2026-07-18',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // The content-wrapping padding's bottom inset is the keyboard's
        // viewInsets.bottom plus the sheet's own 20px margin (D1 in
        // design.md) — proving the padding actually tracks the keyboard
        // rather than a fixed value.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding.resolve(TextDirection.ltr).bottom == 320,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'pops itself (from its own context) and calls onSaved on a successful save',
      (tester) async {
        final controller = LogEntryController(
          LogFoodFromDictionary(FakeDietLogRepository()),
        );
        controller.start(_riceBowl(), clock: () => DateTime.utc(2026, 7, 18));
        var savedCalled = false;

        await tester.pumpWidget(
          l10nTestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => LogEntryScreen(
                        controller: controller,
                        idToken: 'token-123',
                        day: '2026-07-18',
                        onSaved: () => savedCalled = true,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(LogEntryScreen), findsOneWidget);
        expect(find.byType(QuantityCard), findsOneWidget);

        await tester.tap(find.byKey(const Key('save-entry-button')));
        await tester.pumpAndSettle();

        expect(savedCalled, isTrue);
        expect(find.byType(LogEntryScreen), findsNothing);
      },
    );
  });
}
