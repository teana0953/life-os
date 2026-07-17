import 'package:flutter/material.dart';

import 'login_controller.dart';

class LoginScreen extends StatefulWidget {
  final LoginController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              key: const Key('email-field'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: const Key('password-field'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            if (widget.controller.errorMessage != null)
              Text(
                widget.controller.errorMessage!,
                key: const Key('error-message'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('submit-button'),
              onPressed: widget.controller.isLoading
                  ? null
                  : () => widget.controller.submit(
                      _emailController.text,
                      _passwordController.text,
                    ),
              child: widget.controller.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
