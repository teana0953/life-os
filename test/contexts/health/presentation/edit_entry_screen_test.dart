import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/delete_entry.dart';
import 'package:life_os/contexts/health/application/update_food_entry.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class FakeDietLogRepository implements DietLogRepository {
  String? receivedEntryId;
  Portions? receivedPortions;
  String? receivedName;
  String? deletedEntryId;

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
    throw UnimplementedError();
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
    receivedEntryId = entryId;
    receivedName = name;
    receivedPortions = portions;
    return FoodEntry.fromJson({
      'id': entryId,
      'day': '2026-07-18',
      'meal': meal ?? 'lunch',
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
      'eaten_at': (eatenAt ?? DateTime.utc(2026, 7, 18, 12, 30))
          .toUtc()
          .toIso8601String(),
      'logged_at': DateTime.utc(2026, 7, 18, 12, 31).toIso8601String(),
    });
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

FoodEntry _entry() => FoodEntry.fromJson({
  'id': 'entry-1',
  'day': '2026-07-18',
  'meal': 'lunch',
  'name': '雞腿便當',
  'photo_ref': null,
  'source': 'manual',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': 3,
  'meat': 3,
  'fruit': 0,
  'veg': 0,
  'eaten_at': '2026-07-18T12:30:00.000Z',
  'logged_at': '2026-07-18T12:31:00.000Z',
});

Future<void> _pumpScreen(
  WidgetTester tester,
  EditEntryController controller, {
  String idToken = 'token-123',
  VoidCallback? onSaved,
  VoidCallback? onDeleted,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: EditEntryScreen(
          controller: controller,
          idToken: idToken,
          onSaved: onSaved,
          onDeleted: onDeleted,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('EditEntryScreen', () {
    testWidgets('shows the entry prefilled: name, portions, meal, time', (
      tester,
    ) async {
      final repository = FakeDietLogRepository();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());
      await _pumpScreen(tester, controller);

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('edit-name-field')),
      );
      expect(nameField.controller?.text, '雞腿便當');
      final stapleField = tester.widget<TextField>(
        find.byKey(const Key('edit-portion-staple-field')),
      );
      expect(stapleField.controller?.text, '3');
      final meatField = tester.widget<TextField>(
        find.byKey(const Key('edit-portion-meat-field')),
      );
      expect(meatField.controller?.text, '3');
      final loc = lookupAppLocalizations(const Locale('en'));
      final lunchChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('meal-chip-lunch')),
      );
      expect(lunchChip.selected, isTrue);
      final eatenAtText = tester.widget<Text>(
        find.byKey(const Key('eaten-at-text')),
      );
      expect(eatenAtText.data, isNotNull);
      expect(find.text(loc.dietEditEntryTitle), findsOneWidget);
    });

    testWidgets('save updates the entry with the edited portions and pops', (
      tester,
    ) async {
      final repository = FakeDietLogRepository();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());
      var saved = false;
      await _pumpScreen(tester, controller, onSaved: () => saved = true);

      await tester.enterText(
        find.byKey(const Key('edit-portion-staple-field')),
        '5',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-save-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedEntryId, 'entry-1');
      expect(repository.receivedPortions?.staple, 5);
      expect(saved, isTrue);
    });

    testWidgets(
      'delete asks for confirmation, then removes the entry and pops',
      (tester) async {
        final repository = FakeDietLogRepository();
        final controller = EditEntryController(
          UpdateFoodEntry(repository),
          DeleteEntry(repository),
        );
        controller.start(_entry());
        var deleted = false;
        await _pumpScreen(tester, controller, onDeleted: () => deleted = true);

        await tester.tap(find.byKey(const Key('edit-delete-button')));
        await tester.pumpAndSettle();

        // The confirmation dialog is showing; deletion hasn't happened yet.
        expect(repository.deletedEntryId, isNull);
        expect(find.byKey(const Key('edit-delete-confirm-button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('edit-delete-confirm-button')));
        await tester.pumpAndSettle();

        expect(repository.deletedEntryId, 'entry-1');
        expect(deleted, isTrue);
      },
    );

    testWidgets(
      'the delete button and the delete-confirm button use the destructive (error) color',
      (tester) async {
        final repository = FakeDietLogRepository();
        final controller = EditEntryController(
          UpdateFoodEntry(repository),
          DeleteEntry(repository),
        );
        controller.start(_entry());
        await _pumpScreen(tester, controller);

        final theme = Theme.of(
          tester.element(find.byKey(const Key('edit-delete-button'))),
        );
        final deleteButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('edit-delete-button')),
        );
        expect(
          deleteButton.style?.foregroundColor?.resolve(const {}),
          theme.colorScheme.error,
        );

        await tester.tap(find.byKey(const Key('edit-delete-button')));
        await tester.pumpAndSettle();

        final confirmButton = tester.widget<TextButton>(
          find.byKey(const Key('edit-delete-confirm-button')),
        );
        expect(
          confirmButton.style?.foregroundColor?.resolve(const {}),
          theme.colorScheme.error,
        );
      },
    );

    testWidgets('canceling the delete confirmation keeps the entry', (
      tester,
    ) async {
      final repository = FakeDietLogRepository();
      final controller = EditEntryController(
        UpdateFoodEntry(repository),
        DeleteEntry(repository),
      );
      controller.start(_entry());
      await _pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('edit-delete-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-delete-cancel-button')));
      await tester.pumpAndSettle();

      expect(repository.deletedEntryId, isNull);
      expect(find.byType(EditEntryScreen), findsOneWidget);
    });
  });
}
