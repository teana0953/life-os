import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'contexts/finance/presentation/finance_controller.dart';
import 'contexts/finance/presentation/networth_controller.dart';
import 'contexts/finance/presentation/finance_scaffold.dart';
import 'contexts/import/presentation/chaodays_import_controller.dart';
import 'contexts/import/presentation/chaodays_import_screen.dart';
import 'contexts/notifications/presentation/care_history_controller.dart';
import 'contexts/notifications/presentation/care_history_screen.dart';
import 'contexts/notifications/presentation/care_items_controller.dart';
import 'contexts/notifications/presentation/care_items_screen.dart';
import 'contexts/notifications/presentation/care_today_controller.dart';
import 'contexts/notifications/presentation/care_today_screen.dart';
import 'contexts/notifications/presentation/push_health_controller.dart';
import 'contexts/notifications/presentation/reminder_settings_controller.dart';
import 'contexts/notifications/presentation/reminder_settings_screen.dart';
import 'contexts/social/application/friend_use_cases.dart';
import 'contexts/social/application/invite_use_cases.dart';
import 'contexts/social/presentation/friends_screen.dart';
import 'contexts/social/presentation/invite_screen.dart';
import 'contexts/split/application/balance_use_cases.dart';
import 'contexts/split/application/expense_use_cases.dart';
import 'contexts/split/application/group_use_cases.dart';
import 'contexts/split/presentation/group_detail_screen.dart';
import 'contexts/split/presentation/split_tab_dependencies.dart';
import 'contexts/health/application/get_logged_days.dart';
import 'contexts/health/presentation/create_meal_controller.dart';
import 'contexts/health/presentation/daily_target_controller.dart';
import 'contexts/health/presentation/daily_target_screen.dart';
import 'contexts/health/presentation/dictionary_controller.dart';
import 'contexts/health/presentation/diet_day_screen.dart';
import 'contexts/health/presentation/food_search_screen.dart';
import 'contexts/health/presentation/health_scaffold.dart';
import 'contexts/health/presentation/shared_food_item_controller.dart';
import 'contexts/health/presentation/today_controller.dart';
import 'contexts/hydration/presentation/water_controller.dart';
import 'contexts/hydration/presentation/water_screen.dart';
import 'contexts/menstrual/presentation/menstrual_controller.dart';
import 'contexts/menstrual/presentation/menstrual_screen.dart';
import 'contexts/settings/presentation/settings_screen.dart';
import 'contexts/vitals/presentation/trend_controller.dart';
import 'contexts/vitals/presentation/vitals_controller.dart';
import 'contexts/vitals/presentation/vitals_screen.dart';
import 'contexts/user/application/get_profile.dart';
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
    return AuthRedirect(isAuthGateLocation(loc) ? null : loginLocation, pendingDeepLink);
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
  final SharedFoodItemController healthSharedFoodItemController;
  final GetLoggedDays healthGetLoggedDays;
  final WaterController waterController;
  final BowelController bowelController;
  final VitalsController vitalsController;
  final ExerciseController exerciseController;
  final MenstrualController menstrualController;
  final FinanceController financeController;
  final NetWorthController netWorthController;
  final WeightGoalController weightGoalController;
  final TrendController trendController;
  final HealthCalendarController healthCalendarController;
  final PwaUpdateController pwaUpdateController;
  final ChaodaysImportController chaodaysImportController;
  final ReminderSettingsController reminderSettingsController;

  /// Stateless use cases for `/friends` and `/invite` — the route builders
  /// pass these down as-is; each screen builds its own [FriendsController]/
  /// [InviteController] in its `State` (design D9), so none of these live
  /// here as a singleton.
  final ListFriends listFriends;
  final RemoveFriend removeFriend;
  final CreateInvite createInvite;
  final ListInvites listInvites;
  final RevokeInvite revokeInvite;
  final PreviewInvite previewInvite;
  final AcceptInvite acceptInvite;

  /// Stateless split-context use cases and their `GetProfile` (design D5c —
  /// resolved per-load by `SplitController`/`GroupDetailController`, not
  /// cached here) — `/finance`'s 分帳 tab and the nested `/finance/groups/:id`
  /// route build their own controllers from these, mirroring the friends
  /// use cases above (design.md, task 8.1). `listFriends` above is reused
  /// for split's candidate lists (design D5b) rather than duplicated here.
  final GetBalances splitGetBalances;
  final ListGroups splitListGroups;
  final CreateGroup splitCreateGroup;
  final GetGroup splitGetGroup;
  final GetGroupBalances splitGetGroupBalances;
  final AddGroupMember splitAddGroupMember;
  final ArchiveGroup splitArchiveGroup;
  final ListExpenses splitListExpenses;
  final CreateExpense splitCreateExpense;
  final UpdateExpense splitUpdateExpense;
  final DeleteExpense splitDeleteExpense;
  final GetProfile splitGetProfile;

  /// Drives the shared push-off banner on the health overview, 今日照護, and
  /// care reminders management (all three subscribe to it).
  final PushHealthController pushHealthController;
  final CareItemsController careItemsController;
  final CareTodayController careTodayController;
  final CareHistoryController careHistoryController;

  /// Drives the trend tab's care adherence card — a separate
  /// [CareHistoryController] instance from [careHistoryController] (design
  /// §B), sharing the same underlying repository and [dataRevision].
  final CareHistoryController careAdherenceController;
  final DataRevision dataRevision;

  /// The SW → app hand-over for a tapped care notification's destination
  /// (design.md D1/D2). Optional so existing construction sites keep
  /// working; defaults to the platform-appropriate no-op/Cache-Storage impl
  /// via the conditional export in `pending_deep_link.dart`.
  final PendingDeepLinkStore pendingDeepLinkStore;

  /// Resolves "today" for the day-keyed routes. Defaults to [DateTime.now];
  /// a test pins it — and can advance it — to reach the midnight rollover.
  final DateTime Function() clock;

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
    required this.healthSharedFoodItemController,
    required this.healthGetLoggedDays,
    required this.waterController,
    required this.bowelController,
    required this.vitalsController,
    required this.exerciseController,
    required this.menstrualController,
    required this.financeController,
    required this.netWorthController,
    required this.weightGoalController,
    required this.trendController,
    required this.healthCalendarController,
    required this.pwaUpdateController,
    required this.chaodaysImportController,
    required this.reminderSettingsController,
    required this.listFriends,
    required this.removeFriend,
    required this.createInvite,
    required this.listInvites,
    required this.revokeInvite,
    required this.previewInvite,
    required this.acceptInvite,
    required this.splitGetBalances,
    required this.splitListGroups,
    required this.splitCreateGroup,
    required this.splitGetGroup,
    required this.splitGetGroupBalances,
    required this.splitAddGroupMember,
    required this.splitArchiveGroup,
    required this.splitListExpenses,
    required this.splitCreateExpense,
    required this.splitUpdateExpense,
    required this.splitDeleteExpense,
    required this.splitGetProfile,
    required this.pushHealthController,
    required this.careItemsController,
    required this.careTodayController,
    required this.careHistoryController,
    required this.careAdherenceController,
    required this.dataRevision,
    this.pendingDeepLinkStore = const PendingDeepLinkStoreImpl(),
    this.clock = DateTime.now,
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
  /// `_scheduleDeepLinkCheck`.
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
        // Only `/care-today` can be handed over today, so this reloads that
        // one screen unconditionally; a second destination would need to
        // dispatch on the pending path instead.
        //
        // A *quiet* reload: the user is looking at that list, so it must not
        // be replaced by a spinner — nor by an error screen if the reload
        // fails (design.md D9, same rule as the post-mark reload). The token
        // is fetched fresh, like `CareTodayScreen._load` does, rather than
        // reusing `_authNotifier.idToken`: that is a snapshot from the last
        // `authStateChanges` event, which does not fire on token renewal, so
        // the overnight tap this reload exists for is exactly when it would
        // be expired.
        refresh: () async {
          final token = await widget.authRepository.idToken() ?? '';
          await widget.careTodayController.reloadQuietly(token);
        },
      );

  @override
  void initState() {
    super.initState();
    // Registration order matters: this listener is added before `_router` is
    // ever built (first `build`), so ours runs first when auth resolves, ahead
    // of go_router's own `refreshListenable` redirect — so the actual check
    // is deferred a frame (see `_scheduleDeepLinkCheck`) to let that redirect
    // land first (design.md D6).
    _authNotifier.addListener(_scheduleDeepLinkCheck);
    _authNotifier.addListener(_resetControllersOnSignOut);
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

  /// `true` while a signed-in user's data may still be loaded on the
  /// app-lifetime controllers — cleared on sign-out (design.md D2) so a
  /// subsequently signed-in user never inherits the previous user's profile
  /// (and so `isAdmin`) or net worth figures. `AuthRouterNotifier` exposes no
  /// uid to compare, only `signedIn`, so the signal is that transition
  /// (true → false) rather than "a different user signed in" — signing in as
  /// anyone else necessarily passes through a sign-out first.
  bool _wasSignedIn = false;

  void _resetControllersOnSignOut() {
    final signedIn = _authNotifier.signedIn;
    if (_wasSignedIn && !signedIn) {
      widget.homeController.reset();
      // Unlike `FinanceController`, which `FinanceScaffold` reloads on every
      // entry, nothing else clears the net worth controller.
      widget.netWorthController.reset();
      // Same reasoning for the record calendar's browsed month: nothing else
      // clears it, so the next user would open it on the previous user's
      // month (and its data) instead of their own current month.
      widget.healthCalendarController.reset();
    }
    _wasSignedIn = signedIn;
  }

  @override
  void dispose() {
    _authNotifier.removeListener(_scheduleDeepLinkCheck);
    _authNotifier.removeListener(_resetControllersOnSignOut);
    _pendingDeepLinkController.dispose();
    _authNotifier.dispose();
    super.dispose();
  }

  String get _idToken => _authNotifier.idToken ?? '';
  String get _today => dayString(widget.clock());

  /// Builds a day-keyed tracker screen for the `/health/<name>` route. Nested
  /// under `/health` so the URL hierarchy — which is what a web browser back /
  /// refresh reconstructs the page stack from — implies [HealthScaffold] below
  /// it. An unknown name resets to the record hub.
  ///
  /// [query] is the URL's query parameters — a modifier on the same screen
  /// rather than a route of its own, which is how the vitals launcher
  /// shortcuts say which reading to start (`/health/vitals?add=glucose`).
  Widget _trackerFor(String? name, Map<String, String> query) {
    switch (name) {
      case 'water':
        return WaterScreen(
          controller: widget.waterController,
          idToken: _idToken,
          day: _today,
          clock: widget.clock,
        );
      case 'vitals':
        return VitalsScreen(
          controller: widget.vitalsController,
          idToken: _idToken,
          day: _today,
          clock: widget.clock,
          autoAddSection: query['add'],
        );
      case 'bowel':
        return BowelScreen(
          controller: widget.bowelController,
          idToken: _idToken,
          day: _today,
          clock: widget.clock,
        );
      case 'exercise':
        return ExerciseScreen(
          controller: widget.exerciseController,
          idToken: _idToken,
          day: _today,
          clock: widget.clock,
        );
      case 'menstrual':
        return MenstrualScreen(
          controller: widget.menstrualController,
          idToken: _idToken,
          clock: widget.clock,
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
    clock: widget.clock,
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
          path: splashLocation,
          builder: (context, state) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: authErrorLocation,
          builder: (context, state) => _AuthErrorScreen(onRetry: _authNotifier.retry),
        ),
        GoRoute(
          path: loginLocation,
          builder: (context, state) => LoginScreen(
            controller: widget.loginController,
            localeController: widget.localeController,
            signUp: widget.signUp,
          ),
        ),
        GoRoute(
          path: registerLocation,
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
        // URL reconstructs the screen. `FriendsController` is built by the
        // screen's own `State` (design D9), not here.
        GoRoute(
          path: '/friends',
          builder: (context, state) => FriendsScreen(
            listFriends: widget.listFriends,
            removeFriend: widget.removeFriend,
            createInvite: widget.createInvite,
            listInvites: widget.listInvites,
            revokeInvite: widget.revokeInvite,
            authRepository: widget.authRepository,
            signOut: widget.signOut,
          ),
        ),
        // `key: ValueKey(token)`: go_router's `pageKey` only tracks the path
        // pattern, not the query — without this key, opening a second invite
        // link without leaving the app would reuse the first link's `State`
        // (and its `InviteController`), silently showing the first inviter
        // while consuming the first token (design D13).
        GoRoute(
          path: '/invite',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'];
            return InviteScreen(
              key: ValueKey(token),
              previewInvite: widget.previewInvite,
              acceptInvite: widget.acceptInvite,
              authRepository: widget.authRepository,
              signOut: widget.signOut,
              token: token,
            );
          },
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
            pushHealthController: widget.pushHealthController,
          ),
        ),
        GoRoute(
          path: '/care-today',
          builder: (context, state) => CareTodayScreen(
            controller: widget.careTodayController,
            authRepository: widget.authRepository,
            onOpenCareItems: () => context.push('/care-items'),
            pushHealthController: widget.pushHealthController,
          ),
        ),
        GoRoute(
          path: '/care-history',
          builder: (context, state) => CareHistoryScreen(
            controller: widget.careHistoryController,
            authRepository: widget.authRepository,
          ),
        ),
        // The three ledger/net-worth/split tabs are the shell's own internal
        // state (design.md — mirroring HealthScaffold's record hub), but a
        // group's own detail screen is nested under `/finance/groups/:id`
        // (task 8.1) — nested, not flat, for the same reason `/health`'s
        // sub-routes are: a web back button or refresh reconstructs the
        // whole stack from the URL hierarchy, where a flat route would only
        // rebuild the leaf and collapse back-navigation straight to the grid.
        GoRoute(
          path: '/finance',
          builder: (context, state) => FinanceScaffold(
            authRepository: widget.authRepository,
            controller: widget.financeController,
            netWorthController: widget.netWorthController,
            split: SplitTabDependencies(
              getBalances: widget.splitGetBalances,
              listGroups: widget.splitListGroups,
              listExpenses: widget.splitListExpenses,
              createExpense: widget.splitCreateExpense,
              updateExpense: widget.splitUpdateExpense,
              deleteExpense: widget.splitDeleteExpense,
              createGroup: widget.splitCreateGroup,
              listFriends: widget.listFriends,
              getProfile: widget.splitGetProfile,
              // Just the group id: the caller's own id (design D5c) is
              // resolved by the group screen itself from `/api/me`. It used
              // to ride in a `?self=` query parameter, which made every
              // permission gate on that screen a function of a shareable,
              // hand-editable, history-persisted URL — a link carrying
              // someone else's id offered the creator-only archive and the
              // payer-only edit to a viewer who was neither.
              onOpenGroup: (context, groupId) =>
                  context.push<void>('/finance/groups/$groupId'),
              // `push`, not `go`: adding a friend is a detour, and the user
              // is expected back on the split tab afterwards.
              onAddFriend: (context) => context.push('/friends'),
            ),
            clock: widget.clock,
          ),
          routes: [
            GoRoute(
              path: 'groups/:id',
              builder: (context, state) {
                final groupId = state.pathParameters['id']!;
                return GroupDetailScreen(
                  // go_router's `pageKey` is derived from the path
                  // *pattern* only, not the matched `:id` — without this key,
                  // opening a second group from the first group's screen
                  // (in-app push, no intervening pop) would reuse the first
                  // group's `State`, and with it its `GroupDetailController`,
                  // silently showing the first group's data under the new
                  // URL (the friends change's invite-token bug, same shape).
                  key: ValueKey(groupId),
                  getGroup: widget.splitGetGroup,
                  getGroupBalances: widget.splitGetGroupBalances,
                  listExpenses: widget.splitListExpenses,
                  addGroupMember: widget.splitAddGroupMember,
                  archiveGroup: widget.splitArchiveGroup,
                  createExpense: widget.splitCreateExpense,
                  updateExpense: widget.splitUpdateExpense,
                  deleteExpense: widget.splitDeleteExpense,
                  listFriends: widget.listFriends,
                  getProfile: widget.splitGetProfile,
                  authRepository: widget.authRepository,
                  groupId: groupId,
                  clock: widget.clock,
                );
              },
            ),
          ],
        ),
        // Nested so a web back / refresh rebuilds the whole stack from the URL
        // (flat routes rebuilt only the leaf, collapsing back-navigation to the
        // grid). Screens are built from injected controllers — not carried in
        // `extra` — so a URL-driven rebuild reconstructs them.
        GoRoute(
          path: '/health',
          builder: (context, state) => HealthScaffold(
            pushHealthController: widget.pushHealthController,
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
            careAdherenceController: widget.careAdherenceController,
            onOpenSettings: () => context.push('/settings'),
            onOpenImport: () => context.push('/import/chaodays'),
            onOpenReminders: () => context.push('/reminders'),
            onOpenCareItems: () => context.push('/care-items'),
            onOpenCareToday: () => context.push('/care-today'),
            onOpenCareHistory: () => context.push('/care-history'),
            dataRevision: widget.dataRevision,
            clock: widget.clock,
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
                    return ListenableBuilder(
                      listenable: widget.homeController,
                      builder: (context, _) => FoodSearchScreen(
                        meal: args.meal,
                        dictionaryController: widget.healthDictionaryController,
                        createMealController: widget.healthCreateMealController,
                        idToken: _idToken,
                        day: args.day,
                        signOut: widget.signOut,
                        isAdmin: widget.homeController.profile?.isAdmin ?? false,
                        sharedFoodItemController: widget.healthSharedFoodItemController,
                        onNeedProfile: () =>
                            widget.homeController.ensureLoaded(_idToken),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'dictionary',
                  // The same full-screen search with no target meal: a lookup
                  // that asks which meal only at completion. In-app, the viewed
                  // day and its meal names ride in `extra`; a launcher shortcut
                  // is pure URL and carries none, so that case builds
                  // [_UrlDictionaryScreen], which supplies both itself.
                  builder: (context, state) {
                    final args = state.extra;
                    if (args is ({String day, List<String> mealNames})) {
                      return ListenableBuilder(
                        listenable: widget.homeController,
                        builder: (context, _) => FoodSearchScreen(
                          meal: null,
                          mealNames: args.mealNames,
                          dictionaryController: widget.healthDictionaryController,
                          createMealController: widget.healthCreateMealController,
                          idToken: _idToken,
                          day: args.day,
                          signOut: widget.signOut,
                          isAdmin: widget.homeController.profile?.isAdmin ?? false,
                          sharedFoodItemController: widget.healthSharedFoodItemController,
                          onNeedProfile: () =>
                              widget.homeController.ensureLoaded(_idToken),
                        ),
                      );
                    }
                    return _UrlDictionaryScreen(
                      todayController: widget.healthTodayController,
                      dictionaryController: widget.healthDictionaryController,
                      createMealController: widget.healthCreateMealController,
                      sharedFoodItemController: widget.healthSharedFoodItemController,
                      homeController: widget.homeController,
                      idToken: _idToken,
                      day: _today,
                      signOut: widget.signOut,
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: ':name',
              builder: (context, state) => _trackerFor(
                state.pathParameters['name'],
                state.uri.queryParameters,
              ),
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

/// The food dictionary reached by URL alone — a launcher shortcut, or a web
/// refresh — with none of the `extra` an in-app navigation carries.
///
/// It cannot just build [FoodSearchScreen] straight away: `mealNames` is a
/// CONSTRUCTION-TIME snapshot and the route builder is not re-run when the
/// shared [TodayController] later notifies, so a cold start would freeze in the
/// empty list that is in place while the health shell's load is still in
/// flight — and every snack recorded from here would then be named the base
/// name and collide with the day's existing one.
class _UrlDictionaryScreen extends StatefulWidget {
  final TodayController todayController;
  final DictionaryController dictionaryController;
  final CreateMealController createMealController;
  final SharedFoodItemController sharedFoodItemController;
  final HomeController homeController;
  final String idToken;
  final String day;
  final SignOut signOut;

  const _UrlDictionaryScreen({
    required this.todayController,
    required this.dictionaryController,
    required this.createMealController,
    required this.sharedFoodItemController,
    required this.homeController,
    required this.idToken,
    required this.day,
    required this.signOut,
  });

  @override
  State<_UrlDictionaryScreen> createState() => _UrlDictionaryScreenState();
}

class _UrlDictionaryScreenState extends State<_UrlDictionaryScreen> {
  /// One-shot WITHIN a given [day]: this screen has already asked for its own
  /// load, so a failing one can't turn into a loop. Reset only when [day]
  /// itself changes (the midnight rollover in [didUpdateWidget]) or when the
  /// user explicitly retries.
  bool _requestedLoad = false;

  /// The day the shared [TodayController] was holding when this screen took it
  /// over. The diet day underneath keeps its own `_viewedDate`/`_day` and only
  /// reloads on its own day-switch, so restoring today unconditionally would
  /// leave it showing TODAY's meals under a PAST day's header — and, worse,
  /// filing food added from there under the past day it still points at.
  String? _returnDay;

  @override
  void initState() {
    super.initState();
    widget.todayController.addListener(_onChanged);
    // All three calls below notify SYNCHRONOUSLY, and this screen is mounted in
    // the middle of a router stack rebuild — a notify there marks other
    // listeners (the diet day's TodayScreen below, an outgoing FoodSearchScreen)
    // dirty mid-build and throws. Hence post-frame, and hence not in the route
    // builder either.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // What `DietDayScreen._openDictionary` does before pushing — without it
      // an abandoned per-meal tray (and its target meal) leaks in and the
      // dictionary opens showing recording controls.
      widget.createMealController.start(null);
      widget.dictionaryController.clearSearch();
      _ensureDayLoaded();
    });
  }

  @override
  void didUpdateWidget(covariant _UrlDictionaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `day` comes from `_today`, recomputed on every App rebuild — so sitting
    // here across midnight changes it. `_requestedLoad` is one-shot and never
    // resets, so without this the build below would keep seeing
    // `log.day != widget.day` with nobody left to fix it: the permanent spinner
    // D7 exists to prevent.
    if (oldWidget.day != widget.day) {
      _requestedLoad = false;
      // Post-frame for the same reason `initState` is: `load` notifies
      // SYNCHRONOUSLY and the TodayScreen below has a bare `setState` listener,
      // so calling it from here throws "setState() called during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureDayLoaded();
      });
    }
  }

  @override
  void dispose() {
    widget.todayController.removeListener(_onChanged);
    // Arriving by URL means `go`, so the `true` this screen pops has nobody to
    // catch it (in-app it is an `await push<bool>`) and the diet day underneath
    // would still show the record it held before the food was added. `dispose`
    // rather than `PopScope` because it also covers being replaced by another
    // `go`; the worst case is one harmless extra reload. Post-frame again: the
    // tree is locked while this screen is being unmounted.
    final controller = widget.todayController;
    final idToken = widget.idToken;
    // The borrowed day if this screen took the controller over, today
    // otherwise. `_ensureDayLoaded` captures `_returnDay` before it can fail,
    // so a takeover whose load then failed still hands the day back.
    final day = _returnDay ?? widget.day;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.load(idToken, day),
    );
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    // The diet day sitting below this screen in the stack reloads the SAME
    // controller from its own `initState`, and the URL-driven stack builds it
    // after this screen — so the notification can land mid-build, where
    // `setState` throws. Re-run on the next frame instead.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onChanged());
      return;
    }
    setState(() {});
    _ensureDayLoaded();
  }

  /// Loads [widget.day] itself when the shared controller is holding another
  /// day — the diet day's day-nav browses the past, and the shortcut always
  /// records against today. Nothing else would trigger that reload
  /// ([TodayController.load]'s only callers are the health shell's mount and
  /// the diet day's own day switch), so waiting for one would spin forever.
  void _ensureDayLoaded() {
    if (_requestedLoad) return;
    final controller = widget.todayController;
    final held = controller.dayMealsLog?.day;
    // Someone else's load is already in flight (the health shell pre-loads on
    // mount); this listener runs again when it lands. Return BEFORE capturing:
    // `dayMealsLog` is still the day being replaced, and recording it would
    // hand back a day the user has already navigated away from.
    if (controller.status == TodayStatus.loading) return;
    // Captured before the error guard, though: the diet day can reach
    // `error`/`needsReauth` with `dayMealsLog` INTACT (a failed mutation goes
    // through `TodayController._mutate`, which sets the status and leaves the
    // record alone). Bailing out first would lose the day this screen has to
    // hand back, and `dispose` would restore today over a diet day still
    // pointing at the past one.
    // `??=`: only the FIRST pass borrowed a day from the user — the midnight
    // rollover would otherwise overwrite it with yesterday's "today".
    if (held != null && held != widget.day) _returnDay ??= held;
    if (controller.status == TodayStatus.error ||
        controller.status == TodayStatus.needsReauth) {
      return;
    }
    if (held == widget.day) return;
    _requestedLoad = true;
    controller.load(widget.idToken, widget.day);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.todayController;

    // Every pre-dictionary state carries the SAME AppBar the dictionary itself
    // has, so the back arrow is there whatever happens — matching what
    // VitalsScreen and DietDayScreen already do. Without it a cold start whose
    // meals request fails strands the user on a screen whose only action is
    // signing out.
    Widget shell(Widget body) => Scaffold(
      appBar: AppBar(title: Text(loc.dietDictionaryTitle)),
      body: body,
    );

    switch (controller.status) {
      // Both exits mirror TodayScreen's: without them a failed load would
      // leave this screen spinning forever.
      case TodayStatus.needsReauth:
        return shell(
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('dictionary-sign-in-again-button'),
                    onPressed: widget.signOut.call,
                    child: Text(loc.signInAgain),
                  ),
                ],
              ),
            ),
          ),
        );
      case TodayStatus.error:
        return shell(
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.errorDietLoadFailed,
                    key: const Key('dictionary-error-message'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('dictionary-retry-button'),
                    onPressed: () {
                      // Loads directly rather than via `_ensureDayLoaded`,
                      // which refuses while the status is `error` — the very
                      // state this button exists to leave. Capture the day to
                      // hand back first (`??=`: an earlier takeover wins).
                      if (controller.dayMealsLog?.day != widget.day) {
                        _returnDay ??= controller.dayMealsLog?.day;
                      }
                      _requestedLoad = true;
                      controller.load(widget.idToken, widget.day);
                    },
                    child: Text(loc.retry),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('dictionary-sign-out-button'),
                    onPressed: widget.signOut.call,
                    child: Text(loc.signOut),
                  ),
                ],
              ),
            ),
          ),
        );
      case TodayStatus.loading:
      case TodayStatus.loaded:
        final log = controller.dayMealsLog;
        if (log == null || log.day != widget.day) {
          return shell(const Center(child: CircularProgressIndicator()));
        }
        return ListenableBuilder(
          listenable: widget.homeController,
          builder: (context, _) => FoodSearchScreen(
            meal: null,
            mealNames: log.meals.map((m) => m.meal).toList(),
            dictionaryController: widget.dictionaryController,
            createMealController: widget.createMealController,
            idToken: widget.idToken,
            day: widget.day,
            signOut: widget.signOut,
            isAdmin: widget.homeController.profile?.isAdmin ?? false,
            sharedFoodItemController: widget.sharedFoodItemController,
            onNeedProfile: () => widget.homeController.ensureLoaded(widget.idToken),
          ),
        );
    }
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
