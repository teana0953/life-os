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

  /// Whether the numeric keyboard offers a decimal point. Defaults to `true`
  /// (portion/quantity fields accept fractions). Callers that only accept whole
  /// numbers (e.g. exercise minutes) pass `false` so the keyboard can't offer a
  /// decimal the field would silently reject.
  final bool allowDecimal;

  /// A per-field validation error, shown via `InputDecoration.errorText`
  /// right below this field. `null` (the default) shows no error — every
  /// existing caller keeps rendering exactly as before.
  final String? errorText;

  /// Whether the field accepts input. Defaults to `true` — every existing
  /// caller keeps rendering exactly as before. A caller sets this to `false`
  /// for a field that must show its current value but not be retyped (e.g.
  /// an archived budget category, which can only be cleared, not changed).
  final bool enabled;

  const NumericAmountField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.allowDecimal = true,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        decoration: InputDecoration(
          labelText: label,
          hintText: '0',
          errorText: errorText,
        ),
      ),
    );
  }
}
