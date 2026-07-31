import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/create_shared_food_item.dart';
import 'package:life_os/contexts/health/application/update_shared_food_item.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_input.dart';
import 'package:life_os/contexts/health/domain/shared_food_item_patch.dart';
import 'package:life_os/contexts/health/presentation/shared_food_item_controller.dart';
import 'package:life_os/contexts/health/presentation/shared_food_item_sheet.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

FoodItem _riceItem() => const FoodItem(
  id: 'rice-1',
  ownerUserId: null,
  name: '飯/1碗',
  carbG: 60,
  proteinG: 4,
  fatG: 0.5,
  sugarG: 0,
  fiberG: 1,
  kcal: 280,
  staple: 4,
  meat: 0,
  fruit: 0,
  veg: 0,
  baseAmount: 50,
  measureUnit: 'g',
);

class FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  Object? errorToThrow;
  Completer<FoodItem>? gate;
  SharedFoodItemInput? receivedInput;
  SharedFoodItemPatch? receivedPatch;

  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}

  @override
  Future<FoodItem> createSharedItem(
    String idToken,
    SharedFoodItemInput input,
  ) async {
    receivedInput = input;
    if (gate != null) return gate!.future;
    if (errorToThrow != null) throw errorToThrow!;
    return _riceItem();
  }

  @override
  Future<FoodItem> updateSharedItem(
    String idToken,
    String id,
    SharedFoodItemPatch patch,
  ) async {
    receivedPatch = patch;
    if (gate != null) return gate!.future;
    if (errorToThrow != null) throw errorToThrow!;
    return _riceItem();
  }
}

Widget _buildSheet({
  required FakeFoodDictionaryRepository repository,
  FoodItem? item,
  ValueChanged<FoodItem>? onSuccess,
}) {
  final controller = SharedFoodItemController(
    CreateSharedFoodItem(repository),
    UpdateSharedFoodItem(repository),
  );
  return l10nTestApp(
    home: Scaffold(
      body: SharedFoodItemSheet(
        controller: controller,
        idToken: 'token-123',
        item: item,
        onSuccess: onSuccess ?? (_) {},
      ),
    ),
  );
}

/// Mimics `FoodSearchScreen` (food_search_screen.dart:130): a persistent
/// widget that stays mounted across sheet opens/closes, listens to the same
/// app-wide [SharedFoodItemController], and calls `setState` on every
/// notification — reproducing the hazard where a freshly opened sheet
/// notifying that same controller during its own `initState` could crash
/// with "setState() or markNeedsBuild() called during build".
class _SheetHost extends StatefulWidget {
  final SharedFoodItemController controller;

  const _SheetHost({required this.controller});

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  bool _showSheet = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('host-toggle-button'),
            onPressed: () => setState(() => _showSheet = !_showSheet),
            child: const Text('toggle'),
          ),
          if (_showSheet)
            Expanded(
              child: SharedFoodItemSheet(
                controller: widget.controller,
                idToken: 'token-123',
                onSuccess: (_) {},
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  group('SharedFoodItemSheet', () {
    testWidgets('create mode opens empty', (tester) async {
      await tester.pumpWidget(
        _buildSheet(repository: FakeFoodDictionaryRepository()),
      );

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-name-field')),
      );
      expect(nameField.controller!.text, isEmpty);
    });

    testWidgets('edit mode opens prefilled from the given item', (tester) async {
      await tester.pumpWidget(
        _buildSheet(repository: FakeFoodDictionaryRepository(), item: _riceItem()),
      );

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-name-field')),
      );
      expect(nameField.controller!.text, '飯/1碗');
      final carbField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-carb-field')),
      );
      expect(carbField.controller!.text, '60');
      final measureAmountField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-measure-amount-field')),
      );
      expect(measureAmountField.controller!.text, '50');
    });

    testWidgets('a zero-valued numeric field shows empty with hint 0', (tester) async {
      await tester.pumpWidget(
        _buildSheet(repository: FakeFoodDictionaryRepository(), item: _riceItem()),
      );

      final meatField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-meat-field')),
      );
      expect(meatField.controller!.text, isEmpty);
      expect(meatField.decoration?.hintText, '0');
    });

    testWidgets(
      'submitting in edit mode after changing two fields calls update with only those fields',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(
          _buildSheet(repository: repository, item: _riceItem()),
        );

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New name',
        );
        await tester.enterText(
          find.byKey(const Key('shared-food-item-carb-field')),
          '65',
        );
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();

        expect(repository.receivedPatch?.name, 'New name');
        expect(repository.receivedPatch?.carbG, 65);
        expect(repository.receivedPatch?.proteinG, isNull);
        expect(repository.receivedPatch?.fatG, isNull);
      },
    );

    testWidgets('measure amount without unit shows an error and does not submit', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-measure-amount-field')),
        '50',
      );
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.sharedFoodItemMeasurePairError), findsOneWidget);
      expect(repository.receivedInput, isNull);
      final amountField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-measure-amount-field')),
      );
      expect(amountField.controller!.text, '50');
    });

    testWidgets('measure unit without amount shows an error and does not submit', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-measure-unit-field')),
        'g',
      );
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.sharedFoodItemMeasurePairError), findsOneWidget);
      expect(repository.receivedInput, isNull);
    });

    testWidgets('non-positive measure amount shows an error and does not submit', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-measure-amount-field')),
        '-5',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-measure-unit-field')),
        'g',
      );
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.sharedFoodItemMeasureAmountPositiveError), findsOneWidget);
      expect(repository.receivedInput, isNull);
    });

    testWidgets('clearing both measure fields together submits explicit nulls', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(
        _buildSheet(repository: repository, item: _riceItem()),
      );

      await tester.enterText(
        find.byKey(const Key('shared-food-item-measure-amount-field')),
        '',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-measure-unit-field')),
        '',
      );
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedPatch?.baseAmount.isSet, isTrue);
      expect(repository.receivedPatch?.baseAmount.value, isNull);
      expect(repository.receivedPatch?.measureUnit.isSet, isTrue);
      expect(repository.receivedPatch?.measureUnit.value, isNull);
    });

    testWidgets('while submitting the submit control is disabled and values remain visible', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository()..gate = Completer<FoodItem>();
      await tester.pumpWidget(_buildSheet(repository: repository));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('shared-food-item-submit-button')),
      );
      expect(button.onPressed, isNull);
      final nameField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-name-field')),
      );
      expect(nameField.controller!.text, 'New item');

      repository.gate!.complete(_riceItem());
      await tester.pumpAndSettle();
    });

    testWidgets('edit mode with nothing changed disables the submit control', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSheet(repository: FakeFoodDictionaryRepository(), item: _riceItem()),
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('shared-food-item-submit-button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a failed submission keeps the sheet open with values intact', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository()
        ..errorToThrow = const DietFetchFailure('failed');
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.sharedFoodItemSaveFailed), findsOneWidget);
      final nameField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-name-field')),
      );
      expect(nameField.controller!.text, 'New item');
      expect(find.byKey(const Key('shared-food-item-name-field')), findsOneWidget);
    });

    testWidgets('a forbidden failure shows the permission message, not the generic one', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository()
        ..errorToThrow = const DietForbidden();
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.sharedFoodItemForbiddenError), findsOneWidget);
      final nameField = tester.widget<TextField>(
        find.byKey(const Key('shared-food-item-name-field')),
      );
      expect(nameField.controller!.text, 'New item');
    });

    testWidgets('a successful create calls onSuccess with the created item', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      FoodItem? received;
      await tester.pumpWidget(
        _buildSheet(
          repository: repository,
          onSuccess: (item) => received = item,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(received?.id, 'rice-1');
    });

    testWidgets(
      'create mode with a blank name shows a required error and does not submit',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(_buildSheet(repository: repository));
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.sharedFoodItemNameRequiredError), findsOneWidget);
        expect(repository.receivedInput, isNull);
      },
    );

    testWidgets(
      'clearing the name in edit mode shows a required error and does not submit',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(
          _buildSheet(repository: repository, item: _riceItem()),
        );
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.enterText(find.byKey(const Key('shared-food-item-name-field')), '');
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.sharedFoodItemNameRequiredError), findsOneWidget);
        expect(repository.receivedPatch, isNull);
      },
    );

    testWidgets('a fresh sheet never shows an error left over from a previous submission', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository()
        ..errorToThrow = const DietForbidden();
      final controller = SharedFoodItemController(
        CreateSharedFoodItem(repository),
        UpdateSharedFoodItem(repository),
      );
      final loc = lookupAppLocalizations(const Locale('en'));

      // First sheet instance: submit fails and shows the forbidden error.
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: SharedFoodItemSheet(
              key: const Key('sheet-1'),
              controller: controller,
              idToken: 'token-123',
              onSuccess: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text(loc.sharedFoodItemForbiddenError), findsOneWidget);

      // A brand-new sheet instance (as if the sheet was dismissed and the
      // admin tapped '+' again) sharing the same app-wide controller.
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: SharedFoodItemSheet(
              key: const Key('sheet-2'),
              controller: controller,
              idToken: 'token-123',
              onSuccess: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.sharedFoodItemForbiddenError), findsNothing);
    });

    testWidgets('a non-numeric value in a macro field blocks submission with an error', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-carb-field')),
        '6o',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.text(loc.sharedFoodItemNumberFieldError(loc.sharedFoodItemCarbLabel)),
        findsOneWidget,
      );
      expect(repository.receivedInput, isNull);
    });

    testWidgets('a negative value in a macro field blocks submission with an error', (
      tester,
    ) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(_buildSheet(repository: repository));
      final loc = lookupAppLocalizations(const Locale('en'));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.enterText(
        find.byKey(const Key('shared-food-item-protein-field')),
        '-3',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.text(loc.sharedFoodItemNumberFieldError(loc.sharedFoodItemProteinLabel)),
        findsOneWidget,
      );
      expect(repository.receivedInput, isNull);
    });

    testWidgets('an empty macro field still submits as zero', (tester) async {
      final repository = FakeFoodDictionaryRepository();
      await tester.pumpWidget(_buildSheet(repository: repository));

      await tester.enterText(
        find.byKey(const Key('shared-food-item-name-field')),
        'New item',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
      await tester.pumpAndSettle();

      expect(repository.receivedInput?.carbG, 0);
    });

    testWidgets(
      'reopening a sheet after a failed submit does not notify during build',
      (tester) async {
        final repository = FakeFoodDictionaryRepository()
          ..errorToThrow = const DietForbidden();
        final controller = SharedFoodItemController(
          CreateSharedFoodItem(repository),
          UpdateSharedFoodItem(repository),
        );

        await tester.pumpWidget(l10nTestApp(home: _SheetHost(controller: controller)));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Close the sheet — the controller's error is left over.
        await tester.tap(find.byKey(const Key('host-toggle-button')));
        await tester.pump();

        // Reopen a fresh sheet instance while the host's listener (mirroring
        // FoodSearchScreen, which is never torn down between sheet opens)
        // stays attached to the same controller.
        await tester.tap(find.byKey(const Key('host-toggle-button')));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'an error from a submission that outlived its own sheet does not leak to the next sheet',
      (tester) async {
        final repository = FakeFoodDictionaryRepository()..gate = Completer<FoodItem>();
        final controller = SharedFoodItemController(
          CreateSharedFoodItem(repository),
          UpdateSharedFoodItem(repository),
        );
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(l10nTestApp(home: _SheetHost(controller: controller)));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pump(); // submit in flight, gated

        // Dismiss the sheet while the request is still in flight.
        await tester.tap(find.byKey(const Key('host-toggle-button')));
        await tester.pump();

        // The in-flight request now fails, landing an error on the shared
        // controller after its own sheet is already gone.
        repository.gate!.completeError(const DietForbidden());
        await tester.pumpAndSettle();

        // A brand-new sheet opens next — it must not show that stale error.
        await tester.tap(find.byKey(const Key('host-toggle-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.sharedFoodItemForbiddenError), findsNothing);
      },
    );

    testWidgets(
      'while submitting the sheet is not poppable, and it becomes poppable '
      'again once the request resolves',
      (tester) async {
        final repository = FakeFoodDictionaryRepository()..gate = Completer<FoodItem>();
        await tester.pumpWidget(_buildSheet(repository: repository));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.pump();
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);

        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pump();
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);

        repository.gate!.complete(_riceItem());
        await tester.pumpAndSettle();
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
      },
    );

    testWidgets(
      'multiple invalid macro fields are all flagged at once, each beside its own field',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(_buildSheet(repository: repository));
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.enterText(
          find.byKey(const Key('shared-food-item-carb-field')),
          '6o',
        );
        await tester.enterText(
          find.byKey(const Key('shared-food-item-protein-field')),
          '-3',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();

        final carbField = tester.widget<TextField>(
          find.byKey(const Key('shared-food-item-carb-field')),
        );
        final proteinField = tester.widget<TextField>(
          find.byKey(const Key('shared-food-item-protein-field')),
        );
        expect(
          carbField.decoration?.errorText,
          loc.sharedFoodItemNumberFieldError(loc.sharedFoodItemCarbLabel),
        );
        expect(
          proteinField.decoration?.errorText,
          loc.sharedFoodItemNumberFieldError(loc.sharedFoodItemProteinLabel),
        );
        expect(repository.receivedInput, isNull);
      },
    );

    testWidgets(
      'correcting an invalid macro field clears its error without waiting for the next submit',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(_buildSheet(repository: repository));
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.enterText(
          find.byKey(const Key('shared-food-item-carb-field')),
          '6o',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.byKey(const Key('shared-food-item-carb-field')))
              .decoration
              ?.errorText,
          loc.sharedFoodItemNumberFieldError(loc.sharedFoodItemCarbLabel),
        );

        await tester.enterText(
          find.byKey(const Key('shared-food-item-carb-field')),
          '60',
        );
        await tester.pump();

        expect(
          tester
              .widget<TextField>(find.byKey(const Key('shared-food-item-carb-field')))
              .decoration
              ?.errorText,
          isNull,
        );
      },
    );

    testWidgets(
      'editing the name after a required-name error clears it without waiting for the next submit',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(_buildSheet(repository: repository));
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();
        expect(find.text(loc.sharedFoodItemNameRequiredError), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.pump();

        expect(find.text(loc.sharedFoodItemNameRequiredError), findsNothing);
      },
    );

    testWidgets(
      'editing the measure amount after a measure-pair error clears it without waiting for the next submit',
      (tester) async {
        final repository = FakeFoodDictionaryRepository();
        await tester.pumpWidget(_buildSheet(repository: repository));
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.enterText(
          find.byKey(const Key('shared-food-item-measure-amount-field')),
          '5',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();
        expect(find.text(loc.sharedFoodItemMeasurePairError), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('shared-food-item-measure-amount-field')),
          '',
        );
        await tester.pump();

        expect(find.text(loc.sharedFoodItemMeasurePairError), findsNothing);
      },
    );

    testWidgets(
      'a 401 on submit shows the reauth message, not the generic save-failed one',
      (tester) async {
        final repository = FakeFoodDictionaryRepository()
          ..errorToThrow = const DietReauthenticationRequired();
        await tester.pumpWidget(_buildSheet(repository: repository));
        final loc = lookupAppLocalizations(const Locale('en'));

        await tester.enterText(
          find.byKey(const Key('shared-food-item-name-field')),
          'New item',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shared-food-item-submit-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.sharedFoodItemNeedsReauthError), findsOneWidget);
        expect(find.text(loc.sharedFoodItemSaveFailed), findsNothing);
      },
    );
  });
}
