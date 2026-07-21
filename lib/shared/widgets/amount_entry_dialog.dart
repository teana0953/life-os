import 'package:flutter/material.dart';

/// A single-field numeric entry dialog following the empty-zero convention (an
/// empty field with a `hintText: '0'` rather than a literal "0"). A
/// `StatefulWidget` so its `TextEditingController` is owned and disposed by the
/// framework.
///
/// Generic over the numeric type [T] returned when confirmed: the caller
/// supplies the [parse] used both on submit and on confirm (e.g. `int.tryParse`
/// for millilitres, `double.tryParse` for decimal portions), so number
/// semantics stay exactly as each call site needs. Both the submit action and
/// the confirm button pop `parse(currentText)` (possibly `null` for
/// unparseable input) back to the caller's `showDialog<T>`.
///
/// [initialText] is the pre-formatted starting text — callers apply their own
/// empty-zero + formatting (`value == 0 ? '' : format(value)`), since the
/// zero test and number formatting differ per call site.
class AmountEntryDialog<T> extends StatefulWidget {
  final String title;
  final String initialText;
  final TextInputType keyboardType;
  final T? Function(String) parse;

  /// Key applied to the inner text field, so each call site's existing
  /// widget-test finders keep working.
  final Key fieldKey;

  /// Key applied to the confirm button.
  final Key confirmKey;

  const AmountEntryDialog({
    super.key,
    required this.title,
    required this.initialText,
    required this.keyboardType,
    required this.parse,
    required this.fieldKey,
    required this.confirmKey,
  });

  @override
  State<AmountEntryDialog<T>> createState() => _AmountEntryDialogState<T>();
}

class _AmountEntryDialogState<T> extends State<AmountEntryDialog<T>> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _text,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: const InputDecoration(hintText: '0'),
        onSubmitted: (v) => Navigator.of(context).pop(widget.parse(v)),
      ),
      actions: [
        TextButton(
          key: widget.confirmKey,
          onPressed: () =>
              Navigator.of(context).pop(widget.parse(_text.text)),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
