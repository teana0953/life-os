import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/i18n/language_switcher.dart';
import '../../../shared/i18n/locale_controller.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/mascot.dart';
import '../application/sign_up.dart';
import 'login_controller.dart';

/// Card width above which the sign-in card stops growing (design.md:
/// centered, bounded-width card on wide/desktop viewports).
const _cardMaxWidth = 420.0;
const _cardPadding = 24.0;

class LoginScreen extends StatefulWidget {
  final LoginController controller;
  final LocaleController localeController;
  final SignUp signUp;

  const LoginScreen({
    super.key,
    required this.controller,
    required this.localeController,
    required this.signUp,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _submit() {
    widget.controller.submit(_emailController.text, _passwordController.text);
  }

  String? _errorText(AppLocalizations loc) {
    return switch (widget.controller.error) {
      null => null,
      LoginError.invalidCredentials => loc.errorIncorrectCredentials,
      LoginError.invalidEmail => loc.errorInvalidEmail,
      LoginError.accountDisabled => loc.errorAccountDisabled,
      LoginError.tooManyRequests => loc.errorTooManyRequests,
      LoginError.unknown => loc.errorSignInFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.controller.isLoading;
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
                    child: LanguageSwitcher(
                      controller: widget.localeController,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        key: const Key('login-card'),
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
                                loc.welcomeBack,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.signInSubtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                key: const Key('email-field'),
                                controller: _emailController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocusNode),
                                decoration: InputDecoration(
                                  labelText: loc.emailLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: const Key('password-field'),
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                enabled: !isLoading,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: loc.passwordLabel,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (errorText != null)
                                Text(
                                  errorText,
                                  key: const Key('error-message'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              FilledButton(
                                key: const Key('submit-button'),
                                onPressed: isLoading ? null : _submit,
                                child: isLoading
                                    ? Semantics(
                                        label: loc.signingIn,
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(loc.signInButton),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                key: const Key('register-link'),
                                onPressed: isLoading
                                    ? null
                                    : () => context.push('/register'),
                                child: Text(loc.noAccountLink),
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
