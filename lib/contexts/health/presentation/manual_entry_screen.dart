import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'manual_entry_controller.dart';
import 'portion_form_fields.dart';

/// Bottom-sheet body for logging a food not in the dictionary: an optional
/// name, four per-group portion fields, meal selection (incl. a custom snack
/// label), an eaten-at time, and save — mirroring [QuantityCard]'s meal-chip/
/// eaten-at/onSaved pattern (D1 in design.md). The form fields themselves
/// are the shared [PortionFormFields] widget (D5), also used by the
/// edit-entry sheet. Opened via `showModalBottomSheet(isScrollControlled:
/// true)` by the dictionary sheet, mirroring [EditEntryScreen]'s sheet body
/// (SafeArea -> Padding(viewInsets) -> SingleChildScrollView -> form).
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
    this.pickTime = showPlatformTimePicker,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.dietManualEntryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              PortionFormFields(
                keyPrefix: 'manual',
                name: controller.name,
                onNameChanged: controller.setName,
                staple: controller.staple,
                meat: controller.meat,
                fruit: controller.fruit,
                veg: controller.veg,
                onPortionChanged: controller.setPortion,
                meal: controller.meal,
                onMealChanged: controller.setMeal,
                snackLabel: controller.snackLabel,
                onSnackLabelChanged: controller.setSnackLabel,
                eatenAt: controller.eatenAt,
                onEatenAtChanged: controller.setEatenAt,
                pickTime: widget.pickTime,
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
