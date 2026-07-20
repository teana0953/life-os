import 'package:flutter/widgets.dart';

/// Widget builder signature shared by the native and web keyboard-inset
/// implementations (see `keyboard_inset.dart`).
typedef KeyboardInsetWidgetBuilder =
    Widget Function(BuildContext context, double bottomInset);

/// Native/non-web stub (design.md D1): the bottom keyboard inset is
/// `MediaQuery.of(context).viewInsets.bottom`. Inside an already-resized
/// `Scaffold` body this is 0, so this stub is a no-op on native platforms.
class KeyboardInsetBuilder extends StatelessWidget {
  final KeyboardInsetWidgetBuilder builder;

  /// Test-only override so widget tests can drive the inset value on
  /// native without a real keyboard (design.md "Testing").
  final double? debugInsetOverride;

  const KeyboardInsetBuilder({
    super.key,
    required this.builder,
    this.debugInsetOverride,
  });

  @override
  Widget build(BuildContext context) {
    final inset =
        debugInsetOverride ?? MediaQuery.of(context).viewInsets.bottom;
    return builder(context, inset);
  }
}
