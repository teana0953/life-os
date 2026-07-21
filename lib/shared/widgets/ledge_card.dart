import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's standard "toy ledge" surface: a rounded, 2px-outlined container
/// with the downward-offset [ledgeShadow]. Shared by the diet/water section
/// cards, the settings sections, and the auth form cards.
///
/// Colors and the shadow are derived from [Theme] (never hard-coded). The
/// [borderRadius] defaults to 20 (the auth screens pass 22).
class LedgeCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Background fill; defaults to the theme's surface color.
  final Color? color;

  const LedgeCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        boxShadow: ledgeShadow(theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}
