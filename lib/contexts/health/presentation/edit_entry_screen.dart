import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'edit_entry_controller.dart';
import 'portion_form_fields.dart';

/// Bottom-sheet body for editing a past entry's name/portions/meal/
/// eaten-at, or deleting it (D5 in design.md). Pushed via
/// `showModalBottomSheet(isScrollControlled: true)` by the shell.
class EditEntryScreen extends StatefulWidget {
  final EditEntryController controller;
  final String idToken;

  /// Called after a successful save, so the caller can refresh the viewed
  /// day.
  final VoidCallback? onSaved;

  /// Called after a successful delete, so the caller can refresh the
  /// viewed day.
  final VoidCallback? onDeleted;

  final Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime)
  pickTime;

  const EditEntryScreen({
    super.key,
    required this.controller,
    required this.idToken,
    this.onSaved,
    this.onDeleted,
    this.pickTime = showPlatformTimePicker,
  });

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
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
    final saved = await widget.controller.save(widget.idToken);
    if (!saved) return;
    widget.onSaved?.call();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.dietDeleteConfirmTitle),
        content: Text(loc.dietDeleteConfirmMessage),
        actions: [
          TextButton(
            key: const Key('edit-delete-cancel-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          TextButton(
            key: const Key('edit-delete-confirm-button'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.dietDeleteEntryButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await widget.controller.delete(widget.idToken);
    if (!deleted) return;
    widget.onDeleted?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
                loc.dietEditEntryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              PortionFormFields(
                keyPrefix: 'edit',
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
              if (controller.status == EditEntryStatus.error) ...[
                const SizedBox(height: 12),
                Text(
                  controller.error == EditEntryError.reauthRequired
                      ? loc.pleaseSignInAgain
                      : loc.errorSomethingWentWrong,
                  key: const Key('edit-entry-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('edit-save-button'),
                onPressed: controller.status == EditEntryStatus.saving
                    ? null
                    : _save,
                child: Text(loc.dietSaveEntryButton),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('edit-delete-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error, width: 2),
                ),
                onPressed: controller.status == EditEntryStatus.deleting
                    ? null
                    : _delete,
                child: Text(loc.dietDeleteEntryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
