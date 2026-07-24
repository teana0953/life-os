import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/medication_reminder.dart';
import 'medication_reminders_controller.dart';

/// Add/edit form for a [MedicationReminder]: a label, an add/remove list of
/// `HH:mm` times, a 7-chip weekday selector (Sun..Sat → 0..6), an
/// every-N-weeks stepper, an anchor date, and an enabled switch. Submit is
/// blocked until the label is non-empty and at least one time and one
/// weekday are chosen (design D4 — client-basic, server-authoritative).
/// [existing] is `null` for add mode, or the reminder being edited.
class MedicationReminderForm extends StatefulWidget {
  final MedicationRemindersController controller;
  final String idToken;
  final MedicationReminder? existing;

  /// Returns the current time, used as the default anchor date. Defaults to
  /// [DateTime.now]; tests inject a fixed clock.
  final DateTime Function() clock;

  const MedicationReminderForm({
    super.key,
    required this.controller,
    required this.idToken,
    this.existing,
    this.clock = DateTime.now,
  });

  @override
  State<MedicationReminderForm> createState() =>
      _MedicationReminderFormState();
}

class _MedicationReminderFormState extends State<MedicationReminderForm> {
  late final TextEditingController _labelController;
  late List<String> _times;
  late Set<int> _daysOfWeek;
  late int _weekInterval;
  late DateTime _anchorDate;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? '');
    _times = List.of(existing?.times ?? const []);
    _daysOfWeek = Set.of(existing?.daysOfWeek ?? const []);
    _weekInterval = existing?.weekInterval ?? 1;
    _anchorDate = existing?.anchorDate ?? widget.clock();
    _enabled = existing?.enabled ?? true;
    _labelController.addListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _labelController.removeListener(_onChanged);
    _labelController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _saving => widget.controller.mutating;

  bool get _canSubmit =>
      !_saving &&
      _labelController.text.trim().isNotEmpty &&
      _times.isNotEmpty &&
      _daysOfWeek.isNotEmpty;

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      // Always 24h, regardless of locale (design: "24h HH:mm clearly
      // shown") — matches the vitals screen's time-entry convention.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _times.add(_zeroPad(picked)));
  }

  Future<void> _pickAnchorDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2000),
      lastDate: widget.clock().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _anchorDate = picked);
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim();
    final daysOfWeek = _daysOfWeek.toList()..sort();
    final existing = widget.existing;
    if (existing == null) {
      await widget.controller.create(
        widget.idToken,
        MedicationReminderDraft(
          label: label,
          times: _times,
          daysOfWeek: daysOfWeek,
          weekInterval: _weekInterval,
          anchorDate: _anchorDate,
          enabled: _enabled,
        ),
      );
    } else {
      await widget.controller.update(
        widget.idToken,
        existing.id,
        MedicationReminderUpdate(
          label: label,
          times: _times,
          daysOfWeek: daysOfWeek,
          weekInterval: _weekInterval,
          anchorDate: _anchorDate,
          enabled: _enabled,
        ),
      );
    }
    if (!mounted) return;
    // A mutation failure keeps the form open with the error shown inline;
    // success (or a reauth, surfaced by the list screen underneath) pops.
    if (widget.controller.mutationError == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? loc.medicationReminderFormTitleEdit
              : loc.medicationReminderFormTitleAdd,
        ),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('medication-reminder-label-field'),
                        controller: _labelController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: loc.medicationReminderLabelField,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.medicationReminderTimesLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      for (var i = 0; i < _times.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _times[i],
                                  key: Key('medication-reminder-time-$i'),
                                ),
                              ),
                              IconButton(
                                key: Key(
                                  'medication-reminder-remove-time-$i',
                                ),
                                tooltip: loc.medicationReminderRemoveTimeTooltip,
                                onPressed: _saving
                                    ? null
                                    : () => setState(() => _times.removeAt(i)),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      OutlinedButton(
                        key: const Key('medication-reminder-add-time'),
                        onPressed: _saving ? null : _addTime,
                        child: Text(loc.medicationReminderAddTimeButton),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.medicationReminderWeekdaysLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (var day = 0; day < 7; day++)
                            FilterChip(
                              key: Key('medication-reminder-weekday-chip-$day'),
                              label: Text(_weekdayShortLabel(loc, day)),
                              selected: _daysOfWeek.contains(day),
                              onSelected: _saving
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected) {
                                        _daysOfWeek.add(day);
                                      } else {
                                        _daysOfWeek.remove(day);
                                      }
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.medicationReminderWeekIntervalValue(
                                _weekInterval,
                              ),
                              key: const Key(
                                'medication-reminder-week-interval-value',
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key(
                              'medication-reminder-week-interval-decrement',
                            ),
                            onPressed: (_saving || _weekInterval <= 1)
                                ? null
                                : () => setState(() => _weekInterval--),
                            icon: const Icon(Icons.remove),
                          ),
                          IconButton(
                            key: const Key(
                              'medication-reminder-week-interval-increment',
                            ),
                            onPressed: _saving
                                ? null
                                : () => setState(() => _weekInterval++),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      // The anchor date only matters once weekInterval > 1
                      // (design D4) — a plain weekly reminder shouldn't be
                      // asked for an irrelevant start date.
                      if (_weekInterval > 1) ...[
                        const SizedBox(height: 12),
                        Text(
                          loc.medicationReminderAnchorDateLabel,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          key: const Key('medication-reminder-anchor-date'),
                          onPressed: _saving ? null : _pickAnchorDate,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(mediumDateLabel(context, _anchorDate)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        key: const Key('medication-reminder-enabled-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.medicationReminderEnabledLabel),
                        value: _enabled,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _enabled = value),
                      ),
                      if (widget.controller.mutationError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          loc.medicationReminderErrorGeneric,
                          key: const Key('medication-reminder-form-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      if (!_canSubmit && !_saving) ...[
                        const SizedBox(height: 8),
                        Text(
                          loc.medicationReminderIncompleteHint,
                          key: const Key('medication-reminder-incomplete-hint'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('medication-reminder-form-submit'),
                        onPressed: _canSubmit ? _submit : null,
                        child: _saving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(loc.medicationReminderSaveButton),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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

/// Formats a [TimeOfDay] as a strict ASCII "HH:mm" — manual zero-pad (NOT
/// `formatTimeOfDay`, which can localize digits/separators) so the
/// stored/wire format the backend requires stays exact (mirrors the vitals
/// screen's `_zeroPad`).
String _zeroPad(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';
