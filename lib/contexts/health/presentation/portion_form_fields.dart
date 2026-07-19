import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'log_entry_controller.dart' show snackMealValue;

String _formatPortion(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

/// A portion value's initial field text: empty for zero (so the user doesn't
/// have to delete a "0" before typing), the formatted number otherwise.
String _portionFieldText(double value) =>
    value == 0 ? '' : _formatPortion(value);

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Default [PortionFormFields.pickTime]: the platform time picker.
Future<TimeOfDay?> showPlatformTimePicker(
  BuildContext context,
  TimeOfDay initialTime,
) {
  return showTimePicker(context: context, initialTime: initialTime);
}

/// Name + four per-group portion inputs + meal selector (incl. custom snack
/// label) + eaten-at time picker, shared by [ManualEntryScreen] (logging a
/// new manual entry) and `EditEntryScreen` (editing a past entry) — a
/// targeted extraction of [ManualEntryScreen]'s original form (D5 in
/// design.md). [keyPrefix] namespaces the name/portion field `Key`s (e.g.
/// `manual`/`edit`) so widget tests can target either screen's fields; the
/// meal-chip/snack-label/eaten-at keys are shared verbatim since the two
/// screens are never mounted in the same widget subtree.
class PortionFormFields extends StatefulWidget {
  final String keyPrefix;
  final String name;
  final ValueChanged<String> onNameChanged;
  final double staple;
  final double meat;
  final double fruit;
  final double veg;
  final void Function(String category, double value) onPortionChanged;
  final String meal;
  final ValueChanged<String> onMealChanged;
  final String snackLabel;
  final ValueChanged<String> onSnackLabelChanged;
  final DateTime eatenAt;
  final ValueChanged<DateTime> onEatenAtChanged;
  final Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime)
  pickTime;

  const PortionFormFields({
    super.key,
    required this.keyPrefix,
    required this.name,
    required this.onNameChanged,
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
    required this.onPortionChanged,
    required this.meal,
    required this.onMealChanged,
    required this.snackLabel,
    required this.onSnackLabelChanged,
    required this.eatenAt,
    required this.onEatenAtChanged,
    this.pickTime = showPlatformTimePicker,
  });

  @override
  State<PortionFormFields> createState() => _PortionFormFieldsState();
}

class _PortionFormFieldsState extends State<PortionFormFields> {
  late final TextEditingController _nameText;
  late final TextEditingController _stapleText;
  late final TextEditingController _meatText;
  late final TextEditingController _fruitText;
  late final TextEditingController _vegText;
  late final TextEditingController _snackLabelText;

  @override
  void initState() {
    super.initState();
    _nameText = TextEditingController(text: widget.name);
    _stapleText = TextEditingController(text: _portionFieldText(widget.staple));
    _meatText = TextEditingController(text: _portionFieldText(widget.meat));
    _fruitText = TextEditingController(text: _portionFieldText(widget.fruit));
    _vegText = TextEditingController(text: _portionFieldText(widget.veg));
    _snackLabelText = TextEditingController(text: widget.snackLabel);
  }

  @override
  void dispose() {
    _nameText.dispose();
    _stapleText.dispose();
    _meatText.dispose();
    _fruitText.dispose();
    _vegText.dispose();
    _snackLabelText.dispose();
    super.dispose();
  }

  Future<void> _pickEatenAt() async {
    final current = widget.eatenAt.toLocal();
    final picked = await widget.pickTime(
      context,
      TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    widget.onEatenAtChanged(
      DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isSnack = widget.meal == snackMealValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: Key('${widget.keyPrefix}-name-field'),
          controller: _nameText,
          decoration: InputDecoration(
            labelText: loc.dietManualEntryNameLabel,
          ),
          onChanged: widget.onNameChanged,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('meal-chip-breakfast'),
              label: Text(loc.dietMealBreakfast),
              selected: widget.meal == 'breakfast',
              onSelected: (_) => widget.onMealChanged('breakfast'),
            ),
            ChoiceChip(
              key: const Key('meal-chip-lunch'),
              label: Text(loc.dietMealLunch),
              selected: widget.meal == 'lunch',
              onSelected: (_) => widget.onMealChanged('lunch'),
            ),
            ChoiceChip(
              key: const Key('meal-chip-dinner'),
              label: Text(loc.dietMealDinner),
              selected: widget.meal == 'dinner',
              onSelected: (_) => widget.onMealChanged('dinner'),
            ),
            ChoiceChip(
              key: const Key('meal-chip-snack'),
              label: Text(loc.dietSnackBaseName),
              selected: isSnack,
              onSelected: (_) => widget.onMealChanged(snackMealValue),
            ),
          ],
        ),
        if (isSnack) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('snack-label-field'),
            controller: _snackLabelText,
            decoration: InputDecoration(hintText: loc.dietSnackLabelHint),
            onChanged: widget.onSnackLabelChanged,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: Key('${widget.keyPrefix}-portion-staple-field'),
          controller: _stapleText,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: loc.dietCategoryStaple,
            hintText: '0',
          ),
          onChanged: (value) => widget.onPortionChanged(
            'staple',
            double.tryParse(value) ?? 0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key('${widget.keyPrefix}-portion-meat-field'),
          controller: _meatText,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: loc.dietCategoryMeat,
            hintText: '0',
          ),
          onChanged: (value) =>
              widget.onPortionChanged('meat', double.tryParse(value) ?? 0),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key('${widget.keyPrefix}-portion-fruit-field'),
          controller: _fruitText,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: loc.dietCategoryFruit,
            hintText: '0',
          ),
          onChanged: (value) =>
              widget.onPortionChanged('fruit', double.tryParse(value) ?? 0),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key('${widget.keyPrefix}-portion-veg-field'),
          controller: _vegText,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: loc.dietCategoryVeg,
            hintText: '0',
          ),
          onChanged: (value) =>
              widget.onPortionChanged('veg', double.tryParse(value) ?? 0),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                loc.dietEatenAtLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            OutlinedButton.icon(
              key: const Key('eaten-at-button'),
              onPressed: _pickEatenAt,
              icon: const Icon(Icons.access_time),
              label: Text(
                _formatTime(widget.eatenAt),
                key: const Key('eaten-at-text'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
