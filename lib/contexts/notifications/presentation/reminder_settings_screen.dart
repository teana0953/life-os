import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/push_repository.dart';
import 'reminder_settings_controller.dart';

/// Lets the user enable Web Push notifications (grant permission + subscribe)
/// and send a test push, guiding them through blocked environments —
/// iOS-not-installed, permission denied, or an unsupported browser — instead
/// of a dead-end prompt.
class ReminderSettingsScreen extends StatefulWidget {
  final ReminderSettingsController controller;
  final AuthRepository authRepository;

  const ReminderSettingsScreen({
    super.key,
    required this.controller,
    required this.authRepository,
  });

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _enable() async {
    final idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await widget.controller.enable(idToken);
  }

  Future<void> _sendTest() async {
    final idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await widget.controller.sendTest(idToken);
    if (!mounted) return;
    if (widget.controller.testError is PushReauthRequired) return;

    final loc = AppLocalizations.of(context)!;
    final testError = widget.controller.testError;
    final message = testError != null
        ? loc.reminderTestErrorGeneric
        : (widget.controller.testResult!.sent > 0
              ? loc.reminderTestSent
              : loc.reminderTestNoDevice);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('reminder-test-snackbar'),
        content: Text(message),
      ),
    );
  }

  String? _statusText(AppLocalizations loc, ReminderSettingsStatus status) =>
      switch (status) {
        ReminderSettingsStatus.unsupported => loc.reminderStatusUnsupported,
        ReminderSettingsStatus.iosNeedsInstall =>
          loc.reminderStatusIosNeedsInstall,
        ReminderSettingsStatus.permissionDenied =>
          loc.reminderStatusPermissionDenied,
        ReminderSettingsStatus.enabled => loc.reminderEnabledStatus,
        ReminderSettingsStatus.error => loc.reminderErrorGeneric,
        ReminderSettingsStatus.idle || ReminderSettingsStatus.enabling => null,
      };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final appBar = AppBar(title: Text(loc.reminderTitle));
    final controller = widget.controller;
    final status = controller.status;
    // A lifeos re-auth requirement gets the shared full-screen reauth exit
    // (design: surfaced distinctly from a generic failure); other failures
    // stay inline with a retry button.
    final isReauth =
        status == ReminderSettingsStatus.error &&
        controller.error is PushReauthRequired;

    return AsyncStateScaffold(
      isLoading: false,
      isReauth: isReauth,
      reauthMessage: loc.pleaseSignInAgain,
      appBar: appBar,
      builder: (context) {
        final theme = Theme.of(context);
        final statusText = _statusText(loc, status);
        // idle/enabling/error(retry) all show the enable action; the
        // permanently-blocked states (unsupported/iosNeedsInstall/
        // permissionDenied) and enabled show explanation instead of a dead
        // button.
        final showEnableButton =
            status == ReminderSettingsStatus.idle ||
            status == ReminderSettingsStatus.enabling ||
            status == ReminderSettingsStatus.error;
        final enabling = status == ReminderSettingsStatus.enabling;

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    LedgeCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (statusText != null) ...[
                            Text(
                              statusText,
                              key: const Key('reminder-status-text'),
                              style: status == ReminderSettingsStatus.error
                                  ? theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                    )
                                  : theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (showEnableButton)
                            FilledButton(
                              key: const Key('reminder-enable-button'),
                              onPressed: enabling ? null : _enable,
                              child: enabling
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      status == ReminderSettingsStatus.error
                                          ? loc.retry
                                          : loc.reminderEnableButton,
                                    ),
                            ),
                          if (status == ReminderSettingsStatus.enabled) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('reminder-test-button'),
                              onPressed: controller.testInFlight
                                  ? null
                                  : _sendTest,
                              child: controller.testInFlight
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : Text(loc.reminderTestButton),
                            ),
                          ],
                          if (status ==
                              ReminderSettingsStatus.permissionDenied) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('reminder-recheck-button'),
                              onPressed: controller.load,
                              child: Text(loc.reminderRecheck),
                            ),
                          ],
                        ],
                      ),
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
