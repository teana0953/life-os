import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'contexts/auth/application/sign_out.dart';
import 'contexts/auth/application/sign_up.dart';
import 'contexts/auth/domain/auth_repository.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/auth/presentation/login_screen.dart';
import 'contexts/health/application/get_logged_days.dart';
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
import 'contexts/health/presentation/today_controller.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'contexts/user/presentation/home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/i18n/locale_controller.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_controller.dart';

/// The locales the app ships translations for. `zh-Hant` uses
/// [Locale.fromSubtags] with `scriptCode` (not [Locale.new] with a
/// `countryCode`, which 'Hant' is not) so it matches the system locale and
/// the generated `AppLocalizations` correctly.
const supportedLocales = [
  Locale('en'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

/// Resolves an OS-reported [locale] against [supportedLocales], falling
/// back to English when there is no supported match.
Locale resolveLocale(Locale? locale, Iterable<Locale> supportedLocales) {
  if (locale != null) {
    for (final candidate in supportedLocales) {
      if (candidate.languageCode == locale.languageCode &&
          candidate.scriptCode == locale.scriptCode) {
        return candidate;
      }
    }
    for (final candidate in supportedLocales) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

/// MaterialApp + auth-state routing: shows [LoginScreen] when there is no
/// authenticated user and [HomeScreen] when there is, driven by
/// [AuthRepository.authStateChanges].
class App extends StatefulWidget {
  final AuthRepository authRepository;
  final LoginController loginController;
  final HomeController homeController;
  final LocaleController localeController;
  final ThemeController themeController;
  final SignOut signOut;
  final SignUp signUp;
  final TodayController healthTodayController;
  final DictionaryController healthDictionaryController;
  final DailyTargetController healthDailyTargetController;
  final CreateMealController healthCreateMealController;
  final GetLoggedDays healthGetLoggedDays;

  const App({
    super.key,
    required this.authRepository,
    required this.loginController,
    required this.homeController,
    required this.localeController,
    required this.themeController,
    required this.signOut,
    required this.signUp,
    required this.healthTodayController,
    required this.healthDictionaryController,
    required this.healthDailyTargetController,
    required this.healthCreateMealController,
    required this.healthGetLoggedDays,
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
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.localeController,
        widget.themeController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: widget.themeController.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: supportedLocales,
          locale: widget.localeController.locale,
          localeResolutionCallback: (locale, supported) =>
              resolveLocale(locale, supported),
          home: StreamBuilder<bool>(
            stream: _authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final loc = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.authErrorGeneric,
                          key: const Key('auth-error-message'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('auth-retry-button'),
                          onPressed: _retryAuthStateChanges,
                          child: Text(loc.retry),
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
                  localeController: widget.localeController,
                  themeController: widget.themeController,
                  signOut: widget.signOut,
                  healthTodayController: widget.healthTodayController,
                  healthDictionaryController: widget.healthDictionaryController,
                  healthDailyTargetController: widget.healthDailyTargetController,
                  healthCreateMealController: widget.healthCreateMealController,
                  healthGetLoggedDays: widget.healthGetLoggedDays,
                );
              }
              return LoginScreen(
                controller: widget.loginController,
                localeController: widget.localeController,
                signUp: widget.signUp,
              );
            },
          ),
        );
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final AuthRepository authRepository;
  final HomeController homeController;
  final LocaleController localeController;
  final ThemeController themeController;
  final SignOut signOut;
  final TodayController healthTodayController;
  final DictionaryController healthDictionaryController;
  final DailyTargetController healthDailyTargetController;
  final CreateMealController healthCreateMealController;
  final GetLoggedDays healthGetLoggedDays;

  const _AuthenticatedHome({
    required this.authRepository,
    required this.homeController,
    required this.localeController,
    required this.themeController,
    required this.signOut,
    required this.healthTodayController,
    required this.healthDictionaryController,
    required this.healthDailyTargetController,
    required this.healthCreateMealController,
    required this.healthGetLoggedDays,
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
    return HomeScreen(
      controller: widget.homeController,
      localeController: widget.localeController,
      themeController: widget.themeController,
      signOut: widget.signOut,
      authRepository: widget.authRepository,
      healthTodayController: widget.healthTodayController,
      healthDictionaryController: widget.healthDictionaryController,
      healthDailyTargetController: widget.healthDailyTargetController,
      healthCreateMealController: widget.healthCreateMealController,
      healthGetLoggedDays: widget.healthGetLoggedDays,
    );
  }
}
