import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/medication_reminder.dart';
import 'medication_reminder_form.dart';
import 'medication_reminders_controller.dart';

/// The medication reminders list: each row shows a reminder's label, times,
/// and weekdays with an enable switch and a delete control; a FAB opens the
/// add form; tapping a row opens the edit form; an empty state guides the
/// user to add one. A timezone section at the top shows the locally
/// remembered timezone (design D5 — no server read) and lets the user
/// change it.
class MedicationRemindersScreen extends StatefulWidget {
  final MedicationRemindersController controller;
  final AuthRepository authRepository;

  const MedicationRemindersScreen({
    super.key,
    required this.controller,
    required this.authRepository,
  });

  @override
  State<MedicationRemindersScreen> createState() =>
      _MedicationRemindersScreenState();
}

class _MedicationRemindersScreenState
    extends State<MedicationRemindersScreen> {
  String _idToken = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    _idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await widget.controller.load(_idToken);
  }

  Future<void> _openForm({MedicationReminder? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationReminderForm(
          controller: widget.controller,
          idToken: _idToken,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(MedicationReminder reminder) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.medicationReminderDeleteConfirmTitle),
        content: Text(loc.medicationReminderDeleteConfirmMessage),
        actions: [
          TextButton(
            key: const Key('medication-reminder-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.medicationReminderCancelButton),
          ),
          FilledButton(
            key: const Key('medication-reminder-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.medicationReminderDeleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.delete(_idToken, reminder.id);
    }
  }

  // A modal bottom sheet — not an AlertDialog — with a `viewInsets` bottom
  // padding, so the on-screen keyboard doesn't hide the field/Save button on
  // mobile (mirrors `goal_card.dart`'s `_GoalEditSheet` and
  // `exercise_screen.dart`'s `_AddExerciseSheet`).
  Future<void> _editTimezone() async {
    final loc = AppLocalizations.of(context)!;
    final fieldController = TextEditingController(
      text: widget.controller.timezone,
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.medicationReminderTimezoneLabel,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('medication-reminders-timezone-field'),
                controller: fieldController,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(loc.medicationReminderCancelButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('medication-reminders-timezone-save'),
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(fieldController.text.trim()),
                      child: Text(loc.medicationReminderTimezoneSaveButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      await widget.controller.setTimezone(_idToken, result);
    }
  }

  String _weekdaysLabel(AppLocalizations loc, List<int> days) {
    final sorted = List.of(days)..sort();
    return sorted.map((d) => _weekdayShortLabel(loc, d)).join(' ');
  }

  /// Toggles [reminder]'s enabled state, then — if the mutation failed —
  /// shows a `SnackBar` in addition to the top-of-list banner, so the
  /// feedback is visible even when the row is scrolled off-screen. The
  /// switch itself already reverts on failure (bound to `controller.reminders`,
  /// which the failed mutation leaves unchanged).
  Future<void> _toggleEnabled(MedicationReminder reminder, bool value) async {
    await widget.controller.toggleEnabled(_idToken, reminder.id, value);
    if (!mounted) return;
    if (widget.controller.mutationError != null) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('medication-reminders-toggle-failed-snackbar'),
          content: Text(loc.medicationReminderErrorGeneric),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final appBar = AppBar(title: Text(loc.medicationRemindersTitle));

    return AsyncStateScaffold(
      isLoading: controller.status == MedicationRemindersStatus.loading,
      isReauth: controller.status == MedicationRemindersStatus.reauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        final theme = Theme.of(context);

        if (controller.status == MedicationRemindersStatus.error) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.medicationReminderErrorGeneric,
                    key: const Key('medication-reminders-load-error'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('medication-reminders-retry-button'),
                    onPressed: () => controller.load(_idToken),
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          floatingActionButton: FloatingActionButton(
            key: const Key('medication-reminders-add-fab'),
            onPressed: () => _openForm(),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    LedgeCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.medicationReminderTimezoneLabel,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  controller.timezone,
                                  key: const Key(
                                    'medication-reminders-timezone-value',
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const Key(
                                  'medication-reminders-timezone-edit',
                                ),
                                onPressed: _editTimezone,
                                child: Text(loc.medicationReminderTimezoneEdit),
                              ),
                            ],
                          ),
                          Text(
                            loc.medicationReminderTimezoneNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (controller.timezoneError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                loc.medicationReminderTimezoneError,
                                key: const Key(
                                  'medication-reminders-timezone-error',
                                ),
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (controller.mutationError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          loc.medicationReminderErrorGeneric,
                          key: const Key('medication-reminders-mutation-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (controller.reminders.isEmpty)
                      _EmptyState(onAdd: () => _openForm())
                    else
                      for (final reminder in controller.reminders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LedgeCard(
                            child: ListTile(
                              key: Key(
                                'medication-reminder-row-${reminder.id}',
                              ),
                              title: Text(reminder.label),
                              subtitle: Text(
                                '${reminder.times.join(', ')} · '
                                '${_weekdaysLabel(loc, reminder.daysOfWeek)}'
                                '${reminder.weekInterval > 1 ? ' ${loc.medicationReminderCadenceSuffix(reminder.weekInterval)}' : ''}',
                              ),
                              onTap: controller.mutating
                                  ? null
                                  : () => _openForm(existing: reminder),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    key: Key(
                                      'medication-reminder-switch-${reminder.id}',
                                    ),
                                    value: reminder.enabled,
                                    onChanged: controller.mutating
                                        ? null
                                        : (value) =>
                                              _toggleEnabled(reminder, value),
                                  ),
                                  IconButton(
                                    key: Key(
                                      'medication-reminder-delete-${reminder.id}',
                                    ),
                                    onPressed: controller.mutating
                                        ? null
                                        : () => _confirmDelete(reminder),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        key: const Key('medication-reminders-empty-state'),
        children: [
          Icon(
            Icons.medication_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            loc.medicationRemindersEmptyTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            loc.medicationRemindersEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('medication-reminders-empty-add-button'),
            onPressed: onAdd,
            child: Text(loc.medicationRemindersAddButton),
          ),
        ],
      ),
    );
  }
}

String _weekdayShortLabel(AppLocalizations loc, int day) => switch (day) {
  0 => loc.weekdayShortSun,
  1 => loc.weekdayShortMon,
  2 => loc.weekdayShortTue,
  3 => loc.weekdayShortWed,
  4 => loc.weekdayShortThu,
  5 => loc.weekdayShortFri,
  _ => loc.weekdayShortSat,
};
