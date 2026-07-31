import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
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

  String? _nameError;
  String? _measureError;

  /// Per-field numeric validation errors (FIX for follow-up: previously a
  /// single aggregate `_numberError` named only the first bad field and
  /// rendered below both `Wrap` groups, off-screen on a phone with the
  /// keyboard up). Keyed by the field's own controller so each error can be
  /// shown via that field's `InputDecoration.errorText`, right where the
  /// user is looking.
  final Map<TextEditingController, String?> _numberErrors = {};

  /// One listener per controller (rather than one shared listener) so a
  /// keystroke can clear only *that* field's stale error (FIX for
  /// follow-up: errors used to stay visible after the value was corrected,
  /// reappearing only at the next submit if still bad).
  final Map<TextEditingController, VoidCallback> _fieldListeners = {};

  /// The error from this sheet's own last submission, or `null`. Deliberately
  /// separate from [SharedFoodItemController.error]: that field lives on an
  /// app-wide singleton controller reused across sheet openings, so reading
  /// it directly in `build()` would show an error left over from a previous,
  /// unrelated sheet (including one whose submission only failed after that
  /// sheet was already dismissed). This field is only ever set from this
  /// State's own [_submit], so a freshly opened sheet starts with it `null`
  /// and never inherits someone else's error.
  SharedFoodItemError? _ownError;

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
    _measureAmount = TextEditingController(
      text: _seedNullable(item?.baseAmount),
    );
    _measureUnit = TextEditingController(text: item?.measureUnit ?? '');
    for (final c in _allControllers) {
      void listener() => _onFieldChanged(c);
      _fieldListeners[c] = listener;
      c.addListener(listener);
    }
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  void _onFieldChanged(TextEditingController controller) {
    setState(() {
      if (controller == _name) {
        _nameError = null;
      } else if (controller == _measureAmount || controller == _measureUnit) {
        _measureError = null;
      } else {
        _numberErrors[controller] = null;
      }
    });
  }

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.removeListener(_fieldListeners[c]!);
      c.dispose();
    }
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  double _parseOrZero(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  /// `true` in create mode (nothing to compare against — always submittable;
  /// a blank name is instead blocked by [_validateName] with a visible
  /// error, not by silently disabling this button — design.md D9); in edit
  /// mode, `true` only once at least one field's text differs from its
  /// seeded original (design.md D5b: an unchanged edit must not submit,
  /// since the backend rejects an empty PATCH with 400).
  bool get _hasChanges {
    final item = _item;
    if (item == null) return true;
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

  /// An empty (or whitespace-only) name must never be submittable, in either
  /// mode — checked before any request is sent. Sets [_nameError] and
  /// returns false when invalid, mirroring [_validateMeasure]/[_validateNumbers].
  bool _validateName() {
    if (_name.text.trim().isEmpty) {
      final loc = AppLocalizations.of(context)!;
      setState(() => _nameError = loc.sharedFoodItemNameRequiredError);
      return false;
    }
    setState(() => _nameError = null);
    return true;
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
        setState(
          () => _measureError = loc.sharedFoodItemMeasureAmountPositiveError,
        );
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
  /// e.g. `6o` typed into carbs would silently PATCH `carb_g: 0`. Unlike
  /// [_validateName]/[_validateMeasure], this checks every field (not just
  /// the first offending one) and records each error into [_numberErrors]
  /// keyed by its own field, so an admin with several typos sees all of
  /// them at once, each beside the field it names. Returns false if any
  /// field is invalid.
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
    var valid = true;
    final errors = <TextEditingController, String?>{};
    for (final (controller, label) in fields) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        errors[controller] = null;
        continue;
      }
      final value = double.tryParse(text);
      if (value == null || value < 0) {
        errors[controller] = loc.sharedFoodItemNumberFieldError(label);
        valid = false;
      } else {
        errors[controller] = null;
      }
    }
    setState(() {
      _numberErrors
        ..clear()
        ..addAll(errors);
    });
    return valid;
  }

  Future<void> _submit() async {
    if (!_validateName()) return;
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
    // A successful write must be reported even if this sheet is already gone:
    // `PopScope` blocks the barrier tap and the back gesture while submitting,
    // but the drag handle's `onClosing` calls `Navigator.pop` directly
    // (Flutter's bottom_sheet.dart), so a drag-dismiss mid-flight still
    // disposes this State. `onSuccess` belongs to the *screen*, which outlives
    // the sheet, and it already guards its own `mounted` before touching the
    // screen's context — so it runs regardless, and the admin gets the success
    // message and the refreshed list instead of silently wondering whether the
    // item was created. Only the failure branch is gated on this State, since
    // `_ownError` would paint an error onto a sheet the user can no longer see.
    if (result != null) {
      widget.onSuccess(result);
      return;
    }
    if (!mounted) return;
    setState(() => _ownError = widget.controller.error);
  }

  Widget _numberField(Key key, TextEditingController controller, String label) {
    return NumericAmountField(
      fieldKey: key,
      controller: controller,
      label: label,
      errorText: _numberErrors[controller],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final submitting =
        controller.status == SharedFoodItemControllerStatus.submitting;
    final canSubmit = !submitting && _hasChanges;

    String? errorMessage;
    if (_ownError == SharedFoodItemError.forbidden) {
      errorMessage = loc.sharedFoodItemForbiddenError;
    } else if (_ownError == SharedFoodItemError.needsReauth) {
      errorMessage = loc.sharedFoodItemNeedsReauthError;
    } else if (_ownError == SharedFoodItemError.saveFailed) {
      errorMessage = loc.sharedFoodItemSaveFailed;
    }

    return PopScope(
      // While a submit is in flight, this State is the only thing that
      // knows the request is still running — blocking dismissal here (both
      // the barrier tap and the back/drag gesture) is the only lever
      // available from inside the sheet. Without this, a submit that
      // completes successfully after the sheet was already dismissed is
      // silent: `_submit`'s `mounted` guard (kept as defence in depth)
      // discards the result, so the admin sees no confirmation and no list
      // refresh, and may create a duplicate.
      canPop: !submitting,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _item == null
                      ? loc.sharedFoodItemCreateTitle
                      : loc.sharedFoodItemEditTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('shared-food-item-name-field'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: loc.sharedFoodItemNameLabel,
                  ),
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _nameError!,
                    key: const Key('shared-food-item-name-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  loc.sharedFoodItemPortionsHeading,
                  key: const Key('shared-food-item-portions-heading'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _numberField(
                      const Key('shared-food-item-staple-field'),
                      _staple,
                      loc.dietCategoryStaple,
                    ),
                    _numberField(
                      const Key('shared-food-item-meat-field'),
                      _meat,
                      loc.dietCategoryMeat,
                    ),
                    _numberField(
                      const Key('shared-food-item-fruit-field'),
                      _fruit,
                      loc.dietCategoryFruit,
                    ),
                    _numberField(
                      const Key('shared-food-item-veg-field'),
                      _veg,
                      loc.dietCategoryVeg,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  loc.sharedFoodItemNutrientsHeading,
                  key: const Key('shared-food-item-nutrients-heading'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _numberField(
                      const Key('shared-food-item-carb-field'),
                      _carb,
                      loc.sharedFoodItemCarbLabel,
                    ),
                    _numberField(
                      const Key('shared-food-item-protein-field'),
                      _protein,
                      loc.sharedFoodItemProteinLabel,
                    ),
                    _numberField(
                      const Key('shared-food-item-fat-field'),
                      _fat,
                      loc.sharedFoodItemFatLabel,
                    ),
                    _numberField(
                      const Key('shared-food-item-sugar-field'),
                      _sugar,
                      loc.sharedFoodItemSugarLabel,
                    ),
                    _numberField(
                      const Key('shared-food-item-fiber-field'),
                      _fiber,
                      loc.sharedFoodItemFiberLabel,
                    ),
                    _numberField(
                      const Key('shared-food-item-kcal-field'),
                      _kcal,
                      loc.sharedFoodItemKcalLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('shared-food-item-measure-amount-field'),
                        controller: _measureAmount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
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
                        decoration: InputDecoration(
                          labelText: loc.sharedFoodItemMeasureUnitLabel,
                        ),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('shared-food-item-cancel-button'),
                        // Blocked while submitting for the same reason as the
                        // `PopScope` above (design.md D5b): the only escape
                        // hatch out of the sheet during an in-flight request
                        // is the barrier/back gesture, which `PopScope`
                        // already blocks — this button must not offer a
                        // second, unguarded way out.
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: Text(loc.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
