import 'package:flutter/material.dart';

/// The standard full-screen async-state scaffold shared by the diet-target
/// and water screens: a centered loading spinner while [isLoading], a
/// centered reauth message ([reauthMessage]) while [isReauth], and otherwise
/// the loaded content from [builder].
///
/// [isLoading] takes precedence over [isReauth]. Screen-specific states
/// beyond these two (e.g. a load-failed error) belong inside [builder].
///
/// [appBar] is optional (default `null` → the loading/reauth Scaffolds have no
/// app bar, the original behavior). A full-screen tracker pushed onto the
/// navigation stack passes its app bar so the loading and reauth states keep a
/// back button — otherwise a web/PWA user hitting reauth (e.g. a 401 on a
/// mutation) would be trapped with no way back.
class AsyncStateScaffold extends StatelessWidget {
  final bool isLoading;
  final bool isReauth;
  final String? reauthMessage;
  final PreferredSizeWidget? appBar;
  final WidgetBuilder builder;

  const AsyncStateScaffold({
    super.key,
    required this.isLoading,
    required this.isReauth,
    this.reauthMessage,
    this.appBar,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (isReauth) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text(reauthMessage ?? '', textAlign: TextAlign.center),
        ),
      );
    }
    return builder(context);
  }
}
