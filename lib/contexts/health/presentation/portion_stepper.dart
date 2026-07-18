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

  const PortionStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.color,
    this.decrementKey,
    this.incrementKey,
  });

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

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
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            key: decrementKey,
            onPressed: () => onChanged((value - step).clamp(0.0, double.infinity)),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: Text(
              _format(value),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
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
