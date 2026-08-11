import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'contexts/auth/application/sign_out.dart';
import 'contexts/auth/application/send_password_reset.dart';
import 'contexts/auth/application/sign_up.dart';
import 'contexts/auth/domain/auth_repository.dart';
import 'contexts/assistant/presentation/assistant_chat_context.dart';
import 'contexts/assistant/presentation/assistant_controller.dart';
import 'contexts/assistant/presentation/assistant_screen.dart';
import 'contexts/assistant/presentation/assistant_sheet_page.dart';
import 'contexts/auth/presentation/login_controller.dart';
import 'contexts/auth/presentation/login_screen.dart';
import 'contexts/auth/presentation/password_reset_screen.dart';
import 'contexts/auth/presentation/register_screen.dart';
import 'contexts/body_profile/presentation/weight_goal_controller.dart';
import 'contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'contexts/bowel/presentation/bowel_controller.dart';
import 'contexts/bowel/presentation/bowel_screen.dart';
import 'contexts/exercise/presentation/exercise_controller.dart';
import 'contexts/exercise/presentation/exercise_screen.dart';
import 'contexts/finance/application/list_finance_categories.dart';
import 'contexts/finance/domain/finance_repository.dart';
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
import 'contexts/split/application/activity_use_cases.dart';
import 'contexts/split/application/balance_use_cases.dart';
import 'contexts/split/application/expense_use_cases.dart';
import 'contexts/split/application/group_use_cases.dart';
import 'contexts/split/application/settlement_use_cases.dart';
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
import 'contexts/user/presentation/home_dashboard_controller.dart';
import 'contexts/user/presentation/home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/assistant/gemini_key_controller.dart';
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
import 'shared/auth/id_token_provider.dart';

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
    return AuthRedirect(
      isAuthGateLocation(loc) ? null : loginLocation,
      pendingDeepLink,
    );
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

  /// Only for the instalment-plan screens (see `FinanceScaffold`): a plan is
  /// not month-shaped, so it does not go through `financeController`.
  final FinanceRepository financeRepository;
  final LoginController loginController;
  final HomeController homeController;
  final HomeDashboardController? homeDashboardController;
  final LocaleController localeController;
  final ThemeController themeController;
  final GeminiKeyController geminiKeyController;
  final AssistantController assistantController;
  final SignOut signOut;
  final SignUp signUp;
  final SendPasswordReset sendPasswordReset;
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

  /// The recorder's own finance categories, for the split expense form's
  /// category picker. Lives here because `/finance/groups/:id` builds
  /// [GroupDetailScreen] outside `FinanceScaffold` — that screen has no
  /// `FinanceController` to read the already-loaded list off, and an
  /// unwired picker there silently clears every participant's category on
  /// the next edit.
  final ListFinanceCategories listFinanceCategories;

  /// Settlement (repayment) use cases (design.md task 5/5b/6) — shared by
  /// the split tab (`SplitTabDependencies`) and a group's own person-to-
  /// person section (`GroupDetailScreen`), since both settle a two-person
  /// balance the same way (design D0).
  final ListSettlements splitListSettlements;
  final CreateSettlement splitCreateSettlement;
  final DeleteSettlement splitDeleteSettlement;
  final ListActivity splitListActivity;

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
    required this.financeRepository,
    required this.loginController,
    required this.homeController,
    this.homeDashboardController,
    required this.localeController,
    required this.themeController,
    required this.geminiKeyController,
    required this.assistantController,
    required this.signOut,
    required this.signUp,
    required this.sendPasswordReset,
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
    required this.listFinanceCategories,
    required this.splitListSettlements,
    required this.splitCreateSettlement,
    required this.splitDeleteSettlement,
    required this.splitListActivity,
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
        // is fetched fresh here, the same rule every authenticated request in
        // the app now follows (`IdTokenProvider`): a token resolved any
        // earlier can be past its one-hour life by the time this runs, and the
        // overnight tap this reload exists for is exactly that case.
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
      widget.homeDashboardController?.reset();
      widget.netWorthController.reset();
      // `FinanceScaffold` reloads this one on entry, but a reload is not a
      // clear: re-entering finance in the same calendar month keeps the
      // previous account's split-spending figures on the controller until
      // the new account's own fetch lands, and the overview paints them in
      // the meantime.
      widget.financeController.reset();
      // Same reasoning for the record calendar's browsed month: nothing else
      // clears it, so the next user would open it on the previous user's
      // month (and its data) instead of their own current month.
      widget.healthCalendarController.reset();
      // The assistant transcript is the previous user's finances in prose,
      // and its proposal cards are pre-filled writes into *their* ledger —
      // nothing else ever clears it (the conversation deliberately survives
      // navigation), so sign-out must.
      widget.assistantController.reset();
      // The BYOK Gemini key is the previous user's own billable credential,
      // persisted device-locally with nothing else that ever removes it — so
      // without this the next account signed in on this device sends its
      // prompts (and its data) on the previous user's key and quota.
      // Fire-and-forget because this listener is synchronous; the clear only
      // has to land before a signed-in screen can reach the assistant again,
      // and sign-out has just put the login screen in front of the user.
      unawaited(widget.geminiKeyController.clear());
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

  /// The [IdTokenProvider] handed to every authenticated route builder. It
  /// asks the auth repository on **every** call rather than closing over a
  /// value: `idToken()` renews a token that is close to expiring, so a screen
  /// that has been mounted for hours still sends a live one. Signed out
  /// resolves to `''`, the pre-existing semantics (the request 401s and the
  /// re-auth exit takes over).
  ///
  /// The `catch` is load-bearing and is the same guard `AuthRouterNotifier`
  /// used to carry before the token moved to the call sites: a renewal that
  /// has to go to the network **throws** when it fails, and the throw would
  /// escape here — before the controller is ever entered, so no controller's
  /// error handling would run and the user's tap would vanish with neither a
  /// write nor a message. Resolving to `''` instead reproduces the pre-change
  /// outcome: the request goes out unauthenticated, the backend 401s, and the
  /// re-auth exit takes over. This is exactly the case this whole change is
  /// about (a PWA open past the token's hour) combined with a flaky network,
  /// so it is not hypothetical.
  Future<String> _idToken() => guardedIdToken(widget.authRepository);
  String get _today => dayString(widget.clock());

  /// Builds a day-keyed tracker screen for the `/health/<name>` route. Nested
  /// under `/health` so the URL hierarchy — which is what a web browser back /
  /// refresh reconstructs the page stack from — implies [HealthScaffold] below
  /// it. An unknown name resets to the record hub.
  ///
  /// [query] is the URL's query parameters — a modifier on the same screen
  /// rather than a route of its own, which is how the vitals launcher
  /// shortcuts say which reading to start (`/health/vitals?add=glucose`).
  ///
  /// Every tracker is wrapped in a [_TrackerLoadGate]. None of these screens
  /// loads its own day: [HealthScaffold.initState] does it for all of them at
  /// once, which is fine when the shell is what put them on screen — but a
  /// home-grid tile (`push('/health/vitals')`) mounts the tracker with NO
  /// shell in the stack, and its controller sits in its initial `loading`
  /// state with nobody left to leave it: a permanent spinner. The gate is the
  /// missing loader. The `default` branch is not wrapped — there is no
  /// controller behind an unknown name.
  Widget _trackerFor(String? name, Map<String, String> query) {
    final day = _today;
    switch (name) {
      case 'water':
        final controller = widget.waterController;
        return _TrackerLoadGate(
          hasWantedDay: () => controller.day?.day == day,
          load: () async => controller.load(await _idToken(), day),
          child: WaterScreen(
            controller: controller,
            idToken: _idToken,
            day: day,
            clock: widget.clock,
            onSignInAgain: widget.signOut.call,
          ),
        );
      case 'vitals':
        final controller = widget.vitalsController;
        return _TrackerLoadGate(
          hasWantedDay: () => controller.day?.day == day,
          load: () async => controller.load(await _idToken(), day),
          child: VitalsScreen(
            controller: controller,
            idToken: _idToken,
            day: day,
            clock: widget.clock,
            autoAddSection: query['add'],
            onSignInAgain: widget.signOut.call,
          ),
        );
      case 'bowel':
        final controller = widget.bowelController;
        return _TrackerLoadGate(
          hasWantedDay: () => controller.day?.day == day,
          load: () async => controller.load(await _idToken(), day),
          child: BowelScreen(
            controller: controller,
            idToken: _idToken,
            day: day,
            clock: widget.clock,
            onSignInAgain: widget.signOut.call,
          ),
        );
      case 'exercise':
        final controller = widget.exerciseController;
        return _TrackerLoadGate(
          hasWantedDay: () => controller.day?.day == day,
          load: () async => controller.load(await _idToken(), day),
          child: ExerciseScreen(
            controller: controller,
            idToken: _idToken,
            day: day,
            clock: widget.clock,
            onSignInAgain: widget.signOut.call,
          ),
        );
      case 'menstrual':
        final controller = widget.menstrualController;
        return _TrackerLoadGate(
          // The menstrual overview is not day-keyed, so "already has it" is
          // simply "has an overview".
          hasWantedDay: () => controller.overview != null,
          load: () async => controller.load(await _idToken()),
          child: MenstrualScreen(
            controller: controller,
            idToken: _idToken,
            clock: widget.clock,
            onSignInAgain: widget.signOut.call,
          ),
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
          builder: (context, state) =>
              _AuthErrorScreen(onRetry: _authNotifier.retry),
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
          path: passwordResetLocation,
          builder: (context, state) => PasswordResetScreen(
            sendPasswordReset: widget.sendPasswordReset,
            localeController: widget.localeController,
            // `extra` is whatever the sign-in screen had typed; a direct
            // visit (a bookmark, a shared link) has none and starts empty.
            initialEmail: state.extra is String ? state.extra as String : '',
          ),
        ),
        GoRoute(
          path: registerLocation,
          builder: (context, state) => RegisterScreen(
            signUp: widget.signUp,
            localeController: widget.localeController,
          ),
        ),
        // Every signed-in destination is a CHILD of home, so the stack a
        // browser (or a launcher shortcut, or a push deep link) rebuilds from
        // a URL always has home underneath it — the back button walks into the
        // app instead of out of it. Nesting changes only what is built below a
        // location, never the location itself: the URLs are unchanged and
        // pinned by `app_route_shapes_test.dart`. In-app `context.push('/x')`
        // calls are unaffected — an absolute path still matches, and an
        // imperative push still adds exactly one page.
        GoRoute(
          path: '/',
          builder: (context, state) => _AuthenticatedHome(
            authRepository: widget.authRepository,
            homeController: widget.homeController,
            dashboardController: widget.homeDashboardController,
            clock: widget.clock,
          ),
          routes: [
            // Nested under home rather than under a shell: the assistant is
            // entered from the home grid today and from other shells later, so it
            // belongs to none of them. Built purely from injected DI, so
            // a web refresh reconstructs it — the conversation itself lives on
            // the app-lifetime controller.
            // `ctx`/`tab`/`month` in the query carry what the user was looking
            // at when they entered (the finance shell's entry point) — on the
            // URL, not in `extra`, so a web refresh reconstructs the context
            // too. Garbage parameters are dropped by `fromQuery`, never echoed.
            // `key: ValueKey(query)`: go_router's `pageKey` tracks only the path
            // pattern (the `/invite` lesson), so without it entering again with
            // a different context would reuse the old `State` — and its
            // already-consumed context-prefix flag.
            // `pageBuilder` (not `builder`): the route is non-opaque so the
            // screen it was opened from stays visible and interactive behind an
            // `AssistantSheetPage` panel — see that widget's doc for why this
            // keeps the URL/back-button/refresh behaviour a real route gives
            // instead of a `showModalBottomSheet`. `barrierColor` is set
            // explicitly: `CustomTransitionPage` leaves it `null` by default,
            // which is a fully transparent (but still dismissible) barrier — the
            // panel would look like it has nothing behind it to dismiss.
            GoRoute(
              path: 'assistant',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                opaque: false,
                barrierDismissible: true,
                barrierColor: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.32),
                barrierLabel: MaterialLocalizations.of(
                  context,
                ).modalBarrierDismissLabel,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      );
                    },
                child: AssistantSheetPage(
                  child: AssistantScreen(
                    key: ValueKey(state.uri.query),
                    controller: widget.assistantController,
                    geminiKeyController: widget.geminiKeyController,
                    idToken: _idToken,
                    onSignInAgain: widget.signOut.call,
                    chatContext: AssistantChatContext.fromQuery(
                      state.uri.queryParameters,
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: 'settings',
              builder: (context, state) => SettingsScreen(
                themeController: widget.themeController,
                localeController: widget.localeController,
                geminiKeyController: widget.geminiKeyController,
                signOut: widget.signOut,
                pwaInstall: const PwaInstallImpl(),
                homeController: widget.homeController,
                idToken: _idToken,
              ),
            ),
            // No `extra`: built purely from injected DI, so a web refresh on this
            // URL reconstructs the screen. `FriendsController` is built by the
            // screen's own `State` (design D9), not here.
            GoRoute(
              path: 'friends',
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
              path: 'invite',
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
              path: 'import/chaodays',
              builder: (context, state) => ChaodaysImportScreen(
                controller: widget.chaodaysImportController,
                authRepository: widget.authRepository,
              ),
            ),
            GoRoute(
              path: 'reminders',
              builder: (context, state) => ReminderSettingsScreen(
                controller: widget.reminderSettingsController,
                authRepository: widget.authRepository,
              ),
            ),
            GoRoute(
              path: 'care-items',
              builder: (context, state) => CareItemsScreen(
                controller: widget.careItemsController,
                authRepository: widget.authRepository,
                pushHealthController: widget.pushHealthController,
              ),
            ),
            GoRoute(
              path: 'care-today',
              builder: (context, state) => CareTodayScreen(
                controller: widget.careTodayController,
                authRepository: widget.authRepository,
                onOpenCareItems: () => context.push('/care-items'),
                pushHealthController: widget.pushHealthController,
              ),
            ),
            GoRoute(
              path: 'care-history',
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
              path: 'finance',
              builder: (context, state) => FinanceScaffold(
                authRepository: widget.authRepository,
                controller: widget.financeController,
                netWorthController: widget.netWorthController,
                financeRepository: widget.financeRepository,
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
                  listSettlements: widget.splitListSettlements,
                  createSettlement: widget.splitCreateSettlement,
                  deleteSettlement: widget.splitDeleteSettlement,
                  listActivity: widget.splitListActivity,
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
                      listFinanceCategories: widget.listFinanceCategories,
                      getBalances: widget.splitGetBalances,
                      createSettlement: widget.splitCreateSettlement,
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
              path: 'health',
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
                        if (day is! String) {
                          return const _Redirect(to: '/health/diet');
                        }
                        return DailyTargetScreen(
                          controller: widget.healthDailyTargetController,
                          idToken: _idToken,
                          day: day,
                          onSaved: () async => widget.healthTodayController
                              .load(await _idToken(), day),
                          onSignInAgain: widget.signOut.call,
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
                            dictionaryController:
                                widget.healthDictionaryController,
                            createMealController:
                                widget.healthCreateMealController,
                            idToken: _idToken,
                            day: args.day,
                            signOut: widget.signOut,
                            isAdmin:
                                widget.homeController.profile?.isAdmin ?? false,
                            sharedFoodItemController:
                                widget.healthSharedFoodItemController,
                            onNeedProfile: () async => widget.homeController
                                .ensureLoaded(await _idToken()),
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
                              dictionaryController:
                                  widget.healthDictionaryController,
                              createMealController:
                                  widget.healthCreateMealController,
                              idToken: _idToken,
                              day: args.day,
                              signOut: widget.signOut,
                              isAdmin:
                                  widget.homeController.profile?.isAdmin ??
                                  false,
                              sharedFoodItemController:
                                  widget.healthSharedFoodItemController,
                              onNeedProfile: () async => widget.homeController
                                  .ensureLoaded(await _idToken()),
                            ),
                          );
                        }
                        return _UrlDictionaryScreen(
                          todayController: widget.healthTodayController,
                          dictionaryController:
                              widget.healthDictionaryController,
                          createMealController:
                              widget.healthCreateMealController,
                          sharedFoodItemController:
                              widget.healthSharedFoodItemController,
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
///
/// Deliberately NOT `go`: that discards the whole page stack and rebuilds it
/// from [to], so a user who pushed their way here from home would be left with
/// nothing behind [to] and a back button that leaves the app — the very thing
/// nesting the routes under `/` exists to prevent. The two shapes this can be
/// reached in need opposite repairs:
///
///  * the page below is ALREADY [to] (the ordinary in-app case: `/health` is
///    below `/health/<unknown>` because the stack was rebuilt from the URL) —
///    just `pop`, which leaves exactly one [to] on screen;
///  * anything else — `pushReplacement`, which swaps this page for [to] and
///    leaves everything below it untouched.
///
/// A blanket `pushReplacement` would get the first case wrong: a URL-driven
/// `/health/<unknown>` would end as `[/, /health, /health]` — two health
/// shells stacked, each running its own screenful of loads.
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
      if (!mounted) return;
      final router = GoRouter.of(context);
      final matches = router.routerDelegate.currentConfiguration.matches;
      final below = matches.length >= 2
          ? matches[matches.length - 2].matchedLocation
          : null;
      if (below == widget.to && router.canPop()) {
        router.pop();
      } else {
        router.pushReplacement(widget.to);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Whether `HealthScaffold` is in the current page stack.
///
/// It loads the whole health module on mount — every tracker's day, the diet
/// day's meals, the food favourites — so any screen that would otherwise fetch
/// one of those itself must stand down when the shell is below it, or the two
/// answers race and the loser's state is overwritten.
///
/// Read from the route match list rather than from a controller flag because
/// it is exact and, unlike "is a load in flight?", already true at the moment
/// these screens mount (the shell has to await an ID token before its own load
/// starts). A URL-driven `/health/water` matches `[/, /health, /health/water]`;
/// the same location reached by an imperative push from home matches
/// `[/, /health/water]` — no shell, nobody else loading.
bool _healthShellInStack(BuildContext context) => GoRouter.of(context)
    .routerDelegate
    .currentConfiguration
    .matches
    .any((match) => match.matchedLocation == '/health');

/// Makes sure the tracker below it actually has the day it is about to show,
/// loading it if nobody else will.
///
/// One generic gate for all five trackers rather than five copies: the traps
/// below are the same for each, and traps duplicated five times are five
/// places to get one of them wrong.
///
/// * **It loads only when the health shell is NOT in this page stack.** That
///   is the whole distinction. `HealthScaffold.initState` loads all five
///   trackers, so whenever it is below this route (a URL-driven entry, or a
///   push from inside the shell) there is nothing for this gate to do — and
///   doing it anyway is not merely a wasted request: the second answer to
///   land overwrites the screen's state, which on `/health/vitals?add=glucose`
///   wipes out the empty reading the shortcut just opened. The signal is the
///   route match list, checked in [_healthShellInStack]; it is exact, and
///   crucially it is available SYNCHRONOUSLY. An "is a load in flight?" flag
///   on the controllers cannot do this job: measured, this gate's whole
///   decision runs before `HealthScaffold.initState` is even called, so at
///   decision time nothing is in flight yet.
/// * **Post-frame, never in `build`.** `load` notifies SYNCHRONOUSLY, and
///   this widget is mounted in the middle of a router stack rebuild — a
///   notification there marks widgets below dirty mid-build and throws.
/// * **Nothing to do when the day is already held.** Re-entering a tracker
///   from home must not put a spinner over data the user can already see.
/// * **Exactly one decision, taken once.** No re-entrancy flag is needed for
///   that: measured, a route's `builder` runs ONCE per page and is not re-run
///   when `App` rebuilds, so this gate is mounted once and never updated in
///   place. That is also why there is no midnight-rollover reset — the day it
///   was built with cannot change underneath it. (The day the child shows is
///   frozen the same way: a pre-existing property of these routes, not
///   something this gate introduces.)
///
/// No listener: this is a loader, not a view. It decides once, on mount; the
/// screen below it listens to the controller itself and repaints on its own.
class _TrackerLoadGate extends StatefulWidget {
  /// Whether the controller already holds what the child needs.
  final bool Function() hasWantedDay;

  final Future<void> Function() load;
  final Widget child;

  const _TrackerLoadGate({
    required this.hasWantedDay,
    required this.load,
    required this.child,
  });

  @override
  State<_TrackerLoadGate> createState() => _TrackerLoadGateState();
}

class _TrackerLoadGateState extends State<_TrackerLoadGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    if (!mounted) return;
    if (_healthShellInStack(context)) return;
    if (widget.hasWantedDay()) return;
    widget.load();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  final IdTokenProvider idToken;
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
      _ensureFavoritesLoaded();
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
    // The provider itself, not a token: `dispose` cannot await. Resolving it
    // inside the post-frame callback below is both possible (that callback
    // can be async) and correct — the token then comes from the moment the
    // reload actually goes out.
    final idToken = widget.idToken;
    // The borrowed day if this screen took the controller over, today
    // otherwise. `_ensureDayLoaded` captures `_returnDay` before it can fail,
    // so a takeover whose load then failed still hands the day back.
    final day = _returnDay ?? widget.day;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async => controller.load(await idToken(), day),
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

  /// Fetches the favourite foods when nobody else is going to. The health
  /// shell loads them on mount, which is why this screen never had to — but it
  /// is now reachable straight from the home grid (the 食物份量工具 tile), with
  /// no shell in the stack, and the favourites list would otherwise sit on its
  /// initial spinner forever.
  ///
  /// Guarded by [_healthShellInStack] for the same reason the tracker gate is:
  /// when the shell is below, it is already fetching these and a second fetch
  /// would race it. The remaining condition is "still in its initial state" —
  /// `loaded` needs nothing, and `error`/`needsReauth` belong to the screen's
  /// own retry.
  void _ensureFavoritesLoaded() {
    if (_healthShellInStack(context)) return;
    final dictionary = widget.dictionaryController;
    if (dictionary.status != DictionaryStatus.loading) return;
    dictionary.load();
  }

  /// Loads [widget.day] itself when the shared controller is holding another
  /// day — the diet day's day-nav browses the past, and the shortcut always
  /// records against today. Nothing else would trigger that reload
  /// ([TodayController.load]'s only callers are the health shell's mount and
  /// the diet day's own day switch), so waiting for one would spin forever.
  Future<void> _ensureDayLoaded() async {
    if (_requestedLoad) return;
    final controller = widget.todayController;
    final held = controller.dayMealsLog?.day;
    // Someone else's load is already in flight (the health shell pre-loads on
    // mount); this listener runs again when it lands. Return BEFORE capturing:
    // `dayMealsLog` is still the day being replaced, and recording it would
    // hand back a day the user has already navigated away from.
    //
    // `loadingDay`, NOT `status == TodayStatus.loading`: `loading` is also
    // this controller's INITIAL value, so the status read could not tell "the
    // shell is fetching" from "nobody has fetched at all". That was harmless
    // while the shell was always below this screen, and stopped being harmless
    // when the home grid's 食物份量工具 tile started pushing straight here —
    // with no shell in the stack, this screen waited forever for a load nobody
    // had started.
    //
    // `loadingDay` alone is NOT enough, though, and cannot be: on a
    // URL-driven entry this screen and `HealthScaffold` are mounted in the
    // SAME frame, and the shell only sets `loadingDay` after `await
    // idToken()` — so at the moment this post-frame callback runs, the shell's
    // load is decided upon but not yet in flight and the flag still reads
    // `null`. Measured: without the second clause below, a launcher shortcut
    // to `/health/diet/dictionary` fired a THIRD `GET /api/meals` for the day
    // the shell was already about to fetch.
    //
    // Hence [_healthShellInStack] as well — but only while NOTHING has been
    // loaded yet. The shell being in the stack does not by itself mean it is
    // about to load today: it may have been mounted long ago, with the diet
    // day browsing a past day since, which is precisely the takeover this
    // method exists for. "Shell below AND the controller is still empty" is
    // the one shape that means "its mount-time load is coming".
    if (controller.loadingDay != null) return;
    if (held == null && _healthShellInStack(context)) return;
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
    controller.load(await widget.idToken(), widget.day);
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
                    onPressed: () async {
                      // Loads directly rather than via `_ensureDayLoaded`,
                      // which refuses while the status is `error` — the very
                      // state this button exists to leave. Capture the day to
                      // hand back first (`??=`: an earlier takeover wins).
                      if (controller.dayMealsLog?.day != widget.day) {
                        _returnDay ??= controller.dayMealsLog?.day;
                      }
                      _requestedLoad = true;
                      controller.load(await widget.idToken(), widget.day);
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
            onNeedProfile: () async =>
                widget.homeController.ensureLoaded(await widget.idToken()),
          ),
        );
    }
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final AuthRepository authRepository;
  final HomeController homeController;
  final HomeDashboardController? dashboardController;
  final DateTime Function() clock;

  const _AuthenticatedHome({
    required this.authRepository,
    required this.homeController,
    this.dashboardController,
    required this.clock,
  });

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  GoRouterDelegate? _routerDelegate;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // In `didChangeDependencies`, not `initState`: reading the router is an
    // inherited-widget lookup.
    final delegate = GoRouter.of(context).routerDelegate;
    if (identical(delegate, _routerDelegate)) return;
    _routerDelegate?.removeListener(_onRouteChanged);
    _routerDelegate = delegate..addListener(_onRouteChanged);
    // Post-frame for the first check too: a URL-driven cold start builds home
    // and the pages above it in the SAME frame, and mid-frame the top of the
    // stack is not settled yet — checking here would read `/` and fire the
    // very fan-out this defers.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRouteChanged());
  }

  /// `/api/me` — one request, and everything downstream of it (`isAdmin`, the
  /// greeting, sign-out) is needed whether or not home is the visible page,
  /// including by screens deep-linked to directly. Loaded unconditionally.
  Future<void> _loadProfile() async {
    final token = await widget.authRepository.idToken();
    await widget.homeController.load(token ?? '');
  }

  /// The dashboard, in contrast, is a SIX-request fan-out (weight goal,
  /// vitals trends, menstrual, budgets, net worth, split balances) that paints
  /// nothing except on home itself. On a launcher-shortcut or push-deep-link
  /// cold start, home is built but never seen — and those six requests were
  /// competing for the connection with the one screen the user actually asked
  /// for. Deferred until home is the current page.
  void _onRouteChanged() {
    if (!mounted) return;
    final dashboard = widget.dashboardController;
    if (dashboard == null) return;
    // `status`, not a one-shot field of this widget's own: sign-out resets the
    // controller back to `idle`, so the next user's home loads their figures
    // instead of inheriting the previous user's.
    if (dashboard.status != HomeDashboardStatus.idle) return;
    // `matches.last`, not `currentConfiguration.uri`: an imperative `push`
    // deliberately leaves the URI alone, so the URI still reads `/` while the
    // user is looking at a pushed screen.
    final matches = _routerDelegate!.currentConfiguration.matches;
    if (matches.isEmpty || matches.last.matchedLocation != '/') return;
    unawaited(_loadDashboard(dashboard));
  }

  Future<void> _loadDashboard(HomeDashboardController dashboard) async {
    final token = await widget.authRepository.idToken();
    await dashboard.load(token ?? '', widget.clock());
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      controller: widget.homeController,
      dashboardController: widget.dashboardController,
      clock: widget.clock,
      idToken: () async => await widget.authRepository.idToken() ?? '',
    );
  }
}
