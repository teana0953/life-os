import 'package:flutter/material.dart';

/// A fixed-width, centered numeric portion field following the empty-zero
/// convention: a `hintText: '0'` shows in place of a literal "0" (the caller's
/// [controller] is seeded empty for a zero value), with an optional [label].
///
/// The [controller] is owned by the caller (it seeds the empty-zero text and
/// reads the typed value back on submit). [fieldKey] is applied to the inner
/// `TextField` so existing widget-test finders keep working.
class NumericAmountField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;

  const NumericAmountField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        key: fieldKey,
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, hintText: '0'),
      ),
    );
  }
}
