import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'keyboard_inset_calc.dart';

/// Web implementation of [KeyboardMetricsText] — shows the live browser
/// viewport numbers so the on-device (mobile) keyboard occlusion can be
/// diagnosed without a console. See `keyboard_metrics.dart`.
class KeyboardMetricsText extends StatefulWidget {
  const KeyboardMetricsText({super.key});

  @override
  State<KeyboardMetricsText> createState() => _KeyboardMetricsTextState();
}

class _KeyboardMetricsTextState extends State<KeyboardMetricsText> {
  late final JSFunction _onChange;

  @override
  void initState() {
    super.initState();
    _onChange = ((web.Event _) {
      if (mounted) setState(() {});
    }).toJS;
    final vv = web.window.visualViewport;
    vv?.addEventListener('resize', _onChange);
    vv?.addEventListener('scroll', _onChange);
  }

  @override
  void dispose() {
    final vv = web.window.visualViewport;
    vv?.removeEventListener('resize', _onChange);
    vv?.removeEventListener('scroll', _onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vv = web.window.visualViewport;
    final innerHeight = web.window.innerHeight;
    final vvHeight = vv?.height ?? 0;
    final offsetTop = vv?.offsetTop ?? 0;
    final inset = computeKeyboardInset(
      layoutHeight: innerHeight.toDouble(),
      viewportHeight: vvHeight,
      offsetTop: offsetTop,
    );
    final mq = MediaQuery.of(context);
    return Text(
      'iH=$innerHeight  vvH=${vvHeight.toStringAsFixed(0)}  '
      'off=${offsetTop.toStringAsFixed(0)}  ins=${inset.toStringAsFixed(0)}\n'
      'mqH=${mq.size.height.toStringAsFixed(0)}  '
      'mqVI=${mq.viewInsets.bottom.toStringAsFixed(0)}  '
      'dpr=${mq.devicePixelRatio.toStringAsFixed(2)}',
      key: const Key('keyboard-metrics'),
      style: const TextStyle(fontSize: 11, height: 1.2),
    );
  }
}
