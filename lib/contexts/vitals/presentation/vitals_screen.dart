import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/tracker_day_nav.dart';
import '../domain/vitals_day.dart';
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

  /// The reading list a launcher shortcut asked to start — `'glucose'` or
  /// `'bp'` (from `/health/vitals?add=…`). When set, one empty reading of that
  /// kind is added and focused, exactly once per arrival. Anything else
  /// (including `null`) leaves the screen behaving as an ordinary visit.
  final String? autoAddSection;

  const VitalsScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.clock = DateTime.now,
    this.autoAddSection,
  });

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> with TrackerDayScreen {
  @override
  String get initialDay => widget.day;
  @override
  DateTime Function() get clock => widget.clock;
  @override
  void reloadDay(String day) => widget.controller.load(widget.idToken, day);

  /// Whether [widget.autoAddSection] has already been consumed. Lives on the
  /// State (not the widget): `build` runs on every keystroke/rotation, and
  /// without this the user would collect a pile of blank rows.
  bool _autoAddConsumed = false;

  /// Which list the auto-added row is in and at what index, so the row can
  /// carry [_autoAddRowKey] and hand [_autoAddFocusNode] to its field.
  String? _autoAddKind;
  int? _autoAddIndex;

  /// Re-created per auto-add so the key never has to migrate between the
  /// glucose and bp subtrees when a second shortcut arrives.
  GlobalKey _autoAddRowKey = GlobalKey();
  final FocusNode _autoAddFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Evaluated BEFORE the listener is registered, so the synchronous
    // `notifyListeners()` inside `addXxxReading` can't call `setState` during
    // this initState. The row still lands in the very first build.
    _maybeAutoAdd();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant VitalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // go_router's pageKey is the route TEMPLATE (`/health/:name`) — it carries
    // neither the query nor the concrete name — so `?add=glucose` →
    // `?add=bp` UPDATES this Route instead of rebuilding it: same State, no
    // second `initState`. And the controller is loaded by now, so it will
    // never notify again either — resetting the flag alone would therefore do
    // nothing at all. Re-evaluate immediately.
    if (oldWidget.autoAddSection != widget.autoAddSection) {
      _autoAddConsumed = false;
      _maybeAutoAdd();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _autoAddFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
    // The mount-time path covers "already loaded"; this covers "was still
    // loading on arrival" — adding before the record lands would have the row
    // wiped by `VitalsController._applyRecord`.
    _maybeAutoAdd();
  }

  /// Starts the reading a launcher shortcut named, once the day's record has
  /// actually arrived. `error`/`needsReauth` add nothing.
  void _maybeAutoAdd() {
    if (_autoAddConsumed) return;
    final section = widget.autoAddSection;
    if (section != 'glucose' && section != 'bp') return;
    // Only past this point is this a shortcut arrival — an ordinary visit must
    // keep whatever day the user browsed to.
    //
    // A shortcut always records TODAY, but this State SURVIVES the navigation
    // (the pageKey is the route template), so the day-nav may have left
    // `viewedDay` on a past day — and `_save` writes `viewedDay`. Adding here
    // would file the reading under the browsed day, silently. Switch back
    // first; the reload notifies and brings us here again, in agreement.
    // (On the initState path `_viewedDate` initialises lazily from
    // `widget.day`, so this is never the branch taken there — `setDay`'s
    // `setState` would be illegal that early.)
    if (viewedDay != widget.day) {
      setDay(DateTime.parse(widget.day));
      return;
    }
    final controller = widget.controller;
    if (controller.status != VitalsStatus.loaded || controller.day == null) {
      return;
    }

    // Set BEFORE the add: `addGlucoseReading`/`addBpReading` notify
    // SYNCHRONOUSLY and so re-enter `_onControllerChanged` — a flag set
    // afterwards recurses until the stack blows.
    _autoAddConsumed = true;
    _autoAddKind = section;
    _autoAddRowKey = GlobalKey();
    if (section == 'glucose') {
      _autoAddIndex = controller.glucoseReadings.length;
      controller.addGlucoseReading();
    } else {
      _autoAddIndex = controller.bpReadings.length;
      controller.addBpReading();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The row is only built on the frame AFTER a notify that landed mid-build,
      // so this frame's context can be missing — `ensureVisible` would throw.
      if (!mounted || _autoAddRowKey.currentContext == null) return;
      _autoAddFocusNode.requestFocus();
      // Not the default alignment of 0: flush to the top edge scrolls the
      // section heading off, leaving the user focused on a bare number field
      // with nothing saying which reading it is.
      Scrollable.ensureVisible(
        _autoAddRowKey.currentContext!,
        alignment: 0.3,
      );
    });
  }

  /// The [GlobalKey] wrapper for the auto-added row of [kind] at [index] —
  /// applied around what `_glucoseRow`/`_bpRow` already return, so neither
  /// `_ReadingListSection` nor its `rowBuilder` signature has to change.
  Widget _autoAddWrap(String kind, int index, Widget row) =>
      (_autoAddKind == kind && _autoAddIndex == index)
      ? KeyedSubtree(key: _autoAddRowKey, child: row)
      : row;

  /// The focus node for the auto-added row's primary field — the glucose
  /// VALUE (not its free-text label) and bp's systolic.
  FocusNode? _autoAddFocusFor(String kind, int index) =>
      (_autoAddKind == kind && _autoAddIndex == index)
      ? _autoAddFocusNode
      : null;

  /// Awaits [save] then, if the controller ended in an error state, surfaces a
  /// transient save-failed snackbar over the still-rendered form. `needsReauth`
  /// routes via [build] instead, so it is left alone.
  Future<void> _save() async {
    await widget.controller.save(widget.idToken, viewedDay);
    if (!mounted) return;
    if (widget.controller.status == VitalsStatus.error) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.vitalsSaveFailed)));
    }
  }

  /// Opens the Material time picker seeded from a reading's stored "HH:mm"
  /// (parsed with a guard — see [_parseTime]) and, on a pick, writes the
  /// manually zero-padded "HH:mm" back through the existing per-list update.
  Future<void> _editBpTime(int index) async {
    final reading = widget.controller.bpReadings[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(reading.time),
    );
    if (picked == null || !mounted) return;
    widget.controller.updateBpReading(
      index,
      reading.copyWith(time: _zeroPad(picked)),
    );
  }

  Future<void> _editGlucoseTime(int index) async {
    final reading = widget.controller.glucoseReadings[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(reading.time),
    );
    if (picked == null || !mounted) return;
    widget.controller.updateGlucoseReading(
      index,
      reading.copyWith(time: _zeroPad(picked)),
    );
  }

  Future<void> _editSpo2Time(int index) async {
    final reading = widget.controller.spo2Readings[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(reading.time),
    );
    if (picked == null || !mounted) return;
    widget.controller.updateSpo2Reading(
      index,
      reading.copyWith(time: _zeroPad(picked)),
    );
  }

  /// Builds the shared, themed time control for a reading row. Placed
  /// per-list inside each `rowBuilder` (see below) so it sits where it doesn't
  /// crowd the fields — e.g. on BP's second/pulse line.
  Widget _timeChip({
    required String sectionId,
    required int index,
    required String time,
    required bool busy,
    required void Function(int index) onEdit,
  }) {
    final loc = AppLocalizations.of(context)!;
    return _TimeChip(
      chipKey: Key('vitals-$sectionId-time-$index'),
      time: time,
      tooltip: loc.vitalsTimeLabel,
      onPressed: busy ? null : () => onEdit(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;

    final busy =
        controller.status == VitalsStatus.loading ||
        controller.status == VitalsStatus.saving;

    // Shared across the loading/reauth (AsyncStateScaffold) and loaded/error
    // Scaffolds so the pushed full-screen tracker keeps a back button in every
    // state; the day switcher lives in the body's shared header below.
    final appBar = AppBar(title: Text(loc.dietTabVitals));

    return AsyncStateScaffold(
      isLoading: busy && controller.day == null,
      isReauth: controller.status == VitalsStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        if (controller.day == null) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Text(
                loc.errorVitalsLoadFailed,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
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
                  // Deliberately NOT a ListView: its lazy delegate only builds
                  // what is near the viewport, so with a few readings already
                  // logged the glucose/bp section a shortcut targets is never
                  // built — `_autoAddRowKey.currentContext` is null and both
                  // the focus and the scroll-into-view silently do nothing.
                  // The content here is a fixed handful of cards, so building
                  // it all costs nothing. `stretch` restores the full-width
                  // cross-axis sizing children got from the sliver.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dayNavHeader(
                          todayTitle: loc.vitalsTitle,
                          historyTitle: loc.vitalsHistoryTitle,
                        ),
                        const SizedBox(height: 16),
                        LedgeCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
    // Systolic/diastolic share the first line and pulse sits on the second so
    // three numeric fields (plus the mmHg/bpm units) don't overflow a narrow
    // phone row. mmHg lives in the section title; pulse carries a `bpm` suffix.
    // The time control rides the pulse line's trailing space so it never
    // squeezes the widest (first) field line.
    return _autoAddWrap(
      'bp',
      index,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _RowNumberField(
                  fieldKey: Key('vitals-bp-systolic-$index'),
                  focusNode: _autoAddFocusFor('bp', index),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RowNumberField(
                  fieldKey: Key('vitals-bp-pulse-$index'),
                  label: loc.vitalsPulseLabel,
                  text: reading.pulse == null ? '' : '${reading.pulse}',
                  enabled: !busy,
                  suffixText: loc.vitalsPulseUnit,
                  onChanged: (v) => controller.updateBpReading(
                    index,
                    reading.copyWith(pulse: v.isEmpty ? null : int.tryParse(v)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _timeChip(
                sectionId: 'bp',
                index: index,
                time: reading.time,
                busy: busy,
                onEdit: _editBpTime,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _glucoseContextLabel(
    AppLocalizations loc,
    GlucoseMealContext context,
  ) => switch (context) {
    GlucoseMealContext.fasting => loc.glucoseContextFasting,
    GlucoseMealContext.preMeal => loc.glucoseContextPreMeal,
    GlucoseMealContext.postMeal => loc.glucoseContextPostMeal,
  };

  Widget _glucoseRow(
    BuildContext context,
    VitalsController controller,
    int index,
    bool busy,
  ) {
    final loc = AppLocalizations.of(context)!;
    final reading = controller.glucoseReadings[index];
    return _autoAddWrap(
      'glucose',
      index,
      Column(
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
                  focusNode: _autoAddFocusFor('glucose', index),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Structured meal-context picker: tapping the selected chip clears it.
              for (final context in GlucoseMealContext.values)
                ChoiceChip(
                  key: Key('vitals-glucose-context-${context.name}-$index'),
                  label: Text(_glucoseContextLabel(loc, context)),
                  selected: reading.mealContext == context,
                  onSelected: busy
                      ? null
                      : (selected) => controller.updateGlucoseReading(
                          index,
                          reading.copyWith(
                            mealContext: selected ? context : null,
                          ),
                        ),
                ),
              // Rides the picker line; the surrounding `Wrap` lets it drop to
              // its own line rather than overflow on a narrow phone.
              _timeChip(
                sectionId: 'glucose',
                index: index,
                time: reading.time,
                busy: busy,
                onEdit: _editGlucoseTime,
              ),
            ],
          ),
        ],
      ),
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
    // SpO2/pulse fill the first line; the time control sits on its own second
    // line (both fields are `Expanded`, so an inline chip would squeeze them).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                suffixText: loc.vitalsPulseUnit,
                onChanged: (v) => controller.updateSpo2Reading(
                  index,
                  reading.copyWith(pulse: v.isEmpty ? null : int.tryParse(v)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _timeChip(
            sectionId: 'spo2',
            index: index,
            time: reading.time,
            busy: busy,
            onEdit: _editSpo2Time,
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
                  // The per-row time control now lives inside `rowBuilder`
                  // (placed per-list so it doesn't tax field width — e.g. on
                  // BP's second/pulse line); only the remove control stays in
                  // this uniform trailing slot.
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

  /// Optional compact unit shown inside the field (e.g. `bpm`), used where the
  /// unit doesn't fit the floating label without crowding a narrow row.
  final String? suffixText;

  /// Supplied only for the row a launcher shortcut just added, so the screen
  /// can put the cursor straight into it; `null` everywhere else (the field
  /// then owns its focus internally, as before).
  final FocusNode? focusNode;

  const _RowNumberField({
    required this.fieldKey,
    required this.label,
    required this.text,
    required this.enabled,
    required this.onChanged,
    this.suffixText,
    this.focusNode,
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
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '0',
        suffixText: widget.suffixText,
      ),
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

/// A compact per-row time control showing a reading's "HH:mm": a themed pastel
/// pill (schedule icon + time) matching the app's design language, with a tap
/// ripple as its affordance. Tapping opens the Material time picker (via
/// [onPressed]). Colors derive from [Theme]. An empty (pre-time) reading shows
/// a `--:--` placeholder rather than an empty label.
class _TimeChip extends StatelessWidget {
  final Key chipKey;
  final String time;
  final String tooltip;
  final VoidCallback? onPressed;

  const _TimeChip({
    required this.chipKey,
    required this.time,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.secondary.withValues(alpha: 0.18),
        shape: StadiumBorder(
          side: BorderSide(color: scheme.outline, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: chipKey,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  time.isEmpty ? '--:--' : time,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
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

/// Parses a field's text to its numeric value for external-change detection:
/// empty (or blank) is `null`, otherwise `num.tryParse`. Two strings that parse
/// equal (e.g. the raw "72." and the parsed echo "72.0") are treated as the
/// same value, so a keystroke's own rebuild never re-seeds the field.
num? _parseNum(String text) => text.trim().isEmpty ? null : num.tryParse(text);

/// Parses a stored "HH:mm" to a [TimeOfDay], GUARDING against an empty or
/// malformed value (a pre-time reading has `time == ''`) — falls back to the
/// current time instead of crashing.
TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length == 2) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
      return TimeOfDay(hour: h, minute: m);
    }
  }
  return TimeOfDay.now();
}

/// Formats a [TimeOfDay] as a strict ASCII "HH:mm" — manual zero-pad (NOT
/// `formatTimeOfDay`, which can localize digits/separators) so the stored/wire
/// format the backend requires stays exact.
String _zeroPad(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';
