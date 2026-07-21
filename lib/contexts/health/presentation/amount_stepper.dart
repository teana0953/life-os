import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

String _format(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// A portion/measure amount's field text: empty for zero (the numeric
/// empty-zero convention — the field shows a `hintText: '0'` instead), the
/// formatted number otherwise.
String _fieldText(double value) => value == 0 ? '' : _format(value);

/// Reusable amount control: a −/+ stepper around a typable numeric field and
/// a unit label, plus (when [allowMeasure]) a portion/measure mode toggle
/// whose measure side is labeled by [measureLabel] (e.g. 公克/毫升 — never a
/// bare "g"/"ml"). Used by the create-meal tray and Today's in-place item
/// editor. Presentation-only — all state (the current amount and mode)
/// lives in the caller; this widget only reports changes via
/// [onChanged]/[onModeChanged].
class AmountStepper extends StatefulWidget {
  /// The current amount: a unit quantity, or a measure amount when
  /// [measureMode] is true.
  final double value;
  final ValueChanged<double> onChanged;

  /// The unit shown after the field, e.g. the item's dictionary unit ("碗")
  /// or a generic portions word. Never a bare "g"/"ml".
  final String unitLabel;

  /// The −/+ increment/decrement step.
  final double step;

  /// Whether to show the portion/measure mode toggle at all (only when the
  /// item has a defined base measure).
  final bool allowMeasure;

  /// The current mode: entering a measure amount (true) or a unit quantity
  /// (false).
  final bool measureMode;

  /// The measure segment's label — 公克 for a gram item, 毫升 for a
  /// millilitre item. Required when [allowMeasure] is true.
  final String? measureLabel;

  /// Reports a tap on the portion/measure toggle; only relevant when
  /// [allowMeasure].
  final ValueChanged<bool>? onModeChanged;

  const AmountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.unitLabel,
    this.step = 1,
    this.allowMeasure = false,
    this.measureMode = false,
    this.measureLabel,
    this.onModeChanged,
  });

  @override
  State<AmountStepper> createState() => _AmountStepperState();
}

class _AmountStepperState extends State<AmountStepper> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _fieldText(widget.value));
  }

  @override
  void didUpdateWidget(covariant AmountStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field's displayed text in sync with external value changes
    // (the −/+ buttons, or the caller resetting the amount on a mode
    // toggle) without clobbering an in-progress keystroke: only resync when
    // the value actually diverges from what the field currently parses to.
    final currentParsed = double.tryParse(_text.text) ?? 0;
    if (widget.value != oldWidget.value && widget.value != currentParsed) {
      _text.text = _fieldText(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onFieldChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // A fixed two-row layout (not a Wrap) so switching the mode never changes
    // the number of lines: row 1 is the −/field/+ trio plus the after-field
    // unit label; row 2 is the portion/measure SegmentedButton, always on its
    // own line. Only the after-field label's text changes with the mode, so
    // the SegmentedButton keeps a fixed position and nothing reflows.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => widget.onChanged(
                (widget.value - widget.step).clamp(0.0, double.infinity),
              ),
              icon: const Icon(Icons.remove),
              // Tightened so the trio leaves room for the after-field label to
              // fit (or ellipsize) instead of overflowing row 1 at 320dp.
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            SizedBox(
              width: 56,
              child: TextField(
                controller: _text,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: '0'),
                onChanged: _onFieldChanged,
              ),
            ),
            IconButton(
              onPressed: () => widget.onChanged(widget.value + widget.step),
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 8),
            // The after-field unit label follows the selected mode: the measure
            // unit (顆/公克/毫升) in measure mode, the portion word otherwise —
            // so the label after the number never contradicts the highlighted
            // segment. Flexible + ellipsis so a longer label (e.g. the English
            // "portion(s)") shrinks rather than overflowing the row on narrow
            // phones.
            Flexible(
              child: Text(
                widget.measureMode
                    ? (widget.measureLabel ?? widget.unitLabel)
                    : widget.unitLabel,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (widget.allowMeasure)
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(loc.dietQuantityLabel)),
              ButtonSegment(value: true, label: Text(widget.measureLabel ?? '')),
            ],
            selected: {widget.measureMode},
            onSelectionChanged: (selection) =>
                widget.onModeChanged?.call(selection.first),
          ),
      ],
    );
  }
}

/// The measure segment's label for a food's [measureUnit] — 公克 for `g`,
/// 毫升 for `ml`, the unit word itself for a household unit (顆/碗/杯),
/// `null` when the food has no measure unit (null or empty — no measure
/// toggle should be offered; empty must map to null so no blank label or
/// "9 " consumed ever renders).
String? measureLabelFor(String? measureUnit, AppLocalizations loc) {
  switch (measureUnit) {
    case null:
    case '':
      return null;
    case 'g':
      return loc.dietGramsLabel;
    case 'ml':
      return loc.dietMeasureUnitMl;
    default:
      return measureUnit;
  }
}
