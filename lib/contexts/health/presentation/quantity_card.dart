import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import 'log_entry_controller.dart';

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

/// Card for logging a dictionary item: meal selection (incl. a custom
/// snack label), unit-quantity/grams amount with a live portion preview
/// (D2 in design.md), an eaten-at time, and save.
class QuantityCard extends StatefulWidget {
  final LogEntryController controller;
  final String idToken;
  final String day;
  final VoidCallback? onSaved;

  const QuantityCard({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.onSaved,
  });

  @override
  State<QuantityCard> createState() => _QuantityCardState();
}

class _QuantityCardState extends State<QuantityCard> {
  late final TextEditingController _quantityText;
  late final TextEditingController _gramsText;
  late final TextEditingController _snackLabelText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _quantityText = TextEditingController(
      text: _formatPortion(widget.controller.quantity),
    );
    _gramsText = TextEditingController(
      text: _formatPortion(widget.controller.grams),
    );
    _snackLabelText = TextEditingController(text: widget.controller.snackLabel);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _quantityText.dispose();
    _gramsText.dispose();
    _snackLabelText.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

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
    final dietColors = theme.extension<DietCategoryColors>();
    final preview = controller.preview;
    final isSnack = controller.meal == snackMealValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.name, style: theme.textTheme.titleLarge),
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
          Row(
            children: [
              Text(loc.dietUseGramsLabel),
              Switch(
                key: const Key('use-grams-switch'),
                value: controller.useGrams,
                onChanged: (value) => controller.setUseGrams(value),
              ),
            ],
          ),
        if (!controller.useGrams)
          TextField(
            key: const Key('quantity-field'),
            controller: _quantityText,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: loc.dietQuantityLabel),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) controller.setQuantity(parsed);
            },
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
        Text(loc.dietEatenAtLabel, style: theme.textTheme.bodyMedium),
        Text(_formatTime(controller.eatenAt), key: const Key('eaten-at-text')),
        const SizedBox(height: 12),
        Text(loc.dietPreviewTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (preview != null)
          Wrap(
            key: const Key('preview-row'),
            spacing: 12,
            runSpacing: 8,
            children: [
              _PreviewChip(
                label: loc.dietCategoryStaple,
                value: preview.staple,
                color: dietColors?.staple,
              ),
              _PreviewChip(
                label: loc.dietCategoryMeat,
                value: preview.meat,
                color: dietColors?.meat,
              ),
              _PreviewChip(
                label: loc.dietCategoryFruit,
                value: preview.fruit,
                color: dietColors?.fruit,
              ),
              _PreviewChip(
                label: loc.dietCategoryVeg,
                value: preview.veg,
                color: dietColors?.veg,
              ),
            ],
          ),
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

class _PreviewChip extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;

  const _PreviewChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(_formatPortion(value), style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
