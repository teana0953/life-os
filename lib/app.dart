import 'package:flutter/material.dart';

import 'contexts/auth/domain/auth_repository.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/auth/presentation/login_screen.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'contexts/user/presentation/home_screen.dart';
import 'shared/theme/app_theme.dart';

/// MaterialApp + auth-state routing: shows [LoginScreen] when there is no
/// authenticated user and [HomeScreen] when there is, driven by
/// [AuthRepository.authStateChanges].
class App extends StatefulWidget {
  final AuthRepository authRepository;
  final LoginController loginController;
  final HomeController homeController;

  const App({
    super.key,
    required this.authRepository,
    required this.loginController,
    required this.homeController,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late Stream<bool> _authStateChanges = widget.authRepository
      .authStateChanges;

  void _retryAuthStateChanges() {
    setState(() {
      _authStateChanges = widget.authRepository.authStateChanges;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: StreamBuilder<bool>(
        stream: _authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Something went wrong. Please try again.',
                      key: Key('auth-error-message'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('auth-retry-button'),
                      onPressed: _retryAuthStateChanges,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            return _AuthenticatedHome(
              authRepository: widget.authRepository,
              homeController: widget.homeController,
            );
          }
          return LoginScreen(controller: widget.loginController);
        },
      ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final AuthRepository authRepository;
  final HomeController homeController;

  const _AuthenticatedHome({
    required this.authRepository,
    required this.homeController,
  });

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await widget.authRepository.idToken();
    await widget.homeController.load(token ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(controller: widget.homeController);
  }
}
