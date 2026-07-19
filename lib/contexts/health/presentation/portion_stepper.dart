import 'package:flutter/material.dart';

/// A per-category target stepper (D3 in design.md): a label, the current
/// value, and −/+ controls that adjust it by [step] (0.5, so half-portion
/// targets stay reachable), clamped at 0 and preserving decimals. Colored
/// via [color] (from `DietCategoryColors`); reports changes via [onChanged].
class PortionStepper extends StatelessWidget {
  static const double step = 0.5;

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color? color;
  final Key? decrementKey;
  final Key? incrementKey;

  /// Optional key for the tappable value text, so each category's edit entry
  /// point can be targeted uniquely in tests (mirrors [decrementKey]/
  /// [incrementKey]).
  final Key? valueKey;

  /// Optional leading category chip (D3 in design.md), e.g. a rounded icon
  /// labeled with the category's initial. Defaults to `null`, in which case
  /// the small color dot renders as before — additive, existing call sites
  /// are unaffected.
  final Widget? leadingIcon;

  const PortionStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
    this.decrementKey,
    this.incrementKey,
    this.valueKey,
    this.leadingIcon,
  });

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Future<void> _editValue(BuildContext context) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _PortionEditDialog(label: label, initial: value),
    );
    if (result != null) onChanged(result.clamp(0.0, double.infinity));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
      ),
      child: Row(
        children: [
          leadingIcon ?? CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            key: decrementKey,
            onPressed: () => onChanged((value - step).clamp(0.0, double.infinity)),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: InkWell(
              key: valueKey,
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editValue(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _format(value),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ),
          IconButton(
            key: incrementKey,
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Dialog for typing an exact target value for one category. A
/// `StatefulWidget` so its `TextEditingController` is owned and disposed by
/// the framework when the dialog closes — avoiding a per-open leak and the
/// teardown-timing issues of disposing it manually after `showDialog`
/// returns (mirrors `_QuantityEditDialog` in `quantity_card.dart`).
class _PortionEditDialog extends StatefulWidget {
  final String label;
  final double initial;

  const _PortionEditDialog({required this.label, required this.initial});

  @override
  State<_PortionEditDialog> createState() => _PortionEditDialogState();
}

class _PortionEditDialogState extends State<_PortionEditDialog> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: PortionStepper._format(widget.initial),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        key: const Key('portion-edit-field'),
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (v) => Navigator.of(context).pop(double.tryParse(v)),
      ),
      actions: [
        TextButton(
          key: const Key('portion-edit-confirm'),
          onPressed: () =>
              Navigator.of(context).pop(double.tryParse(_text.text)),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
