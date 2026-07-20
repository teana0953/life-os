import 'package:flutter/widgets.dart';

/// Native fallback for [KeyboardMetricsText] — shows the framework's own
/// keyboard/viewport insets. See `keyboard_metrics.dart`.
class KeyboardMetricsText extends StatelessWidget {
  final String? extra;

  const KeyboardMetricsText({super.key, this.extra});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Text(
      'native  mqH=${mq.size.height.toStringAsFixed(0)}  '
      'viewInsets=${mq.viewInsets.bottom.toStringAsFixed(0)}'
      '${extra == null ? '' : '\n$extra'}',
      key: const Key('keyboard-metrics'),
      style: const TextStyle(fontSize: 11, height: 1.2),
    );
  }
}
