import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'contexts/auth/application/sign_out.dart';
import 'contexts/auth/application/sign_up.dart';
import 'contexts/auth/domain/auth_repository.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/auth/presentation/login_screen.dart';
import 'contexts/body_profile/presentation/weight_goal_controller.dart';
import 'contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'contexts/bowel/presentation/bowel_controller.dart';
import 'contexts/exercise/presentation/exercise_controller.dart';
import 'contexts/health/application/get_logged_days.dart';
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
import 'contexts/health/presentation/today_controller.dart';
import 'contexts/hydration/presentation/water_controller.dart';
import 'contexts/menstrual/presentation/menstrual_controller.dart';
import 'contexts/vitals/presentation/trend_controller.dart';
import 'contexts/vitals/presentation/vitals_controller.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'contexts/user/presentation/home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/i18n/locale_controller.dart';
import 'shared/routing/auth_router_notifier.dart';
import 'shared/pwa/pwa_update_banner.dart';
import 'shared/pwa/pwa_update_controller.dart';
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
  final WaterController waterController;
  final BowelController bowelController;
  final VitalsController vitalsController;
  final ExerciseController exerciseController;
  final MenstrualController menstrualController;
  final WeightGoalController weightGoalController;
  final TrendController trendController;
  final HealthCalendarController healthCalendarController;
  final PwaUpdateController pwaUpdateController;

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
    required this.waterController,
    required this.bowelController,
    required this.vitalsController,
    required this.exerciseController,
    required this.menstrualController,
    required this.weightGoalController,
    required this.trendController,
    required this.healthCalendarController,
    required this.pwaUpdateController,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthRouterNotifier _authNotifier = AuthRouterNotifier(
    widget.authRepository,
  );
  late final GoRouter _router = _buildRouter();

  @override
  void dispose() {
    _authNotifier.dispose();
    super.dispose();
  }

  /// Returns the screen carried in [state].extra, or — when it is absent (e.g.
  /// a browser refresh landed directly on a pushed route, which has no in-memory
  /// extra) — a redirect back to the home grid. The app has no deep-linking, so
  /// a refreshed deep route safely resets to `/`.
  Widget _extraScreen(GoRouterState state) {
    final extra = state.extra;
    return extra is Widget ? extra : const _RedirectToHome();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _authNotifier,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        if (_authNotifier.error) return loc == '/auth-error' ? null : '/auth-error';
        if (_authNotifier.loading) return loc == '/splash' ? null : '/splash';
        final atAuthGate = loc == '/login' || loc == '/register';
        final atTransient = loc == '/splash' || loc == '/auth-error';
        if (!_authNotifier.signedIn) {
          return atAuthGate ? null : '/login';
        }
        if (atAuthGate || atTransient) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: '/auth-error',
          builder: (context, state) => _AuthErrorScreen(onRetry: _authNotifier.retry),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(
            controller: widget.loginController,
            localeController: widget.localeController,
            signUp: widget.signUp,
          ),
        ),
        // Pushed full screens carry their (already DI-wired) widget in `extra`,
        // so navigation stays at the call site and this file needs no rewiring.
        GoRoute(path: '/register', builder: (context, state) => _extraScreen(state)),
        GoRoute(
          path: '/',
          builder: (context, state) => _AuthenticatedHome(
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
            waterController: widget.waterController,
            bowelController: widget.bowelController,
            vitalsController: widget.vitalsController,
            exerciseController: widget.exerciseController,
            menstrualController: widget.menstrualController,
            weightGoalController: widget.weightGoalController,
            trendController: widget.trendController,
            healthCalendarController: widget.healthCalendarController,
          ),
        ),
        GoRoute(path: '/settings', builder: (context, state) => _extraScreen(state)),
        GoRoute(path: '/health', builder: (context, state) => _extraScreen(state)),
        GoRoute(
          path: '/health/diet/target',
          builder: (context, state) => _extraScreen(state),
        ),
        GoRoute(
          path: '/health/diet/food-search',
          builder: (context, state) => _extraScreen(state),
        ),
        // The day-keyed trackers (water / vitals / bowel / exercise / menstrual /
        // diet) — one path each (via :name) so every push is a distinct history
        // entry; the screen itself rides in `extra`.
        GoRoute(
          path: '/health/:name',
          builder: (context, state) => _extraScreen(state),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.localeController,
        widget.themeController,
      ]),
      builder: (context, _) {
        return MaterialApp.router(
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
          routerConfig: _router,
          // App-wide "update available" banner: sits above the routed content
          // over any screen, driven by the injected PwaUpdateController.
          builder: (context, child) {
            return Column(
              children: [
                PwaUpdateBanner(controller: widget.pwaUpdateController),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            );
          },
        );
      },
    );
  }
}

/// The auth-stream-error screen (retry re-subscribes via the notifier). Was
/// inlined in the old `StreamBuilder`; now a route target.
class _AuthErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _AuthErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.authErrorGeneric, key: const Key('auth-error-message')),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('auth-retry-button'),
              onPressed: onRetry,
              child: Text(loc.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a pushed route is reached without its `extra` screen (a browser
/// refresh on a deep URL): resets to the home grid after the frame.
class _RedirectToHome extends StatefulWidget {
  const _RedirectToHome();

  @override
  State<_RedirectToHome> createState() => _RedirectToHomeState();
}

class _RedirectToHomeState extends State<_RedirectToHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).go('/');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  final WaterController waterController;
  final BowelController bowelController;
  final VitalsController vitalsController;
  final ExerciseController exerciseController;
  final MenstrualController menstrualController;
  final WeightGoalController weightGoalController;
  final TrendController trendController;
  final HealthCalendarController healthCalendarController;

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
    required this.waterController,
    required this.bowelController,
    required this.vitalsController,
    required this.exerciseController,
    required this.menstrualController,
    required this.weightGoalController,
    required this.trendController,
    required this.healthCalendarController,
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
      waterController: widget.waterController,
      bowelController: widget.bowelController,
      vitalsController: widget.vitalsController,
      exerciseController: widget.exerciseController,
      menstrualController: widget.menstrualController,
      weightGoalController: widget.weightGoalController,
      trendController: widget.trendController,
      healthCalendarController: widget.healthCalendarController,
    );
  }
}
