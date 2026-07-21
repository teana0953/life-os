import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/sign_out.dart';
import '../domain/portion_preview.dart';
import '../domain/portions.dart';
import 'amount_stepper.dart';
import 'create_meal_controller.dart';
import 'dictionary_controller.dart';
import 'meal_label.dart';
import 'portion_pills.dart';
import 'unit_label.dart';

/// The effective quantity previewed for a dictionary tray row: the entered
/// unit quantity, or (in measure mode) the measure-derived quantity via the
/// item's base amount — `null` when a measure amount can't yet be
/// converted.
double? _effectiveQuantity(TrayItem trayItem) {
  if (!trayItem.measureMode) return trayItem.amount;
  return quantityFromMeasure(trayItem.amount, trayItem.item.baseAmount);
}

/// A tray row's previewed portions: a dictionary row's per-unit × effective
/// quantity (`null` when the quantity can't be resolved yet — measure mode
/// with no valid conversion), or a manual row's entered portions directly.
Portions? _previewFor(TrayEntry entry) {
  switch (entry) {
    case TrayItem():
      final quantity = _effectiveQuantity(entry);
      if (quantity == null) return null;
      return previewPortionsForQuantity(entry.item, quantity);
    case ManualTrayItem():
      return entry.portions;
  }
}

/// Sums every tray entry's preview (treating an unresolved measure preview
/// as a zero contribution, rather than excluding the row) into a running
/// total.
Portions _trayTotal(List<TrayEntry> tray) {
  var staple = 0.0, meat = 0.0, fruit = 0.0, veg = 0.0;
  for (final entry in tray) {
    final preview = _previewFor(entry);
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

  Future<void> _openManualEntry() async {
    final result = await showDialog<(String, Portions)>(
      context: context,
      builder: (_) => const _ManualEntryDialog(),
    );
    if (result != null) {
      widget.createMealController.addManual(result.$1, result.$2);
    }
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              key: const Key('food-search-field'),
              decoration: InputDecoration(hintText: loc.dietSearchFoodHint),
              onChanged: dictionary.search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('manual-entry-link'),
                onPressed: _openManualEntry,
                child: Text(loc.dietManualEntryLink),
              ),
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
/// entry (dictionary or manual).
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
                final entry = controller.tray[index];
                final preview = _previewFor(entry) ?? const Portions(staple: 0, meat: 0, fruit: 0, veg: 0);
                final name = switch (entry) {
                  TrayItem() => entry.item.name,
                  ManualTrayItem() => entry.name,
                };
                return Padding(
                  key: Key('tray-item-$index'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Stacked rows, never one wide Row: name + close on top, the
                  // preview pills on their own full-width line, then (for a
                  // dictionary row) the full AmountStepper below. Squeezing the
                  // pills into a Flexible slot beside the name compresses a
                  // pill below its intrinsic width and wraps its label into a
                  // rounded blob on narrow phones — the pills need a full line.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: loc.dietRemoveItemTooltip,
                            icon: const Icon(Icons.close),
                            onPressed: () => controller.remove(entry),
                          ),
                        ],
                      ),
                      if (preview.staple != 0 ||
                          preview.meat != 0 ||
                          preview.fruit != 0 ||
                          preview.veg != 0)
                        PortionPills(
                          staple: preview.staple,
                          meat: preview.meat,
                          fruit: preview.fruit,
                          veg: preview.veg,
                        ),
                      if (entry is TrayItem)
                        AmountStepper(
                          value: entry.amount,
                          onChanged: (value) => controller.setAmount(entry, value),
                          unitLabel: unitLabelForName(entry.item.name, loc),
                          allowMeasure: entry.item.baseAmount != null && entry.item.measureUnit != null,
                          measureMode: entry.measureMode,
                          measureLabel: measureLabelFor(entry.item.measureUnit, loc),
                          onModeChanged: (measureMode) =>
                              controller.toggleMeasure(entry, measureMode),
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

/// Manual food-entry dialog: a name field + the four category portion
/// inputs (staple/meat/fruit/veg), following the numeric empty-zero
/// convention. Pops `(name, Portions)` on submit, `null` on cancel.
class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog();

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _name = TextEditingController();
  final _staple = TextEditingController();
  final _meat = TextEditingController();
  final _fruit = TextEditingController();
  final _veg = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _staple.dispose();
    _meat.dispose();
    _fruit.dispose();
    _veg.dispose();
    super.dispose();
  }

  double _parse(TextEditingController controller) => double.tryParse(controller.text) ?? 0;

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((
      name,
      Portions(
        staple: _parse(_staple),
        meat: _parse(_meat),
        fruit: _parse(_fruit),
        veg: _parse(_veg),
      ),
    ));
  }

  Widget _portionField(Key key, TextEditingController controller, String label) {
    return SizedBox(
      width: 80,
      child: TextField(
        key: key,
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, hintText: '0'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(loc.dietManualEntryTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('manual-entry-name-field'),
              controller: _name,
              decoration: InputDecoration(labelText: loc.dietManualEntryNameLabel),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _portionField(const Key('manual-entry-staple-field'), _staple, loc.dietCategoryStaple),
                _portionField(const Key('manual-entry-meat-field'), _meat, loc.dietCategoryMeat),
                _portionField(const Key('manual-entry-fruit-field'), _fruit, loc.dietCategoryFruit),
                _portionField(const Key('manual-entry-veg-field'), _veg, loc.dietCategoryVeg),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('manual-entry-add-button'),
          onPressed: _submit,
          child: Text(loc.dietManualEntryAddButton),
        ),
      ],
    );
  }
}
