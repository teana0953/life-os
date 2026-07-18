import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/food_item.dart';
import '../domain/portion_preview.dart';
import 'log_entry_controller.dart';
import 'portion_pills.dart';

String _formatPortion(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Extracts the dictionary-basis unit from an item's name, e.g.
/// `飯/1碗` -> `1碗`. Returns `null` when the name has no `/` unit segment.
String? _unitSegment(String name) {
  final slash = name.indexOf('/');
  if (slash == -1 || slash == name.length - 1) return null;
  return name.substring(slash + 1);
}

/// The first non-zero food-group portion on [item] (staple, meat, fruit,
/// veg, in that order), used as the base value in the preview's
/// "base × quantity" math label. Returns `null` when every group is zero.
double? _firstNonZeroPortion(FoodItem item) {
  if (item.staple != 0) return item.staple;
  if (item.meat != 0) return item.meat;
  if (item.fruit != 0) return item.fruit;
  if (item.veg != 0) return item.veg;
  return null;
}

/// The quantity actually applied to the preview: the entered unit quantity,
/// or the grams-derived quantity when in grams mode (mirrors
/// `LogEntryController.preview`'s own resolution, for display only).
double? _effectiveQuantity(LogEntryController controller) {
  final item = controller.item;
  if (item == null) return null;
  if (controller.useGrams) {
    return quantityFromGrams(controller.grams, item.baseGrams);
  }
  return controller.quantity;
}

/// Default [QuantityCard.pickTime]: the platform time picker.
Future<TimeOfDay?> _showTimePicker(
  BuildContext context,
  TimeOfDay initialTime,
) {
  return showTimePicker(context: context, initialTime: initialTime);
}

/// Card for logging a dictionary item: meal selection (incl. a custom
/// snack label), unit-quantity/grams amount with a live portion preview
/// (D2 in design.md), an eaten-at time, and save.
class QuantityCard extends StatefulWidget {
  final LogEntryController controller;
  final String idToken;
  final String day;
  final VoidCallback? onSaved;
  final Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime)
  pickTime;

  const QuantityCard({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.onSaved,
    this.pickTime = _showTimePicker,
  });

  @override
  State<QuantityCard> createState() => _QuantityCardState();
}

class _QuantityCardState extends State<QuantityCard> {
  late final TextEditingController _gramsText;
  late final TextEditingController _snackLabelText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _gramsText = TextEditingController(
      text: _formatPortion(widget.controller.grams),
    );
    _snackLabelText = TextEditingController(text: widget.controller.snackLabel);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _gramsText.dispose();
    _snackLabelText.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _pickEatenAt() async {
    final controller = widget.controller;
    final current = controller.eatenAt.toLocal();
    final picked = await widget.pickTime(
      context,
      TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    controller.setEatenAt(
      DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _save() async {
    final saved = await widget.controller.save(widget.idToken, widget.day);
    if (saved) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final item = controller.item;
    if (item == null) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final preview = controller.preview;
    final isSnack = controller.meal == snackMealValue;

    final basisUnit = _unitSegment(item.name);
    final hasBasisPortions =
        item.staple != 0 || item.meat != 0 || item.fruit != 0 || item.veg != 0;
    final showBasisLine = basisUnit != null && hasBasisPortions;

    final previewBase = _firstNonZeroPortion(item);
    final previewQuantity = _effectiveQuantity(controller);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.name, style: theme.textTheme.titleLarge),
        if (showBasisLine) ...[
          const SizedBox(height: 8),
          Row(
            key: const Key('quantity-basis-line'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                loc.dietBasisEquals(basisUnit),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              PortionPills(
                staple: item.staple,
                meat: item.meat,
                fruit: item.fruit,
                veg: item.veg,
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('meal-chip-breakfast'),
              label: Text(loc.dietMealBreakfast),
              selected: controller.meal == 'breakfast',
              onSelected: (_) => controller.setMeal('breakfast'),
            ),
            ChoiceChip(
              key: const Key('meal-chip-lunch'),
              label: Text(loc.dietMealLunch),
              selected: controller.meal == 'lunch',
              onSelected: (_) => controller.setMeal('lunch'),
            ),
            ChoiceChip(
              key: const Key('meal-chip-dinner'),
              label: Text(loc.dietMealDinner),
              selected: controller.meal == 'dinner',
              onSelected: (_) => controller.setMeal('dinner'),
            ),
            ChoiceChip(
              key: const Key('meal-chip-snack'),
              label: Text(loc.dietAddSnack),
              selected: isSnack,
              onSelected: (_) => controller.setMeal(snackMealValue),
            ),
          ],
        ),
        if (isSnack) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('snack-label-field'),
            controller: _snackLabelText,
            decoration: InputDecoration(hintText: loc.dietSnackLabelHint),
            onChanged: controller.setSnackLabel,
          ),
        ],
        const SizedBox(height: 12),
        if (item.baseGrams != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<bool>(
              key: const Key('use-grams-toggle'),
              segments: [
                ButtonSegment(value: false, label: Text(loc.dietQuantityLabel)),
                ButtonSegment(value: true, label: Text(loc.dietGramsLabel)),
              ],
              selected: {controller.useGrams},
              onSelectionChanged: (selection) =>
                  controller.setUseGrams(selection.first),
            ),
          ),
        if (!controller.useGrams)
          _QuantityStepper(
            value: controller.quantity,
            onChanged: controller.setQuantity,
          )
        else
          TextField(
            key: const Key('grams-field'),
            controller: _gramsText,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: loc.dietGramsLabel),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) controller.setGrams(parsed);
            },
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                loc.dietEatenAtLabel,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            OutlinedButton.icon(
              key: const Key('eaten-at-button'),
              onPressed: _pickEatenAt,
              icon: const Icon(Icons.access_time),
              label: Text(
                _formatTime(controller.eatenAt),
                key: const Key('eaten-at-text'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(loc.dietPreviewTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (preview != null) ...[
          PortionPills(
            key: const Key('preview-row'),
            staple: preview.staple,
            meat: preview.meat,
            fruit: preview.fruit,
            veg: preview.veg,
          ),
          if (previewBase != null && previewQuantity != null) ...[
            const SizedBox(height: 4),
            Text(
              loc.dietPreviewMathLabel(previewBase, previewQuantity),
              key: const Key('preview-math-label'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('save-entry-button'),
          onPressed: controller.status == LogEntryStatus.saving ? null : _save,
          child: Text(loc.dietSaveEntryButton),
        ),
      ],
    );
  }
}

/// An editable quantity stepper (D2 in design.md): −/+ buttons adjust the
/// value by 0.5, and tapping the value itself opens numeric entry, so a
/// non-0.5 decimal (e.g. 1.25) stays reachable without precision loss.
class _QuantityStepper extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _QuantityStepper({required this.value, required this.onChanged});

  Future<void> _editValue(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _QuantityEditDialog(initial: value),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          key: const Key('quantity-decrement'),
          onPressed: () => onChanged((value - 0.5).clamp(0.0, double.infinity)),
          icon: const Icon(Icons.remove),
        ),
        InkWell(
          key: const Key('quantity-value'),
          onTap: () => _editValue(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatPortion(value),
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        IconButton(
          key: const Key('quantity-increment'),
          onPressed: () => onChanged(value + 0.5),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Dialog for typing an exact quantity. A `StatefulWidget` so its
/// `TextEditingController` is owned and disposed by the framework when the
/// dialog closes — avoiding a per-open leak and the teardown-timing issues of
/// disposing it manually after `showDialog` returns.
class _QuantityEditDialog extends StatefulWidget {
  final double initial;

  const _QuantityEditDialog({required this.initial});

  @override
  State<_QuantityEditDialog> createState() => _QuantityEditDialogState();
}

class _QuantityEditDialogState extends State<_QuantityEditDialog> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _formatPortion(widget.initial));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(loc.dietQuantityLabel),
      content: TextField(
        key: const Key('quantity-edit-field'),
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (v) => Navigator.of(context).pop(double.tryParse(v)),
      ),
      actions: [
        TextButton(
          key: const Key('quantity-edit-confirm'),
          onPressed: () =>
              Navigator.of(context).pop(double.tryParse(_text.text)),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
