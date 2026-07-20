import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/sign_out.dart';
import '../domain/food_item.dart';
import '../domain/portion_preview.dart';
import '../domain/portions.dart';
import 'amount_stepper.dart';
import 'create_meal_controller.dart';
import 'dictionary_controller.dart';
import 'meal_label.dart';
import 'portion_pills.dart';

/// Extracts the dictionary-basis unit from an item's name (e.g. `飯/1碗` ->
/// `碗`, stripping the leading digits), for the tray row's [AmountStepper]
/// unit label. Falls back to a generic quantity word when the name has no
/// `/` unit segment.
String _unitLabelFor(FoodItem item, AppLocalizations loc) {
  final slash = item.name.indexOf('/');
  if (slash == -1 || slash == item.name.length - 1) return loc.dietQuantityLabel;
  final segment = item.name.substring(slash + 1);
  final digits = RegExp(r'^[0-9.]+').firstMatch(segment);
  final unit = digits == null ? segment : segment.substring(digits.end);
  return unit.isEmpty ? loc.dietQuantityLabel : unit;
}

/// The effective quantity previewed for a tray row: the entered unit
/// quantity, or (in gram mode) the grams-derived quantity via the item's
/// base grams — `null` when a gram amount can't yet be converted.
double? _effectiveQuantity(TrayItem trayItem) {
  if (!trayItem.grams) return trayItem.amount;
  return quantityFromGrams(trayItem.amount, trayItem.item.baseGrams);
}

/// A tray row's previewed portions (per-unit × effective quantity), or
/// `null` when the quantity can't be resolved yet (gram mode with no valid
/// conversion).
Portions? _previewFor(TrayItem trayItem) {
  final quantity = _effectiveQuantity(trayItem);
  if (quantity == null) return null;
  return previewPortionsForQuantity(trayItem.item, quantity);
}

/// Sums every tray item's preview (treating an unresolved gram preview as a
/// zero contribution, rather than excluding the row) into a running total.
Portions _trayTotal(List<TrayItem> tray) {
  var staple = 0.0, meat = 0.0, fruit = 0.0, veg = 0.0;
  for (final trayItem in tray) {
    final preview = _previewFor(trayItem);
    if (preview == null) continue;
    staple += preview.staple;
    meat += preview.meat;
    fruit += preview.fruit;
    veg += preview.veg;
  }
  return Portions(staple: staple, meat: meat, fruit: fruit, veg: veg);
}

/// Full-screen food search + current-meal tray, pushed over the diet shell
/// for a target [meal] (a standard meal code, an existing snack's name, or
/// the next snack name) — replaces the old dictionary bottom sheet. Search
/// results and favorites come from the shared [DictionaryController]; the
/// tray and submission are owned by [CreateMealController], which the caller
/// must have already reset via `start(meal)` before pushing this screen.
class FoodSearchScreen extends StatefulWidget {
  final String meal;
  final DictionaryController dictionaryController;
  final CreateMealController createMealController;
  final String idToken;
  final String day;

  /// Signs the user out; wired to the needsReauth banner's "sign in again"
  /// control, mirroring `TodayScreen`/`HomeScreen`'s recovery exit.
  final SignOut signOut;

  const FoodSearchScreen({
    super.key,
    required this.meal,
    required this.dictionaryController,
    required this.createMealController,
    required this.idToken,
    required this.day,
    required this.signOut,
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  @override
  void initState() {
    super.initState();
    widget.dictionaryController.addListener(_onChanged);
    widget.createMealController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.dictionaryController.removeListener(_onChanged);
    widget.createMealController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _submit() async {
    final success = await widget.createMealController.submit(
      widget.idToken,
      widget.day,
    );
    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dictionary = widget.dictionaryController;
    final createMeal = widget.createMealController;

    final showingFavorites = dictionary.query.isEmpty;
    final results = showingFavorites ? dictionary.favorites : dictionary.results;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.dietAddToMealButton(mealDisplayLabel(loc, widget.meal))),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('food-search-field'),
              decoration: InputDecoration(hintText: loc.dietSearchFoodHint),
              onChanged: dictionary.search,
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('food-search-results'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                final isFavorite = dictionary.favorites.any((f) => f.id == item.id);
                return ListTile(
                  key: Key('food-search-result-${item.id}'),
                  title: Text(item.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: PortionPills(
                      staple: item.staple,
                      meat: item.meat,
                      fruit: item.fruit,
                      veg: item.veg,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: isFavorite
                        ? loc.dietUnfavoriteTooltip
                        : loc.dietFavoriteTooltip,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    onPressed: () =>
                        dictionary.toggleFavorite(item, isFavorite: isFavorite),
                  ),
                  onTap: () => createMeal.add(item),
                );
              },
            ),
          ),
          if (createMeal.tray.isNotEmpty)
            _TrayPanel(controller: createMeal, loc: loc, theme: theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (createMeal.status == CreateMealControllerStatus.needsReauth) ...[
                Text(
                  loc.pleaseSignInAgain,
                  key: const Key('food-search-reauth-message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('food-search-sign-in-again-button'),
                  onPressed: widget.signOut.call,
                  child: Text(loc.signInAgain),
                ),
                const SizedBox(height: 8),
              ] else if (createMeal.status == CreateMealControllerStatus.error) ...[
                Text(
                  loc.dietSaveMealFailed,
                  key: const Key('food-search-error-message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: const Key('food-search-done-button'),
                onPressed:
                    createMeal.tray.isEmpty ||
                        createMeal.status == CreateMealControllerStatus.submitting
                    ? null
                    : _submit,
                child: Text(loc.dietSearchDoneButton(createMeal.tray.length)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current-meal tray shown at the bottom of [FoodSearchScreen]: a
/// running total pill (sum of every row's preview) and one row per tray
/// item.
class _TrayPanel extends StatelessWidget {
  final CreateMealController controller;
  final AppLocalizations loc;
  final ThemeData theme;

  const _TrayPanel({required this.controller, required this.loc, required this.theme});

  @override
  Widget build(BuildContext context) {
    final total = _trayTotal(controller.tray);

    return Container(
      key: const Key('food-search-tray'),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(loc.dietMealTotalLabel, style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: PortionPills(
                    key: const Key('food-search-total-pill'),
                    staple: total.staple,
                    meat: total.meat,
                    fruit: total.fruit,
                    veg: total.veg,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              key: const Key('food-search-tray-list'),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.tray.length,
              itemBuilder: (context, index) {
                final trayItem = controller.tray[index];
                final preview = _previewFor(trayItem) ?? const Portions(staple: 0, meat: 0, fruit: 0, veg: 0);
                return Padding(
                  key: Key('tray-item-$index'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Two rows rather than one wide Row: the name + preview
                  // pills + close button on top, and the full AmountStepper
                  // (−/field/+/unit/portion-gram toggle) below — a single
                  // row of all of it overflows on narrow phones (~360dp),
                  // especially for gram-enabled items with the extra
                  // SegmentedButton.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trayItem.item.name,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: PortionPills(
                              staple: preview.staple,
                              meat: preview.meat,
                              fruit: preview.fruit,
                              veg: preview.veg,
                            ),
                          ),
                          IconButton(
                            tooltip: loc.dietRemoveItemTooltip,
                            icon: const Icon(Icons.close),
                            onPressed: () => controller.remove(trayItem),
                          ),
                        ],
                      ),
                      AmountStepper(
                        value: trayItem.amount,
                        onChanged: (value) => controller.setAmount(trayItem, value),
                        unitLabel: _unitLabelFor(trayItem.item, loc),
                        allowGrams: trayItem.item.baseGrams != null,
                        grams: trayItem.grams,
                        onModeChanged: (grams) =>
                            controller.toggleGrams(trayItem, grams),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
