import 'package:flutter/material.dart';

/// The thin bar a tracker day screen puts above its content while a
/// mutation/reload is in flight: the content below stays visible rather than
/// blanking to a full spinner. Reserves its 3px of height even when idle, so
/// the content doesn't shift as the bar comes and goes.
class TrackerBusyBar extends StatelessWidget {
  final bool busy;
  final Key indicatorKey;

  const TrackerBusyBar({
    super.key,
    required this.busy,
    required this.indicatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: busy
          ? LinearProgressIndicator(key: indicatorKey, minHeight: 3)
          : null,
    );
  }
}
