import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/field_update.dart';
import '../domain/food_item.dart';
import '../domain/shared_food_item_input.dart';
import '../domain/shared_food_item_patch.dart';
import 'shared_food_item_controller.dart';

/// Empty-zero convention (CLAUDE.md): a value of `0` (or `null`) seeds an
/// empty field with a `'0'` hint, rather than a literal `'0'`.
String _seed(double value) {
  if (value == 0) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}

String _seedNullable(double? value) => value == null ? '' : _seed(value);

/// The bottom sheet used to create a new shared dictionary item or edit an
/// existing one (design.md D4). Not an `AlertDialog` — every text-input form
/// in this app is a bottom sheet, lifted above the on-screen keyboard via
/// `viewInsets.bottom` padding. Holds no use case directly: submission goes
/// through the injected [controller] (screen → controller → use case, this
/// project's layering).
class SharedFoodItemSheet extends StatefulWidget {
  final SharedFoodItemController controller;
  final String idToken;

  /// `null` = create mode (fields start empty, submits `POST`); non-null =
  /// edit mode (fields start prefilled from this item, and submit sends
  /// only the fields the administrator changed, via `PATCH`).
  final FoodItem? item;

  /// Called with the created/updated item once the request succeeds. The
  /// caller (`FoodSearchScreen`) closes the sheet, shows the success
  /// SnackBar, and re-runs the search (design.md D7) — this widget only
  /// drives the form and the submit request.
  final ValueChanged<FoodItem> onSuccess;

  const SharedFoodItemSheet({
    super.key,
    required this.controller,
    required this.idToken,
    this.item,
    required this.onSuccess,
  });

  @override
  State<SharedFoodItemSheet> createState() => _SharedFoodItemSheetState();
}

class _SharedFoodItemSheetState extends State<SharedFoodItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _staple;
  late final TextEditingController _meat;
  late final TextEditingController _fruit;
  late final TextEditingController _veg;
  late final TextEditingController _carb;
  late final TextEditingController _protein;
  late final TextEditingController _fat;
  late final TextEditingController _sugar;
  late final TextEditingController _fiber;
  late final TextEditingController _kcal;
  late final TextEditingController _measureAmount;
  late final TextEditingController _measureUnit;

  String? _measureError;
  String? _numberError;

  FoodItem? get _item => widget.item;

  List<TextEditingController> get _allControllers => [
    _name,
    _staple,
    _meat,
    _fruit,
    _veg,
    _carb,
    _protein,
    _fat,
    _sugar,
    _fiber,
    _kcal,
    _measureAmount,
    _measureUnit,
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _staple = TextEditingController(text: _seedNullable(item?.staple));
    _meat = TextEditingController(text: _seedNullable(item?.meat));
    _fruit = TextEditingController(text: _seedNullable(item?.fruit));
    _veg = TextEditingController(text: _seedNullable(item?.veg));
    _carb = TextEditingController(text: _seedNullable(item?.carbG));
    _protein = TextEditingController(text: _seedNullable(item?.proteinG));
    _fat = TextEditingController(text: _seedNullable(item?.fatG));
    _sugar = TextEditingController(text: _seedNullable(item?.sugarG));
    _fiber = TextEditingController(text: _seedNullable(item?.fiberG));
    _kcal = TextEditingController(text: _seedNullable(item?.kcal));
    _measureAmount = TextEditingController(text: _seedNullable(item?.baseAmount));
    _measureUnit = TextEditingController(text: item?.measureUnit ?? '');
    for (final c in _allControllers) {
      c.addListener(_onChanged);
    }
    widget.controller.addListener(_onChanged);
    // The controller is an app-wide singleton reused across sheet openings —
    // clear any error left over from a previous, unrelated submission so a
    // freshly opened sheet never shows it (see shared_food_item_controller.dart).
    widget.controller.clearError();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  double _parseOrZero(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  /// `true` in create mode (nothing to compare against — always submittable);
  /// in edit mode, `true` only once at least one field's text differs from
  /// its seeded original (design.md D5b: an unchanged edit must not submit,
  /// since the backend rejects an empty PATCH with 400).
  bool get _hasChanges {
    final item = _item;
    if (item == null) return _name.text.trim().isNotEmpty;
    return _name.text.trim() != item.name ||
        _staple.text.trim() != _seedNullable(item.staple) ||
        _meat.text.trim() != _seedNullable(item.meat) ||
        _fruit.text.trim() != _seedNullable(item.fruit) ||
        _veg.text.trim() != _seedNullable(item.veg) ||
        _carb.text.trim() != _seedNullable(item.carbG) ||
        _protein.text.trim() != _seedNullable(item.proteinG) ||
        _fat.text.trim() != _seedNullable(item.fatG) ||
        _sugar.text.trim() != _seedNullable(item.sugarG) ||
        _fiber.text.trim() != _seedNullable(item.fiberG) ||
        _kcal.text.trim() != _seedNullable(item.kcal) ||
        _measureAmount.text.trim() != _seedNullable(item.baseAmount) ||
        _measureUnit.text.trim() != (item.measureUnit ?? '');
  }

  /// Validates the measure-basis pair rule (design.md D5): both filled or
  /// both empty, and a filled amount must be `> 0`. Sets [_measureError]
  /// and returns false when invalid — checked before any request is sent.
  bool _validateMeasure() {
    final amountText = _measureAmount.text.trim();
    final unitText = _measureUnit.text.trim();
    final loc = AppLocalizations.of(context)!;
    if (amountText.isEmpty != unitText.isEmpty) {
      setState(() => _measureError = loc.sharedFoodItemMeasurePairError);
      return false;
    }
    if (amountText.isNotEmpty) {
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        setState(() => _measureError = loc.sharedFoodItemMeasureAmountPositiveError);
        return false;
      }
    }
    setState(() => _measureError = null);
    return true;
  }

  /// The field's new value for a PATCH, or `null` (excluded from the patch)
  /// when its text still matches the seeded original.
  double? _fieldIfChanged(TextEditingController controller, double original) {
    final text = controller.text.trim();
    if (text == _seedNullable(original)) return null;
    return double.tryParse(text) ?? 0;
  }

  /// Validates every macro/portion numeric field: empty stays meaning `0`
  /// (the project-wide empty-zero convention), but non-empty text that
  /// isn't a parseable, non-negative number blocks submission — otherwise
  /// e.g. `6o` typed into carbs would silently PATCH `carb_g: 0`. Sets
  /// [_numberError] (naming the offending field) and returns false when
  /// invalid, mirroring [_validateMeasure]'s pattern.
  bool _validateNumbers() {
    final loc = AppLocalizations.of(context)!;
    final fields = <(TextEditingController, String)>[
      (_staple, loc.dietCategoryStaple),
      (_meat, loc.dietCategoryMeat),
      (_fruit, loc.dietCategoryFruit),
      (_veg, loc.dietCategoryVeg),
      (_carb, loc.sharedFoodItemCarbLabel),
      (_protein, loc.sharedFoodItemProteinLabel),
      (_fat, loc.sharedFoodItemFatLabel),
      (_sugar, loc.sharedFoodItemSugarLabel),
      (_fiber, loc.sharedFoodItemFiberLabel),
      (_kcal, loc.sharedFoodItemKcalLabel),
    ];
    for (final (controller, label) in fields) {
      final text = controller.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null || value < 0) {
        setState(() => _numberError = loc.sharedFoodItemNumberFieldError(label));
        return false;
      }
    }
    setState(() => _numberError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validateNumbers()) return;
    if (!_validateMeasure()) return;

    final amountText = _measureAmount.text.trim();
    final unitText = _measureUnit.text.trim();
    final measureAmount = amountText.isEmpty ? null : double.parse(amountText);
    final measureUnit = unitText.isEmpty ? null : unitText;

    final item = _item;
    final FoodItem? result;
    if (item == null) {
      result = await widget.controller.create(
        widget.idToken,
        SharedFoodItemInput(
          name: _name.text.trim(),
          carbG: _parseOrZero(_carb),
          proteinG: _parseOrZero(_protein),
          fatG: _parseOrZero(_fat),
          sugarG: _parseOrZero(_sugar),
          fiberG: _parseOrZero(_fiber),
          kcal: _parseOrZero(_kcal),
          staple: _parseOrZero(_staple),
          meat: _parseOrZero(_meat),
          fruit: _parseOrZero(_fruit),
          veg: _parseOrZero(_veg),
          baseAmount: measureAmount,
          measureUnit: measureUnit,
        ),
      );
    } else {
      // The measure basis is a pair: if either half changed, both ride in
      // the patch together (an explicit null for the cleared half), never
      // just one — a lone `base_amount` PATCH would desync the unit half.
      final measureTouched =
          amountText != _seedNullable(item.baseAmount) ||
          unitText != (item.measureUnit ?? '');
      result = await widget.controller.update(
        widget.idToken,
        item.id,
        SharedFoodItemPatch(
          name: _name.text.trim() == item.name ? null : _name.text.trim(),
          carbG: _fieldIfChanged(_carb, item.carbG),
          proteinG: _fieldIfChanged(_protein, item.proteinG),
          fatG: _fieldIfChanged(_fat, item.fatG),
          sugarG: _fieldIfChanged(_sugar, item.sugarG),
          fiberG: _fieldIfChanged(_fiber, item.fiberG),
          kcal: _fieldIfChanged(_kcal, item.kcal),
          staple: _fieldIfChanged(_staple, item.staple),
          meat: _fieldIfChanged(_meat, item.meat),
          fruit: _fieldIfChanged(_fruit, item.fruit),
          veg: _fieldIfChanged(_veg, item.veg),
          baseAmount: measureTouched
              ? FieldUpdate.set(measureAmount)
              : const FieldUpdate.unset(),
          measureUnit: measureTouched
              ? FieldUpdate.set(measureUnit)
              : const FieldUpdate.unset(),
        ),
      );
    }
    // The sheet may have been dismissed (tapped outside, dragged down) while
    // this request was in flight — this State is disposed by then, so
    // `onSuccess` (which pops the now-gone sheet route) must not run.
    if (result != null && mounted) widget.onSuccess(result);
  }

  Widget _numberField(Key key, TextEditingController controller, String label) {
    return SizedBox(
      width: 140,
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, hintText: '0'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final submitting = controller.status == SharedFoodItemControllerStatus.submitting;
    final canSubmit = !submitting && _hasChanges;

    String? errorMessage;
    if (controller.error == SharedFoodItemError.forbidden) {
      errorMessage = loc.sharedFoodItemForbiddenError;
    } else if (controller.error == SharedFoodItemError.saveFailed) {
      errorMessage = loc.sharedFoodItemSaveFailed;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _item == null ? loc.sharedFoodItemCreateTitle : loc.sharedFoodItemEditTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('shared-food-item-name-field'),
                controller: _name,
                decoration: InputDecoration(labelText: loc.sharedFoodItemNameLabel),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _numberField(const Key('shared-food-item-staple-field'), _staple, loc.dietCategoryStaple),
                  _numberField(const Key('shared-food-item-meat-field'), _meat, loc.dietCategoryMeat),
                  _numberField(const Key('shared-food-item-fruit-field'), _fruit, loc.dietCategoryFruit),
                  _numberField(const Key('shared-food-item-veg-field'), _veg, loc.dietCategoryVeg),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _numberField(const Key('shared-food-item-carb-field'), _carb, loc.sharedFoodItemCarbLabel),
                  _numberField(const Key('shared-food-item-protein-field'), _protein, loc.sharedFoodItemProteinLabel),
                  _numberField(const Key('shared-food-item-fat-field'), _fat, loc.sharedFoodItemFatLabel),
                  _numberField(const Key('shared-food-item-sugar-field'), _sugar, loc.sharedFoodItemSugarLabel),
                  _numberField(const Key('shared-food-item-fiber-field'), _fiber, loc.sharedFoodItemFiberLabel),
                  _numberField(const Key('shared-food-item-kcal-field'), _kcal, loc.sharedFoodItemKcalLabel),
                ],
              ),
              if (_numberError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _numberError!,
                  key: const Key('shared-food-item-number-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('shared-food-item-measure-amount-field'),
                      controller: _measureAmount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: loc.sharedFoodItemMeasureAmountLabel,
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('shared-food-item-measure-unit-field'),
                      controller: _measureUnit,
                      decoration: InputDecoration(labelText: loc.sharedFoodItemMeasureUnitLabel),
                    ),
                  ),
                ],
              ),
              if (_measureError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _measureError!,
                  key: const Key('shared-food-item-measure-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  key: const Key('shared-food-item-error-message'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('shared-food-item-submit-button'),
                onPressed: canSubmit ? () => _submit() : null,
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(loc.sharedFoodItemSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
