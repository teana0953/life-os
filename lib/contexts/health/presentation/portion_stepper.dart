import 'package:flutter/material.dart';

import '../../../shared/widgets/amount_entry_dialog.dart';

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
      builder: (_) => AmountEntryDialog<double>(
        title: label,
        initialText: value == 0 ? '' : _format(value),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        parse: double.tryParse,
        fieldKey: const Key('portion-edit-field'),
        confirmKey: const Key('portion-edit-confirm'),
      ),
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
