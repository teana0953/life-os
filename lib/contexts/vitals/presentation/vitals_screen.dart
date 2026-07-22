import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/tracker_day_header.dart';
import 'vitals_controller.dart';

/// Vitals section: a form recording the day's weight and body fat (each
/// optional) plus three reading lists (blood pressure, blood glucose, blood
/// oxygen), saved together with an explicit Save. The shell owns loading —
/// this screen does not self-load.
class VitalsScreen extends StatefulWidget {
  final VitalsController controller;
  final String idToken;
  final String day;

  /// Returns the current time, used to resolve "today" for the header title.
  /// Defaults to [DateTime.now]; tests inject a fixed clock. Mirrors bowel.
  final DateTime Function() clock;

  const VitalsScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.clock = DateTime.now,
  });

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
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

  /// Awaits [save] then, if the controller ended in an error state, surfaces a
  /// transient save-failed snackbar over the still-rendered form. `needsReauth`
  /// routes via [build] instead, so it is left alone.
  Future<void> _save() async {
    await widget.controller.save(widget.idToken, widget.day);
    if (!mounted) return;
    if (widget.controller.status == VitalsStatus.error) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.vitalsSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;

    final busy =
        controller.status == VitalsStatus.loading ||
        controller.status == VitalsStatus.saving;

    return AsyncStateScaffold(
      isLoading: busy && controller.day == null,
      isReauth: controller.status == VitalsStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      builder: (context) {
        if (controller.day == null) {
          return Scaffold(
            body: Center(
              child: Text(
                loc.errorVitalsLoadFailed,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 3,
                  child: busy
                      ? const LinearProgressIndicator(
                          key: Key('vitals-busy'),
                          minHeight: 3,
                        )
                      : null,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      LedgeCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TrackerDayHeader(
                              day: widget.day,
                              clock: widget.clock,
                              todayTitle: loc.vitalsTitle,
                              historyTitle: loc.vitalsHistoryTitle,
                            ),
                            const SizedBox(height: 16),
                            _NullableNumberField(
                              fieldKey: const Key('vitals-weight-field'),
                              label: loc.vitalsWeightLabel,
                              value: controller.weightKg,
                              enabled: !busy,
                              onChanged: controller.setWeight,
                            ),
                            const SizedBox(height: 16),
                            _NullableNumberField(
                              fieldKey: const Key('vitals-bodyfat-field'),
                              label: loc.vitalsBodyFatLabel,
                              value: controller.bodyFatPct,
                              enabled: !busy,
                              onChanged: controller.setBodyFat,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ReadingListSection(
                        sectionId: 'bp',
                        title: loc.vitalsBloodPressureSection,
                        count: controller.bpReadings.length,
                        enabled: !busy,
                        onAdd: controller.addBpReading,
                        onRemove: controller.removeBpReading,
                        rowBuilder: (index) =>
                            _bpRow(context, controller, index, busy),
                      ),
                      const SizedBox(height: 16),
                      _ReadingListSection(
                        sectionId: 'glucose',
                        title: loc.vitalsGlucoseSection,
                        count: controller.glucoseReadings.length,
                        enabled: !busy,
                        onAdd: controller.addGlucoseReading,
                        onRemove: controller.removeGlucoseReading,
                        rowBuilder: (index) =>
                            _glucoseRow(context, controller, index, busy),
                      ),
                      const SizedBox(height: 16),
                      _ReadingListSection(
                        sectionId: 'spo2',
                        title: loc.vitalsSpo2Section,
                        count: controller.spo2Readings.length,
                        enabled: !busy,
                        onAdd: controller.addSpo2Reading,
                        onRemove: controller.removeSpo2Reading,
                        rowBuilder: (index) =>
                            _spo2Row(context, controller, index, busy),
                      ),
                      const SizedBox(height: 20),
                      if (controller.hasUnsavedChanges)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            loc.vitalsUnsavedChanges,
                            key: const Key('vitals-unsaved-indicator'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      FilledButton(
                        key: const Key('vitals-save-button'),
                        onPressed: (busy || !controller.hasUnsavedChanges)
                            ? null
                            : _save,
                        child: Text(loc.vitalsSaveButton),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bpRow(
    BuildContext context,
    VitalsController controller,
    int index,
    bool busy,
  ) {
    final loc = AppLocalizations.of(context)!;
    final reading = controller.bpReadings[index];
    return Row(
      children: [
        Expanded(
          child: _RowNumberField(
            fieldKey: Key('vitals-bp-systolic-$index'),
            label: loc.vitalsSystolicLabel,
            text: reading.systolic == 0 ? '' : '${reading.systolic}',
            enabled: !busy,
            onChanged: (v) => controller.updateBpReading(
              index,
              reading.copyWith(systolic: int.tryParse(v) ?? 0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RowNumberField(
            fieldKey: Key('vitals-bp-diastolic-$index'),
            label: loc.vitalsDiastolicLabel,
            text: reading.diastolic == 0 ? '' : '${reading.diastolic}',
            enabled: !busy,
            onChanged: (v) => controller.updateBpReading(
              index,
              reading.copyWith(diastolic: int.tryParse(v) ?? 0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RowNumberField(
            fieldKey: Key('vitals-bp-pulse-$index'),
            label: loc.vitalsPulseLabel,
            text: reading.pulse == null ? '' : '${reading.pulse}',
            enabled: !busy,
            onChanged: (v) => controller.updateBpReading(
              index,
              reading.copyWith(pulse: v.isEmpty ? null : int.tryParse(v)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _glucoseRow(
    BuildContext context,
    VitalsController controller,
    int index,
    bool busy,
  ) {
    final loc = AppLocalizations.of(context)!;
    final reading = controller.glucoseReadings[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _RowTextField(
                fieldKey: Key('vitals-glucose-label-$index'),
                label: loc.vitalsGlucoseLabelField,
                text: reading.label,
                enabled: !busy,
                onChanged: (v) => controller.updateGlucoseReading(
                  index,
                  reading.copyWith(label: v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RowNumberField(
                fieldKey: Key('vitals-glucose-value-$index'),
                label: loc.vitalsGlucoseValueLabel,
                text: reading.value == 0 ? '' : '${reading.value}',
                enabled: !busy,
                onChanged: (v) => controller.updateGlucoseReading(
                  index,
                  reading.copyWith(value: num.tryParse(v) ?? 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _QuickPick(
              pickKey: Key('vitals-glucose-before-$index'),
              label: loc.vitalsGlucoseBeforeMeal,
              onTap: busy
                  ? null
                  : () => controller.updateGlucoseReading(
                      index,
                      reading.copyWith(label: loc.vitalsGlucoseBeforeMeal),
                    ),
            ),
            const SizedBox(width: 8),
            _QuickPick(
              pickKey: Key('vitals-glucose-after-$index'),
              label: loc.vitalsGlucoseAfterMeal,
              onTap: busy
                  ? null
                  : () => controller.updateGlucoseReading(
                      index,
                      reading.copyWith(label: loc.vitalsGlucoseAfterMeal),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _spo2Row(
    BuildContext context,
    VitalsController controller,
    int index,
    bool busy,
  ) {
    final loc = AppLocalizations.of(context)!;
    final reading = controller.spo2Readings[index];
    return Row(
      children: [
        Expanded(
          child: _RowNumberField(
            fieldKey: Key('vitals-spo2-value-$index'),
            label: loc.vitalsSpo2Label,
            text: reading.spo2 == 0 ? '' : '${reading.spo2}',
            enabled: !busy,
            onChanged: (v) => controller.updateSpo2Reading(
              index,
              reading.copyWith(spo2: num.tryParse(v) ?? 0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RowNumberField(
            fieldKey: Key('vitals-spo2-pulse-$index'),
            label: loc.vitalsPulseLabel,
            text: reading.pulse == null ? '' : '${reading.pulse}',
            enabled: !busy,
            onChanged: (v) => controller.updateSpo2Reading(
              index,
              reading.copyWith(pulse: v.isEmpty ? null : int.tryParse(v)),
            ),
          ),
        ),
      ],
    );
  }
}

/// One reading-list editor (blood pressure / glucose / blood oxygen): a titled
/// [LedgeCard] holding each row (built by [rowBuilder]) with a trailing remove
/// control, and an "add" control below. [sectionId] seeds the row/add widget
/// keys. Colors/styles derive from [Theme].
class _ReadingListSection extends StatelessWidget {
  final String sectionId;
  final String title;
  final int count;
  final bool enabled;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final Widget Function(int index) rowBuilder;

  const _ReadingListSection({
    required this.sectionId,
    required this.title,
    required this.count,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var index = 0; index < count; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: rowBuilder(index)),
                  IconButton(
                    key: Key('vitals-$sectionId-remove-$index'),
                    tooltip: loc.vitalsRemoveReading,
                    onPressed: enabled ? () => onRemove(index) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('vitals-$sectionId-add'),
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add),
              label: Text(loc.vitalsAddReading),
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain, nullable numeric field (weight/body fat): empty string maps to
/// `null` (not `0`) so an unrecorded metric is never persisted as zero.
///
/// Owns a persistent [TextEditingController] so the user's raw typed string
/// survives rebuilds (e.g. "72." mid-decimal is not re-derived to "72.0",
/// which would corrupt the next keystroke into "72.05"). The field text is
/// re-seeded from [value] ONLY on an EXTERNAL change (initial load / day change
/// / reset) — detected by comparing the *parsed* values (`_parseNum`), since
/// the raw text and the parsed echo of the user's own keystroke differ as
/// strings but are equal as numbers.
class _NullableNumberField extends StatefulWidget {
  final Key fieldKey;
  final String label;
  final num? value;
  final bool enabled;
  final ValueChanged<num?> onChanged;

  const _NullableNumberField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_NullableNumberField> createState() => _NullableNumberFieldState();
}

class _NullableNumberFieldState extends State<_NullableNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value == null ? '' : '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant _NullableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_parseNum(_controller.text) != widget.value) {
      _controller.text = widget.value == null ? '' : '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (v) =>
          widget.onChanged(v.trim().isEmpty ? null : num.tryParse(v)),
    );
  }
}

/// A per-row numeric field owning a persistent [TextEditingController], synced
/// from [text] only on an external change (parsed-value comparison — same
/// rationale as [_NullableNumberField]). [onChanged] writes the raw string back
/// to the controller. Keyed by row index: on add/remove/reload the parsed-value
/// sync re-seeds any position whose draft value actually changed, and Flutter
/// disposes the controller when the row leaves the list.
class _RowNumberField extends StatefulWidget {
  final Key fieldKey;
  final String label;
  final String text;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _RowNumberField({
    required this.fieldKey,
    required this.label,
    required this.text,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_RowNumberField> createState() => _RowNumberFieldState();
}

class _RowNumberFieldState extends State<_RowNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(covariant _RowNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_parseNum(_controller.text) != _parseNum(widget.text)) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: widget.label, hintText: '0'),
      onChanged: widget.onChanged,
    );
  }
}

/// A per-row free-text field owning a persistent [TextEditingController]. Synced
/// from [text] only when it differs externally (e.g. a quick-pick fills the
/// label) — plain string compare, so mid-string edits and CJK IME composition
/// aren't disrupted by the rebuild each keystroke triggers. Follows bowel's
/// `_noteController`.
class _RowTextField extends StatefulWidget {
  final Key fieldKey;
  final String label;
  final String text;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _RowTextField({
    required this.fieldKey,
    required this.label,
    required this.text,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_RowTextField> createState() => _RowTextFieldState();
}

class _RowTextFieldState extends State<_RowTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(covariant _RowTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      enabled: widget.enabled,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: widget.onChanged,
    );
  }
}

/// A small quick-pick chip that fills a glucose row's label. Colors from
/// [Theme].
class _QuickPick extends StatelessWidget {
  final Key pickKey;
  final String label;
  final VoidCallback? onTap;

  const _QuickPick({
    required this.pickKey,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(key: pickKey, label: Text(label), onPressed: onTap);
  }
}

/// Parses a field's text to its numeric value for external-change detection:
/// empty (or blank) is `null`, otherwise `num.tryParse`. Two strings that parse
/// equal (e.g. the raw "72." and the parsed echo "72.0") are treated as the
/// same value, so a keystroke's own rebuild never re-seeds the field.
num? _parseNum(String text) =>
    text.trim().isEmpty ? null : num.tryParse(text);
