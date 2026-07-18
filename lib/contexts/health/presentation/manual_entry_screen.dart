import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'log_entry_controller.dart' show snackMealValue;
import 'manual_entry_controller.dart';

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

/// Default [ManualEntryScreen.pickTime]: the platform time picker.
Future<TimeOfDay?> _showTimePicker(
  BuildContext context,
  TimeOfDay initialTime,
) {
  return showTimePicker(context: context, initialTime: initialTime);
}

/// Screen for logging a food not in the dictionary: an optional name, four
/// per-group portion fields, meal selection (incl. a custom snack label),
/// an eaten-at time, and save — mirroring [QuantityCard]'s meal-chip/
/// eaten-at/onSaved pattern (D1 in design.md).
class ManualEntryScreen extends StatefulWidget {
  final ManualEntryController controller;
  final String idToken;
  final String day;
  final VoidCallback? onSaved;
  final Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime)
  pickTime;

  const ManualEntryScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.onSaved,
    this.pickTime = _showTimePicker,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  late final TextEditingController _nameText;
  late final TextEditingController _stapleText;
  late final TextEditingController _meatText;
  late final TextEditingController _fruitText;
  late final TextEditingController _vegText;
  late final TextEditingController _snackLabelText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    final controller = widget.controller;
    _nameText = TextEditingController(text: controller.name);
    _stapleText = TextEditingController(text: _formatPortion(controller.staple));
    _meatText = TextEditingController(text: _formatPortion(controller.meat));
    _fruitText = TextEditingController(text: _formatPortion(controller.fruit));
    _vegText = TextEditingController(text: _formatPortion(controller.veg));
    _snackLabelText = TextEditingController(text: controller.snackLabel);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _nameText.dispose();
    _stapleText.dispose();
    _meatText.dispose();
    _fruitText.dispose();
    _vegText.dispose();
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
    if (!saved) return;
    widget.onSaved?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final isSnack = controller.meal == snackMealValue;

    return Scaffold(
      appBar: AppBar(title: Text(loc.dietManualEntryTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('manual-name-field'),
                controller: _nameText,
                decoration: InputDecoration(labelText: loc.dietManualEntryNameLabel),
                onChanged: controller.setName,
              ),
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
              TextField(
                key: const Key('manual-portion-staple-field'),
                controller: _stapleText,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: loc.dietCategoryStaple),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) controller.setPortion('staple', parsed);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('manual-portion-meat-field'),
                controller: _meatText,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: loc.dietCategoryMeat),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) controller.setPortion('meat', parsed);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('manual-portion-fruit-field'),
                controller: _fruitText,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: loc.dietCategoryFruit),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) controller.setPortion('fruit', parsed);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('manual-portion-veg-field'),
                controller: _vegText,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: loc.dietCategoryVeg),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) controller.setPortion('veg', parsed);
                },
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
                      _formatTime(controller.eatenAt),
                      key: const Key('eaten-at-text'),
                    ),
                  ),
                ],
              ),
              if (controller.status == ManualEntryStatus.error &&
                  controller.error == ManualEntryError.allZeroPortions) ...[
                const SizedBox(height: 12),
                Text(
                  loc.dietManualEntryAllZeroError,
                  key: const Key('manual-all-zero-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('manual-save-button'),
                onPressed: controller.status == ManualEntryStatus.saving
                    ? null
                    : _save,
                child: Text(loc.dietSaveEntryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
