import 'package:flutter/material.dart';

/// The standard full-screen async-state scaffold shared by the diet-target
/// and water screens: a centered loading spinner while [isLoading], a
/// centered reauth message ([reauthMessage]) while [isReauth], and otherwise
/// the loaded content from [builder].
///
/// [isLoading] takes precedence over [isReauth]. Screen-specific states
/// beyond these two (e.g. a load-failed error) belong inside [builder].
class AsyncStateScaffold extends StatelessWidget {
  final bool isLoading;
  final bool isReauth;
  final String? reauthMessage;
  final WidgetBuilder builder;

  const AsyncStateScaffold({
    super.key,
    required this.isLoading,
    required this.isReauth,
    this.reauthMessage,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (isReauth) {
      return Scaffold(
        body: Center(
          child: Text(reauthMessage ?? '', textAlign: TextAlign.center),
        ),
      );
    }
    return builder(context);
  }
}
