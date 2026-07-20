import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'keyboard_inset_calc.dart';

/// Widget builder signature shared by the native and web keyboard-inset
/// implementations (see `keyboard_inset.dart`).
typedef KeyboardInsetWidgetBuilder =
    Widget Function(BuildContext context, double bottomInset);

/// Web implementation (design.md D1): on web, the on-screen keyboard resizes
/// the browser's *visual* viewport, not the layout viewport, so
/// `MediaQuery.viewInsets.bottom` stays 0 and the `Scaffold` never resizes.
/// This subscribes to `window.visualViewport`'s `resize`/`scroll` events and
/// computes the inset via [computeKeyboardInset].
class KeyboardInsetBuilder extends StatefulWidget {
  final KeyboardInsetWidgetBuilder builder;

  /// Test-only override so widget tests can drive the inset value
  /// deterministically (design.md "Testing"). Not exercised by the (native)
  /// widget test suite for this file, since it requires a browser.
  final double? debugInsetOverride;

  const KeyboardInsetBuilder({
    super.key,
    required this.builder,
    this.debugInsetOverride,
  });

  @override
  State<KeyboardInsetBuilder> createState() => _KeyboardInsetBuilderState();
}

class _KeyboardInsetBuilderState extends State<KeyboardInsetBuilder> {
  double _bottomInset = 0;

  // Stored so the same callback ref is used for both addEventListener and
  // removeEventListener (design.md D1 / tasks.md 1.4).
  late final JSFunction _onViewportChange;

  @override
  void initState() {
    super.initState();
    _onViewportChange = _handleViewportChange.toJS;
    final viewport = web.window.visualViewport;
    viewport?.addEventListener('resize', _onViewportChange);
    viewport?.addEventListener('scroll', _onViewportChange);
    // Seed the initial inset directly — never via setState(), which would
    // throw if called during initState (e.g. if the keyboard is already open
    // when the sheet mounts).
    _bottomInset = _currentInset();
  }

  void _handleViewportChange(web.Event event) {
    final inset = _currentInset();
    if (inset == _bottomInset) return;
    if (mounted) {
      setState(() => _bottomInset = inset);
    } else {
      _bottomInset = inset;
    }
  }

  double _currentInset() {
    final viewport = web.window.visualViewport;
    if (viewport == null) return 0;
    return computeKeyboardInset(
      layoutHeight: web.window.innerHeight.toDouble(),
      viewportHeight: viewport.height,
      offsetTop: viewport.offsetTop,
    );
  }

  @override
  void dispose() {
    final viewport = web.window.visualViewport;
    viewport?.removeEventListener('resize', _onViewportChange);
    viewport?.removeEventListener('scroll', _onViewportChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = widget.debugInsetOverride ?? _bottomInset;
    return widget.builder(context, inset);
  }
}
