import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeDietLogRepository implements DietLogRepository {
  String? receivedName;
  Portions? receivedPortions;
  String? receivedMeal;
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
    receivedName = name;
    receivedPortions = portions;
    receivedMeal = meal;
    receivedEatenAt = eatenAt;
    return FoodEntry.fromJson({
      'id': 'entry-1',
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

Future<void> _pumpScreen(
  WidgetTester tester,
  ManualEntryController controller, {
  String idToken = 'token-123',
  String day = '2026-07-18',
  VoidCallback? onSaved,
}) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: ManualEntryScreen(
        controller: controller,
        idToken: idToken,
        day: day,
        onSaved: onSaved,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ManualEntryScreen', () {
    testWidgets(
      'save posts name, portions, meal, and eaten-at, then invokes onSaved',
      (tester) async {
        final repository = FakeDietLogRepository();
        final controller = ManualEntryController(LogManualEntry(repository));
        controller.start(clock: () => DateTime(2026, 7, 18, 9, 5));
        var saved = false;
        await _pumpScreen(tester, controller, onSaved: () => saved = true);

        await tester.enterText(find.byKey(const Key('manual-name-field')), '蛋');
        await tester.enterText(
          find.byKey(const Key('manual-portion-meat-field')),
          '1',
        );
        await tester.pump();
        final loc = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(loc.dietMealLunch));
        await tester.pump();
        await tester.tap(find.byKey(const Key('manual-save-button')));
        await tester.pumpAndSettle();

        expect(repository.receivedName, '蛋');
        expect(repository.receivedPortions?.meat, 1);
        expect(repository.receivedPortions?.staple, 0);
        expect(repository.receivedMeal, 'lunch');
        expect(repository.receivedEatenAt, DateTime(2026, 7, 18, 9, 5));
        expect(saved, isTrue);
      },
    );

    testWidgets(
      'portion fields start empty (no 0 to delete) and clearing sends 0',
      (tester) async {
        final repository = FakeDietLogRepository();
        final controller = ManualEntryController(LogManualEntry(repository));
        controller.start(clock: () => DateTime(2026, 7, 18, 9, 5));
        await _pumpScreen(tester, controller);

        final staple = tester.widget<TextField>(
          find.byKey(const Key('manual-portion-staple-field')),
        );
        expect(staple.controller?.text, '');

        await tester.enterText(
          find.byKey(const Key('manual-portion-meat-field')),
          '2',
        );
        expect(controller.meat, 2);
        await tester.enterText(
          find.byKey(const Key('manual-portion-meat-field')),
          '',
        );
        expect(controller.meat, 0);
      },
    );

    testWidgets('blocks saving all-zero portions and shows the guard message', (
      tester,
    ) async {
      final repository = FakeDietLogRepository();
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime(2026, 7, 18, 9, 5));
      var saved = false;
      await _pumpScreen(tester, controller, onSaved: () => saved = true);

      await tester.tap(find.byKey(const Key('manual-save-button')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.dietManualEntryAllZeroError), findsOneWidget);
      expect(repository.receivedPortions, isNull);
      expect(saved, isFalse);
    });

    testWidgets(
      'the snack meal chip shows the base snack word, not the "add snack" chip copy',
      (tester) async {
        final repository = FakeDietLogRepository();
        final controller = ManualEntryController(LogManualEntry(repository));
        controller.start(clock: () => DateTime(2026, 7, 18, 9, 5));
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.descendant(
            of: find.byKey(const Key('meal-chip-snack')),
            matching: find.text(loc.dietSnackBaseName),
          ),
          findsOneWidget,
        );
        expect(find.text(loc.dietAddSnack), findsNothing);
      },
    );

    testWidgets('the eaten-at time is editable', (tester) async {
      final repository = FakeDietLogRepository();
      final controller = ManualEntryController(LogManualEntry(repository));
      controller.start(clock: () => DateTime(2026, 7, 18, 9, 5));
      await _pumpScreen(tester, controller);

      final eatenAtText = tester.widget<Text>(
        find.byKey(const Key('eaten-at-text')),
      );
      expect(eatenAtText.data, '09:05');

      controller.setEatenAt(DateTime(2026, 7, 18, 7, 15));
      await tester.pump();

      final updated = tester.widget<Text>(
        find.byKey(const Key('eaten-at-text')),
      );
      expect(updated.data, '07:15');
    });
  });
}
