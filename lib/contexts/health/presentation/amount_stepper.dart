import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

String _format(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// A portion/gram amount's field text: empty for zero (the numeric
/// empty-zero convention — the field shows a `hintText: '0'` instead), the
/// formatted number otherwise.
String _fieldText(double value) => value == 0 ? '' : _format(value);

/// Reusable amount control: a −/+ stepper around a typable numeric field and
/// a unit label, plus (when [allowGrams]) a portion/gram mode toggle. Used by
/// the create-meal tray now, and by PR③'s in-place item edit later.
/// Presentation-only — all state (the current amount and mode) lives in the
/// caller; this widget only reports changes via [onChanged]/[onModeChanged].
class AmountStepper extends StatefulWidget {
  /// The current amount: a unit quantity, or grams when [grams] is true.
  final double value;
  final ValueChanged<double> onChanged;

  /// The unit shown after the field, e.g. the item's dictionary unit ("碗")
  /// or a generic portions word.
  final String unitLabel;

  /// The −/+ increment/decrement step.
  final double step;

  /// Whether to show the portion/gram mode toggle at all (only when the
  /// item has a defined base gram weight).
  final bool allowGrams;

  /// The current mode: entering grams (true) or a unit quantity (false).
  final bool grams;

  /// Reports a tap on the portion/gram toggle; only relevant when
  /// [allowGrams].
  final ValueChanged<bool>? onModeChanged;

  const AmountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.unitLabel,
    this.step = 1,
    this.allowGrams = false,
    this.grams = false,
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

    // A Wrap (not a fixed-width Row) so the portion/gram SegmentedButton —
    // the widest piece, especially with longer English labels — flows onto
    // its own line instead of overflowing on narrow phones (~360dp and
    // below); the −/field/+ trio stays together as one unbreakable Row.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => widget.onChanged(
                (widget.value - widget.step).clamp(0.0, double.infinity),
              ),
              icon: const Icon(Icons.remove),
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
            ),
            const SizedBox(width: 4),
            Text(widget.unitLabel, style: theme.textTheme.bodyMedium),
          ],
        ),
        if (widget.allowGrams)
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(loc.dietQuantityLabel)),
              ButtonSegment(value: true, label: Text(loc.dietGramsLabel)),
            ],
            selected: {widget.grams},
            onSelectionChanged: (selection) =>
                widget.onModeChanged?.call(selection.first),
          ),
      ],
    );
  }
}
