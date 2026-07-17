import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/mascot.dart';
import 'login_controller.dart';

/// Card width above which the sign-in card stops growing (design.md:
/// centered, bounded-width card on wide/desktop viewports).
const _cardMaxWidth = 420.0;
const _cardPadding = 24.0;

class LoginScreen extends StatefulWidget {
  final LoginController controller;

  const LoginScreen({super.key, required this.controller});

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

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.controller.isLoading;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_cardPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < _cardMaxWidth
                  ? constraints.maxWidth
                  : _cardMaxWidth;
              return Center(
                child: SingleChildScrollView(
                  child: SizedBox(
                    key: const Key('login-card'),
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(_cardPadding),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 2,
                        ),
                        boxShadow: ledgeShadow(theme.colorScheme.outline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Mascot(size: 72)),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to Life OS',
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
                            decoration: const InputDecoration(
                              labelText: 'Email',
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
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (widget.controller.errorMessage != null)
                            Text(
                              widget.controller.errorMessage!,
                              key: const Key('error-message'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const Key('submit-button'),
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
