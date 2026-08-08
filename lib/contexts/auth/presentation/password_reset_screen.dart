import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/i18n/language_switcher.dart';
import '../../../shared/i18n/locale_controller.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/mascot.dart';
import '../application/send_password_reset.dart';
import 'password_reset_controller.dart';

/// Mirrors [RegisterScreen]'s card sizing.
const _cardMaxWidth = 420.0;
const _cardPadding = 24.0;

/// Asks the auth service to mail a reset link.
///
/// Its own screen rather than a dialog: a text field inside an `AlertDialog`
/// is squeezed off-screen by the keyboard on a phone (this repo has been here
/// before), and this is the same shape [RegisterScreen] already uses — a full
/// route, so the browser's back button works.
///
/// The confirmation is deliberately the **same** whether or not the address
/// has an account; see [SendPasswordReset] for why.
class PasswordResetScreen extends StatefulWidget {
  final SendPasswordReset sendPasswordReset;
  final LocaleController localeController;

  /// Whatever was typed on the sign-in screen, so the address does not have
  /// to be typed twice — someone who just failed to sign in has it on screen
  /// already.
  final String initialEmail;

  const PasswordResetScreen({
    super.key,
    required this.sendPasswordReset,
    required this.localeController,
    this.initialEmail = '',
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final PasswordResetController _controller;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _controller = PasswordResetController(widget.sendPasswordReset);
    _controller.addListener(_onControllerChanged);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String? _errorText(AppLocalizations loc) => switch (_controller.error) {
    null => null,
    PasswordResetError.invalidEmail => loc.errorInvalidEmail,
    PasswordResetError.tooManyRequests => loc.errorTooManyResetRequests,
    PasswordResetError.unknown => loc.errorSomethingWentWrong,
  };

  @override
  Widget build(BuildContext context) {
    final isLoading = _controller.isLoading;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final errorText = _errorText(loc);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < _cardMaxWidth
                  ? constraints.maxWidth
                  : _cardMaxWidth;
              return Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: LanguageSwitcher(controller: widget.localeController),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        key: const Key('password-reset-card'),
                        width: cardWidth,
                        child: LedgeCard(
                          borderRadius: 22,
                          padding: const EdgeInsets.all(_cardPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: Mascot(size: 72)),
                              const SizedBox(height: 16),
                              Text(
                                _controller.sent ? loc.passwordResetSentTitle : loc.passwordResetTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // The sent copy names the spam folder and the
                                // sender: the mail comes from a Firebase
                                // `noreply` address and is routinely filtered,
                                // which is the commonest reason a reset
                                // "doesn't work".
                                _controller.sent ? loc.passwordResetSentBody : loc.passwordResetSubtitle,
                                key: const Key('password-reset-message'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // The field and the button go away once sent:
                              // leaving them invites a second request, which
                              // the service throttles, and the user reads the
                              // throttle as the reset having failed.
                              if (!_controller.sent) ...[
                                TextField(
                                  key: const Key('email-field'),
                                  controller: _emailController,
                                  enabled: !isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _controller.submit(_emailController.text),
                                  decoration: InputDecoration(labelText: loc.emailLabel),
                                ),
                                const SizedBox(height: 16),
                                if (errorText != null) ...[
                                  Text(
                                    errorText,
                                    key: const Key('error-message'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: theme.colorScheme.error),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                FilledButton(
                                  key: const Key('submit-button'),
                                  onPressed: isLoading ? null : () => _controller.submit(_emailController.text),
                                  child: isLoading
                                      ? Semantics(
                                          label: loc.passwordResetSending,
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        )
                                      : Text(loc.passwordResetButton),
                                ),
                                const SizedBox(height: 8),
                              ],
                              TextButton(
                                key: const Key('back-to-sign-in-link'),
                                onPressed: isLoading ? null : () => context.canPop() ? context.pop() : null,
                                child: Text(loc.passwordResetBackToSignIn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
