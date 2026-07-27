import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'contexts/auth/application/sign_out.dart';
import 'contexts/auth/application/sign_up.dart';
import 'contexts/auth/domain/auth_repository.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/auth/presentation/login_screen.dart';
import 'contexts/auth/presentation/register_screen.dart';
import 'contexts/body_profile/presentation/weight_goal_controller.dart';
import 'contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'contexts/bowel/presentation/bowel_controller.dart';
import 'contexts/bowel/presentation/bowel_screen.dart';
import 'contexts/exercise/presentation/exercise_controller.dart';
import 'contexts/exercise/presentation/exercise_screen.dart';
import 'contexts/import/presentation/chaodays_import_controller.dart';
import 'contexts/import/presentation/chaodays_import_screen.dart';
import 'contexts/notifications/presentation/care_history_controller.dart';
import 'contexts/notifications/presentation/care_history_screen.dart';
import 'contexts/notifications/presentation/care_items_controller.dart';
import 'contexts/notifications/presentation/care_items_screen.dart';
import 'contexts/notifications/presentation/care_today_controller.dart';
import 'contexts/notifications/presentation/care_today_screen.dart';
import 'contexts/notifications/presentation/reminder_settings_controller.dart';
import 'contexts/notifications/presentation/reminder_settings_screen.dart';
import 'contexts/health/application/get_logged_days.dart';
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/daily_target_screen.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
import 'contexts/health/presentation/diet_day_screen.dart';
import 'contexts/health/presentation/food_search_screen.dart';
import 'contexts/health/presentation/health_scaffold.dart';
import 'contexts/health/presentation/today_controller.dart';
import 'contexts/hydration/presentation/water_controller.dart';
import 'contexts/hydration/presentation/water_screen.dart';
import 'contexts/menstrual/presentation/menstrual_controller.dart';
import 'contexts/menstrual/presentation/menstrual_screen.dart';
import 'contexts/settings/presentation/settings_screen.dart';
import 'contexts/vitals/presentation/trend_controller.dart';
import 'contexts/vitals/presentation/vitals_controller.dart';
import 'contexts/vitals/presentation/vitals_screen.dart';
import 'contexts/user/presentation/home_controller.dart';
import 'contexts/user/presentation/home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/date/day_format.dart';
import 'shared/i18n/locale_controller.dart';
import 'shared/routing/app_locations.dart';
import 'shared/routing/auth_router_notifier.dart';
import 'shared/data_revision.dart';
import 'shared/pwa/pending_deep_link.dart';
import 'shared/pwa/pending_deep_link_controller.dart';
import 'shared/pwa/pwa_install.dart';
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

/// The outcome of [resolveAuthRedirect]: where (if anywhere) to redirect, plus
/// the deep-link to keep remembering across the auth-bootstrap phase.
class AuthRedirect {
  /// The location to redirect to, or `null` to stay put.
  final String? location;

  /// The deep-link destination to carry forward (held by the router owner
  /// between redirect calls); `null` once consumed or never captured.
  final String? pendingDeepLink;

  const AuthRedirect(this.location, this.pendingDeepLink);
}

/// Pure auth-redirect decision, extracted so the cold-start deep-link flow is
/// unit-testable without driving the browser URL.
///
/// The bug this fixes: on a cold start the auth state is still `loading`, so
/// every location was redirected to `/splash`, **discarding** the originally
/// requested route (e.g. a `/care-today` opened from a push notification);
/// once auth resolved, `/splash` (transient) was sent to `/` — so the deep
/// link never opened. Here the intended destination is captured into
/// [pendingDeepLink] while loading and **replayed** once auth resolves (works
/// whether the user was already signed in or had to sign in first), instead of
/// always landing on `/`.
///
/// [loc] is the matched location (used for the gate/transient checks);
/// [deepLink] is the full URI string to remember (preserves any query).
AuthRedirect resolveAuthRedirect({
  required String loc,
  required String deepLink,
  required bool error,
  required bool loading,
  required bool signedIn,
  required String? pendingDeepLink,
}) {
  if (error) {
    return AuthRedirect(
      loc == authErrorLocation ? null : authErrorLocation,
      pendingDeepLink,
    );
  }
  if (loading) {
    // Capture a real destination (not the splash/error/gate or the default
    // home) once, so the auth bootstrap doesn't drop it.
    final capture =
        loc != '/' && !isTransientLocation(loc) && !isAuthGateLocation(loc);
    final pending = pendingDeepLink ?? (capture ? deepLink : null);
    return AuthRedirect(loc == splashLocation ? null : splashLocation, pending);
  }
  if (!signedIn) {
    return AuthRedirect(isAuthGateLocation(loc) ? null : '/login', pendingDeepLink);
  }
  // Signed in: if parked on a transient/auth-gate screen, replay the remembered
  // deep link (else home), then clear it.
  if (isAuthGateLocation(loc) || isTransientLocation(loc)) {
    final target =
        (pendingDeepLink != null && !isTransientLocation(pendingDeepLink))
        ? pendingDeepLink
        : '/';
    return AuthRedirect(target, null);
  }
  // Signed in and already on a real route: bootstrap is over, so drop any
  // remembered deep link defensively — nothing left to replay, and keeping it
  // could hijack a later navigation back to a stale target.
  return const AuthRedirect(null, null);
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
  final ChaodaysImportController chaodaysImportController;
  final ReminderSettingsController reminderSettingsController;
  final CareItemsController careItemsController;
  final CareTodayController careTodayController;
  final CareHistoryController careHistoryController;
  final DataRevision dataRevision;

  /// The SW → app hand-over for a tapped care notification's destination
  /// (design.md D1/D2). Optional so existing construction sites keep
  /// working; defaults to the platform-appropriate no-op/Cache-Storage impl
  /// via the conditional export in `pending_deep_link.dart`.
  final PendingDeepLinkStore pendingDeepLinkStore;

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
    required this.chaodaysImportController,
    required this.reminderSettingsController,
    required this.careItemsController,
    required this.careTodayController,
    required this.careHistoryController,
    required this.dataRevision,
    this.pendingDeepLinkStore = const PendingDeepLinkStoreImpl(),
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthRouterNotifier _authNotifier = AuthRouterNotifier(
    widget.authRepository,
  );
  late final GoRouter _router = _buildRouter();

  /// The deep-link destination remembered across the auth-bootstrap phase (see
  /// [resolveAuthRedirect]) so a cold-start push-notification route isn't lost.
  String? _pendingDeepLink;

  /// Consumes a care-notification hand-over (design.md D1) once auth is
  /// ready and the app has settled on a real screen; see
  /// `_scheduleDeepLinkCheck` / `_scheduleDeepLinkNavigationCheck`.
  late final PendingDeepLinkController _pendingDeepLinkController =
      PendingDeepLinkController(
        widget.pendingDeepLinkStore,
        canNavigate: () =>
            !_authNotifier.loading &&
            !_authNotifier.error &&
            _authNotifier.signedIn,
        // `currentConfiguration.uri.path` only reflects the *declarative*
        // location and does not update for an imperative `push` (go_router
        // 16.3.0) — after `push('/care-today')` it would still read `/`, so
        // the dedupe gate below could never see we'd already arrived.
        // `matches.last.matchedLocation` does track pushes.
        currentPath: () {
          final m = _router.routerDelegate.currentConfiguration.matches;
          return m.isEmpty ? '' : m.last.matchedLocation;
        },
        navigate: (path) => _router.push(path),
        // Already on the destination: nothing to push, but the checklist it
        // is showing was loaded when the screen opened, so a reminder tapped
        // from 今日照護 itself would otherwise change nothing on screen — and
        // across midnight would leave yesterday's list up (design.md D9).
        refresh: () => widget.careTodayController.load(_idToken),
      );

  @override
  void initState() {
    super.initState();
    // Registration order matters: adding our listener before `_router` is
    // first touched (below) means ours runs first when auth resolves, ahead
    // of go_router's own `refreshListenable` redirect — so the actual check
    // is deferred a frame (see `_scheduleDeepLinkCheck`) to let that redirect
    // land first (design.md D6).
    _authNotifier.addListener(_scheduleDeepLinkCheck);
    _router.routerDelegate.addListener(_scheduleDeepLinkNavigationCheck);
    _pendingDeepLinkController.start();
  }

  /// Schedules a [PendingDeepLinkController.check] for the next frame so
  /// go_router has finished its own auth redirect first (design.md D6).
  void _scheduleDeepLinkCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingDeepLinkController.check();
    });
  }

  /// Schedules a [PendingDeepLinkController.onNavigation] for the next
  /// frame — the retry point after a gate refusal (design.md D6).
  void _scheduleDeepLinkNavigationCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pendingDeepLinkController.onNavigation();
    });
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_scheduleDeepLinkCheck);
    _router.routerDelegate.removeListener(_scheduleDeepLinkNavigationCheck);
    _pendingDeepLinkController.dispose();
    _authNotifier.dispose();
    super.dispose();
  }

  String get _idToken => _authNotifier.idToken ?? '';
  String get _today => dayString(DateTime.now());

  /// Builds a day-keyed tracker screen for the `/health/<name>` route. Nested
  /// under `/health` so the URL hierarchy — which is what a web browser back /
  /// refresh reconstructs the page stack from — implies [HealthScaffold] below
  /// it. An unknown name resets to the record hub.
  Widget _trackerFor(String? name) {
    switch (name) {
      case 'water':
        return WaterScreen(
          controller: widget.waterController,
          idToken: _idToken,
          day: _today,
        );
      case 'vitals':
        return VitalsScreen(
          controller: widget.vitalsController,
          idToken: _idToken,
          day: _today,
        );
      case 'bowel':
        return BowelScreen(
          controller: widget.bowelController,
          idToken: _idToken,
          day: _today,
        );
      case 'exercise':
        return ExerciseScreen(
          controller: widget.exerciseController,
          idToken: _idToken,
          day: _today,
        );
      case 'menstrual':
        return MenstrualScreen(
          controller: widget.menstrualController,
          idToken: _idToken,
        );
      default:
        return const _Redirect(to: '/health');
    }
  }

  Widget _dietDayScreen() => DietDayScreen(
    authRepository: widget.authRepository,
    idToken: _idToken,
    todayController: widget.healthTodayController,
    dictionaryController: widget.healthDictionaryController,
    dailyTargetController: widget.healthDailyTargetController,
    createMealController: widget.healthCreateMealController,
    getLoggedDays: widget.healthGetLoggedDays,
    signOut: widget.signOut,
  );

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: _authNotifier,
      redirect: (context, state) {
        final result = resolveAuthRedirect(
          loc: state.matchedLocation,
          deepLink: state.uri.toString(),
          error: _authNotifier.error,
          loading: _authNotifier.loading,
          signedIn: _authNotifier.signedIn,
          pendingDeepLink: _pendingDeepLink,
        );
        _pendingDeepLink = result.pendingDeepLink;
        return result.location;
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
        GoRoute(
          path: '/register',
          builder: (context, state) => RegisterScreen(
            signUp: widget.signUp,
            localeController: widget.localeController,
          ),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => _AuthenticatedHome(
            authRepository: widget.authRepository,
            homeController: widget.homeController,
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsScreen(
            themeController: widget.themeController,
            localeController: widget.localeController,
            signOut: widget.signOut,
            pwaInstall: const PwaInstallImpl(),
          ),
        ),
        // No `extra`: built purely from injected DI, so a web refresh on this
        // URL reconstructs the screen.
        GoRoute(
          path: '/import/chaodays',
          builder: (context, state) => ChaodaysImportScreen(
            controller: widget.chaodaysImportController,
            authRepository: widget.authRepository,
          ),
        ),
        GoRoute(
          path: '/reminders',
          builder: (context, state) => ReminderSettingsScreen(
            controller: widget.reminderSettingsController,
            authRepository: widget.authRepository,
          ),
        ),
        GoRoute(
          path: '/care-items',
          builder: (context, state) => CareItemsScreen(
            controller: widget.careItemsController,
            authRepository: widget.authRepository,
            reminderSettingsController: widget.reminderSettingsController,
          ),
        ),
        GoRoute(
          path: '/care-today',
          builder: (context, state) => CareTodayScreen(
            controller: widget.careTodayController,
            authRepository: widget.authRepository,
            onOpenCareItems: () => context.push('/care-items'),
          ),
        ),
        GoRoute(
          path: '/care-history',
          builder: (context, state) => CareHistoryScreen(
            controller: widget.careHistoryController,
            authRepository: widget.authRepository,
          ),
        ),
        // Nested so a web back / refresh rebuilds the whole stack from the URL
        // (flat routes rebuilt only the leaf, collapsing back-navigation to the
        // grid). Screens are built from injected controllers — not carried in
        // `extra` — so a URL-driven rebuild reconstructs them.
        GoRoute(
          path: '/health',
          builder: (context, state) => HealthScaffold(
            authRepository: widget.authRepository,
            signOut: widget.signOut,
            weightGoalController: widget.weightGoalController,
            trendController: widget.trendController,
            healthCalendarController: widget.healthCalendarController,
            todayController: widget.healthTodayController,
            dictionaryController: widget.healthDictionaryController,
            dailyTargetController: widget.healthDailyTargetController,
            createMealController: widget.healthCreateMealController,
            getLoggedDays: widget.healthGetLoggedDays,
            waterController: widget.waterController,
            bowelController: widget.bowelController,
            vitalsController: widget.vitalsController,
            exerciseController: widget.exerciseController,
            menstrualController: widget.menstrualController,
            careTodayController: widget.careTodayController,
            onOpenSettings: () => context.push('/settings'),
            onOpenImport: () => context.push('/import/chaodays'),
            onOpenReminders: () => context.push('/reminders'),
            onOpenCareItems: () => context.push('/care-items'),
            onOpenCareToday: () => context.push('/care-today'),
            dataRevision: widget.dataRevision,
          ),
          routes: [
            GoRoute(
              path: 'diet',
              builder: (context, state) => _dietDayScreen(),
              routes: [
                GoRoute(
                  path: 'target',
                  // The viewed day is a per-navigation arg (diet may be browsing
                  // a past day), so it rides in `extra`; a URL-driven rebuild
                  // with no extra resets to the diet day.
                  builder: (context, state) {
                    final day = state.extra;
                    if (day is! String) return const _Redirect(to: '/health/diet');
                    return DailyTargetScreen(
                      controller: widget.healthDailyTargetController,
                      idToken: _idToken,
                      day: day,
                      onSaved: () =>
                          widget.healthTodayController.load(_idToken, day),
                    );
                  },
                ),
                GoRoute(
                  path: 'food-search',
                  // The meal and the viewed day are per-navigation args, so they
                  // ride in `extra`; a URL-driven rebuild with no extra resets to
                  // the diet day.
                  builder: (context, state) {
                    final args = state.extra;
                    if (args is! ({String meal, String day})) {
                      return const _Redirect(to: '/health/diet');
                    }
                    return FoodSearchScreen(
                      meal: args.meal,
                      dictionaryController: widget.healthDictionaryController,
                      createMealController: widget.healthCreateMealController,
                      idToken: _idToken,
                      day: args.day,
                      signOut: widget.signOut,
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: ':name',
              builder: (context, state) =>
                  _trackerFor(state.pathParameters['name']),
            ),
          ],
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

/// Redirects to [to] after the frame — used when a route can't be built for the
/// current URL (an unknown tracker name, or a food-search rebuilt by a URL-driven
/// navigation with no `extra` meal).
class _Redirect extends StatefulWidget {
  final String to;
  const _Redirect({required this.to});

  @override
  State<_Redirect> createState() => _RedirectState();
}

class _RedirectState extends State<_Redirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).go(widget.to);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
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
