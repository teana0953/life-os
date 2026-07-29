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
    final String action;
    switch (health) {
      case PushHealth.permissionPrompt:
        message = loc.careRemindersPushOffBanner;
        action = loc.careRemindersPushOffAction;
      case PushHealth.permissionDenied:
        message = loc.careRemindersPushDeniedBanner;
        action = loc.careRemindersPushDeniedAction;
      case PushHealth.unknown:
      case PushHealth.ok:
      case PushHealth.syncFailed:
      case PushHealth.unsupported:
        return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LedgeCard(
        key: const Key('push-off-banner'),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(
              key: const Key('push-off-action'),
              onPressed: () => context.push('/reminders'),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
