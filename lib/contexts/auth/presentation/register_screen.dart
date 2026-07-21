import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/i18n/language_switcher.dart';
import '../../../shared/i18n/locale_controller.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/mascot.dart';
import '../application/sign_up.dart';
import 'register_controller.dart';

/// Card width above which the register card stops growing (mirrors
/// [LoginScreen]'s `_cardMaxWidth`).
const _cardMaxWidth = 420.0;
const _cardPadding = 24.0;

class RegisterScreen extends StatefulWidget {
  final SignUp signUp;
  final LocaleController localeController;

  const RegisterScreen({
    super.key,
    required this.signUp,
    required this.localeController,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final RegisterController _controller;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = RegisterController(widget.signUp);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    // Registration succeeded: authStateChanges only swaps the app's bottom
    // route, it doesn't discard routes pushed on top of it, so this screen
    // must pop itself (see design.md D4).
    if (_controller.succeeded && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _submit() {
    _controller.submit(
      _emailController.text,
      _passwordController.text,
      _confirmPasswordController.text,
    );
  }

  String? _errorText(AppLocalizations loc) {
    return switch (_controller.error) {
      null => null,
      RegisterError.emailAlreadyInUse => loc.errorEmailAlreadyInUse,
      RegisterError.weakPassword => loc.errorWeakPassword,
      RegisterError.invalidEmail => loc.errorInvalidEmail,
      RegisterError.passwordMismatch => loc.errorPasswordMismatch,
      RegisterError.unknown => loc.errorSomethingWentWrong,
    };
  }

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
                    child: LanguageSwitcher(
                      controller: widget.localeController,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        key: const Key('register-card'),
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
                                loc.registerTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.registerSubtitle,
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
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_confirmPasswordFocusNode),
                                decoration: InputDecoration(
                                  labelText: loc.passwordLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: const Key('confirm-password-field'),
                                controller: _confirmPasswordController,
                                focusNode: _confirmPasswordFocusNode,
                                enabled: !isLoading,
                                obscureText: true,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: loc.confirmPasswordLabel,
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
                                        label: loc.signingUp,
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(loc.registerButton),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                key: const Key('sign-in-link'),
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                child: Text(loc.haveAccountLink),
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
