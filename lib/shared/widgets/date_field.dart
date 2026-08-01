import 'package:flutter/material.dart';

import '../date/day_format.dart';

/// A labelled, tappable date display: shows the formatted [value] or a
/// [placeholder] when unset. Colors from [Theme]. A null [onTap] disables the
/// control.
class DateField extends StatelessWidget {
  final Key fieldKey;
  final String label;
  final DateTime? value;
  final String placeholder;
  final VoidCallback? onTap;

  const DateField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          key: fieldKey,
          onPressed: onTap,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value == null ? placeholder : mediumDateLabel(context, value!),
            ),
          ),
        ),
      ],
    );
  }
}
