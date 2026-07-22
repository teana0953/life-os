import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import 'pwa_update_controller.dart';

/// App-wide top banner shown over any screen when a newer version of the PWA
/// is ready. Reads visibility reactively from [controller]; renders nothing
/// when no update is available (or it was dismissed this session).
///
/// Mounted from `MaterialApp.builder` above the routed content, so it sits
/// outside any [Scaffold] — hence the wrapping [Material] and [SafeArea].
class PwaUpdateBanner extends StatelessWidget {
  final PwaUpdateController controller;

  const PwaUpdateBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.showBanner) return const SizedBox.shrink();
        final loc = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Material(
          color: scheme.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outline, width: 2),
              ),
              boxShadow: ledgeShadow(scheme.outline),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.updateAvailableTitle,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('pwa-update-button'),
                      onPressed: controller.applyUpdate,
                      child: Text(loc.updateButton),
                    ),
                    IconButton(
                      key: const Key('pwa-update-dismiss'),
                      tooltip: loc.updateDismiss,
                      icon: const Icon(Icons.close),
                      color: scheme.onSurfaceVariant,
                      onPressed: controller.dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
