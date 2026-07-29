import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import 'push_health_controller.dart';

/// The shared "reminders won't reach you" warning, shown on the health
/// overview, 今日照護, and care reminders management so it reads identically
/// wherever the user meets it.
///
/// Only the two OS-permission states the user can act on render anything;
/// every other [PushHealth] collapses to nothing. In particular
/// [PushHealth.syncFailed] is deliberately silent — the backend subscription
/// is still registered and push still arrives, the most common cause is simply
/// being offline, and no action the user could take would clear it. That also
/// means there is nothing to retry here, so the banner carries no such action.
class PushOffBanner extends StatelessWidget {
  final PushHealth health;

  const PushOffBanner({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final String message;
    switch (health) {
      case PushHealth.permissionPrompt:
        message = loc.careRemindersPushOffBanner;
      case PushHealth.permissionDenied:
        message = loc.careRemindersPushDeniedBanner;
      case PushHealth.unknown:
      case PushHealth.ok:
      case PushHealth.syncFailed:
      case PushHealth.unsupported:
        return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // The banner is inserted into an already-open screen once push health
      // resolves asynchronously, so a screen reader would otherwise never
      // announce it.
      child: Semantics(
        container: true,
        liveRegion: true,
        child: LedgeCard(
          key: const Key('push-off-banner'),
          padding: const EdgeInsets.all(16),
          // Message above, action below (the MaterialBanner arrangement):
          // side by side, the fixed-width action leaves the message barely a
          // column of characters on a 320px phone and overflows the row.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('push-off-action'),
                  onPressed: () => context.push('/reminders'),
                  child: Text(loc.careRemindersPushOffAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
