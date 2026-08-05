import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/date/pick_time_24h.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/care_item.dart';
import 'care_items_controller.dart';
import '../../../shared/auth/id_token_provider.dart';

const _categoryChoices = [
  CareCategory.medication,
  CareCategory.rehab,
  CareCategory.radiotherapyCare,
  CareCategory.custom,
];

const _nagIntervalChoices = [0, 5, 10, 15, 30];

String _categoryLabel(AppLocalizations loc, CareCategory category) =>
    switch (category) {
      CareCategory.medication => loc.careCategoryMedication,
      CareCategory.rehab => loc.careCategoryRehab,
      CareCategory.radiotherapyCare => loc.careCategoryRadiotherapyCare,
      CareCategory.custom => loc.careCategoryCustom,
    };

String _weekdayShortLabel(AppLocalizations loc, int day) => switch (day) {
  0 => loc.weekdayShortSun,
  1 => loc.weekdayShortMon,
  2 => loc.weekdayShortTue,
  3 => loc.weekdayShortWed,
  4 => loc.weekdayShortThu,
  5 => loc.weekdayShortFri,
  _ => loc.weekdayShortSat,
};

String _nagLabel(AppLocalizations loc, int minutes) =>
    minutes == 0 ? loc.careNagOnceLabel : loc.careNagEveryNMinutes(minutes);

/// A number formatted without a trailing `.0` when it's a whole number
/// (mirrors `PortionStepper._format`).
String _formatNum(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// The numeric-input empty-zero convention (see repo CLAUDE.md): a zero (or
/// absent) value shows as an empty field with a `0` hint, so the user can
/// type straight away.
String _initialNumText(double? value) =>
    (value == null || value == 0) ? '' : _formatNum(value);

double? _parseOptionalDouble(String text) =>
    text.trim().isEmpty ? null : double.tryParse(text.trim());

String _zeroPad(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Mutable per-row state for one schedule being edited in the form. [id] is
/// `null` for a schedule not yet persisted — kept and sent back on edit so
/// the backend upserts by id (design D5). Owns [doseQuantityController] so
/// its text survives rebuilds without cursor jumps; disposed by the owning
/// form state.
class _ScheduleDraft {
  final String? id;
  String timeOfDay;
  Set<int> weekdays;
  int weekInterval;
  DateTime startDate;
  DateTime? endDate;
  int nagIntervalMinutes;
  bool enabled;
  final TextEditingController doseQuantityController;

  _ScheduleDraft({
    this.id,
    required this.timeOfDay,
    required this.weekdays,
    required this.weekInterval,
    required this.startDate,
    this.endDate,
    required double doseQuantity,
    required this.nagIntervalMinutes,
    required this.enabled,
  }) : doseQuantityController = TextEditingController(
         text: _initialNumText(doseQuantity),
       );

  // Defaults to 1 when the field is left empty/hidden (design D2 — the
  // backend requires dose_quantity on every schedule regardless of
  // category).
  double get doseQuantity =>
      double.tryParse(doseQuantityController.text) ?? 1;

  void dispose() => doseQuantityController.dispose();
}

/// Add/edit form for a [CareItem]: a category selector, a title, a
/// multi-line note, medication-only dose/stock/low-stock fields, and an
/// add/remove list of schedules (time, weekday chips, week-interval
/// stepper, a start date shown once the interval > 1, an optional end date,
/// a nag-interval dropdown, and — medication only — a per-schedule dose
/// quantity). Submit is blocked until the title is non-empty and at least
/// one schedule is present (every schedule always has a time — adding one
/// requires picking a time first). [existing] is `null` for add mode, or
/// the item being edited.
class CareItemForm extends StatefulWidget {
  final CareItemsController controller;
  final IdTokenProvider idToken;
  final CareItem? existing;

  /// Returns the current time, used as the default start date for a new
  /// schedule. Defaults to [DateTime.now]; tests inject a fixed clock.
  final DateTime Function() clock;

  const CareItemForm({
    super.key,
    required this.controller,
    required this.idToken,
    this.existing,
    this.clock = DateTime.now,
  });

  @override
  State<CareItemForm> createState() => _CareItemFormState();
}

class _CareItemFormState extends State<CareItemForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _doseController;
  late final TextEditingController _stockController;
  late final TextEditingController _stockAlertController;
  late CareCategory _category;
  late List<_ScheduleDraft> _schedules;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _category = existing?.category ?? CareCategory.medication;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _doseController = TextEditingController(text: existing?.dose ?? '');
    _stockController = TextEditingController(
      text: _initialNumText(existing?.stock),
    );
    _stockAlertController = TextEditingController(
      text: _initialNumText(existing?.stockAlert),
    );
    _schedules = [
      for (final s in existing?.schedules ?? const <CareSchedule>[])
        _ScheduleDraft(
          id: s.id,
          timeOfDay: s.timeOfDay,
          weekdays: Set.of(s.repeatDays),
          weekInterval: s.weekInterval,
          startDate: s.startDate,
          endDate: s.endDate,
          doseQuantity: s.doseQuantity,
          nagIntervalMinutes: s.nagIntervalMinutes,
          enabled: s.enabled,
        ),
    ];
    _titleController.addListener(_onChanged);
    _noteController.addListener(_onChanged);
    _doseController.addListener(_onChanged);
    _stockController.addListener(_onChanged);
    _stockAlertController.addListener(_onChanged);
    for (final s in _schedules) {
      s.doseQuantityController.addListener(_onChanged);
    }
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _titleController.removeListener(_onChanged);
    _titleController.dispose();
    _noteController.removeListener(_onChanged);
    _noteController.dispose();
    _doseController.removeListener(_onChanged);
    _doseController.dispose();
    _stockController.removeListener(_onChanged);
    _stockController.dispose();
    _stockAlertController.removeListener(_onChanged);
    _stockAlertController.dispose();
    for (final s in _schedules) {
      s.doseQuantityController.removeListener(_onChanged);
      s.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _saving => widget.controller.mutating;

  bool get _canSubmit =>
      !_saving && _titleController.text.trim().isNotEmpty && _schedules.isNotEmpty;

  bool get _isMedication => _category == CareCategory.medication;

  Future<void> _addSchedule() async {
    final picked = await pickTime24h(context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    final draft = _ScheduleDraft(
      timeOfDay: _zeroPad(picked),
      weekdays: {},
      weekInterval: 1,
      startDate: widget.clock(),
      doseQuantity: 1,
      nagIntervalMinutes: 0,
      enabled: true,
    );
    draft.doseQuantityController.addListener(_onChanged);
    setState(() => _schedules.add(draft));
  }

  void _removeSchedule(int index) {
    setState(() {
      final draft = _schedules.removeAt(index);
      draft.doseQuantityController.removeListener(_onChanged);
      draft.dispose();
    });
  }

  Future<void> _changeTime(int index) async {
    final schedule = _schedules[index];
    final picked = await pickTime24h(
      context,
      initialTime: _parseTimeOfDay(schedule.timeOfDay),
    );
    if (picked != null) setState(() => schedule.timeOfDay = _zeroPad(picked));
  }

  Future<void> _pickStartDate(int index) async {
    final schedule = _schedules[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: schedule.startDate,
      firstDate: DateTime(2000),
      lastDate: widget.clock().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => schedule.startDate = picked);
  }

  Future<void> _pickEndDate(int index) async {
    final schedule = _schedules[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: schedule.endDate ?? schedule.startDate,
      firstDate: DateTime(2000),
      lastDate: widget.clock().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => schedule.endDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;
    final doseText = _doseController.text.trim();
    final dose = _isMedication && doseText.isNotEmpty ? doseText : null;
    final stock = _isMedication ? _parseOptionalDouble(_stockController.text) : null;
    final stockAlert = _isMedication
        ? _parseOptionalDouble(_stockAlertController.text)
        : null;
    final schedules = [
      for (final s in _schedules)
        CareSchedule(
          id: s.id,
          timeOfDay: s.timeOfDay,
          repeatDays: s.weekdays.toList()..sort(),
          weekInterval: s.weekInterval,
          startDate: s.startDate,
          endDate: s.endDate,
          doseQuantity: s.doseQuantity,
          nagIntervalMinutes: s.nagIntervalMinutes,
          enabled: s.enabled,
        ),
    ];

    final existing = widget.existing;
    if (existing == null) {
      await widget.controller.create(
        await widget.idToken(),
        CareItemDraft(
          category: _category,
          title: title,
          note: note,
          dose: dose,
          stock: stock,
          stockAlert: stockAlert,
          schedules: schedules,
        ),
      );
    } else {
      await widget.controller.update(
        await widget.idToken(),
        existing.id,
        CareItemUpdate(
          category: _category,
          title: title,
          note: note,
          dose: dose,
          stock: stock,
          stockAlert: stockAlert,
          schedules: schedules,
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

  Widget _buildScheduleRow(BuildContext context, int index) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final schedule = _schedules[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LedgeCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc.careTimeLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: loc.careChangeTimeTooltip,
                    child: OutlinedButton(
                      key: Key('care-item-schedule-time-$index'),
                      onPressed: _saving ? null : () => _changeTime(index),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(schedule.timeOfDay),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: Key('care-item-schedule-remove-$index'),
                  tooltip: loc.careRemoveScheduleTooltip,
                  onPressed: _saving ? null : () => _removeSchedule(index),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(loc.careWeekdaysLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (var day = 0; day < 7; day++)
                  FilterChip(
                    key: Key('care-item-schedule-weekday-chip-$index-$day'),
                    label: Text(_weekdayShortLabel(loc, day)),
                    selected: schedule.weekdays.contains(day),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              schedule.weekdays.add(day);
                            } else {
                              schedule.weekdays.remove(day);
                            }
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              loc.careWeekdaysEmptyHint,
              key: Key('care-item-schedule-weekdays-empty-hint-$index'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.careWeekIntervalValue(schedule.weekInterval),
                    key: Key('care-item-schedule-week-interval-value-$index'),
                  ),
                ),
                IconButton(
                  key: Key('care-item-schedule-week-interval-decrement-$index'),
                  onPressed: (_saving || schedule.weekInterval <= 1)
                      ? null
                      : () => setState(() => schedule.weekInterval--),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  key: Key('care-item-schedule-week-interval-increment-$index'),
                  onPressed: _saving
                      ? null
                      : () => setState(() => schedule.weekInterval++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            // The start date only matters once weekInterval > 1 — a plain
            // weekly schedule doesn't need an irrelevant start date shown
            // (still always sent, defaulting to today; design D3).
            if (schedule.weekInterval > 1) ...[
              const SizedBox(height: 8),
              Text(loc.careStartDateLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              OutlinedButton(
                key: Key('care-item-schedule-start-date-$index'),
                onPressed: _saving ? null : () => _pickStartDate(index),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(mediumDateLabel(context, schedule.startDate)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(loc.careEndDateLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            if (schedule.endDate == null)
              OutlinedButton(
                key: Key('care-item-schedule-end-date-add-$index'),
                onPressed: _saving ? null : () => _pickEndDate(index),
                child: Text(loc.careAddEndDateButton),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('care-item-schedule-end-date-$index'),
                      onPressed: _saving ? null : () => _pickEndDate(index),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          mediumDateLabel(context, schedule.endDate!),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('care-item-schedule-end-date-remove-$index'),
                    tooltip: loc.careRemoveEndDateTooltip,
                    onPressed: _saving
                        ? null
                        : () => setState(() => schedule.endDate = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            if (_isMedication) ...[
              const SizedBox(height: 8),
              TextField(
                key: Key('care-item-schedule-dose-quantity-$index'),
                controller: schedule.doseQuantityController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: loc.careDoseQuantityLabel,
                  hintText: '1',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(loc.careNagIntervalLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            DropdownButton<int>(
              key: Key('care-item-schedule-nag-dropdown-$index'),
              value: schedule.nagIntervalMinutes,
              isExpanded: true,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => schedule.nagIntervalMinutes = value);
                      }
                    },
              items: [
                for (final minutes in _nagIntervalChoices)
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(_nagLabel(loc, minutes)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? loc.careFormTitleEdit : loc.careFormTitleAdd),
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
                      Text(loc.careCategoryLabel, style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final category in _categoryChoices)
                            ChoiceChip(
                              key: Key(
                                'care-item-category-chip-${category.wireValue}',
                              ),
                              label: Text(_categoryLabel(loc, category)),
                              selected: _category == category,
                              onSelected: _saving
                                  ? null
                                  : (selected) {
                                      if (selected) {
                                        setState(() => _category = category);
                                      }
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('care-item-title-field'),
                        controller: _titleController,
                        enabled: !_saving,
                        decoration: InputDecoration(labelText: loc.careTitleField),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('care-item-note-field'),
                        controller: _noteController,
                        enabled: !_saving,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(labelText: loc.careNoteField),
                      ),
                      if (_isMedication) ...[
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('care-item-dose-field'),
                          controller: _doseController,
                          enabled: !_saving,
                          decoration: InputDecoration(labelText: loc.careDoseField),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('care-item-stock-field'),
                          controller: _stockController,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: loc.careStockField,
                            hintText: '0',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('care-item-stock-alert-field'),
                          controller: _stockAlertController,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: loc.careStockAlertField,
                            hintText: '0',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(loc.careSchedulesLabel, style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _schedules.length; i++)
                        _buildScheduleRow(context, i),
                      OutlinedButton(
                        key: const Key('care-item-add-schedule'),
                        onPressed: _saving ? null : _addSchedule,
                        child: Text(loc.careAddScheduleButton),
                      ),
                      if (widget.controller.mutationError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          loc.careErrorGeneric,
                          key: const Key('care-item-form-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      if (!_canSubmit && !_saving) ...[
                        const SizedBox(height: 8),
                        Text(
                          loc.careIncompleteHint,
                          key: const Key('care-item-incomplete-hint'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('care-item-form-submit'),
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
                            : Text(loc.careSaveButton),
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
