import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_screen.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_screen.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_screen.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/health/presentation/diet_day_screen.dart';
import 'package:life_os/contexts/health/presentation/food_search_screen.dart';
import 'package:life_os/contexts/health/presentation/health_scaffold.dart';
import 'package:life_os/contexts/hydration/presentation/water_screen.dart';
import 'package:life_os/contexts/import/presentation/chaodays_import_screen.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_screen.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_screen.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_screen.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_screen.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_screen.dart';
import 'package:life_os/contexts/settings/presentation/settings_screen.dart';
import 'package:life_os/contexts/social/presentation/friends_screen.dart';
import 'package:life_os/contexts/social/presentation/invite_screen.dart';
import 'package:life_os/contexts/split/presentation/group_detail_screen.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_screen.dart';
import 'package:life_os/shared/routing/finance_tab.dart';

import 'app_test.dart';

/// The URL surface of the signed-in app, pinned as a table.
///
/// Every entry is a location a *browser* or a *launcher shortcut* can produce
/// — bookmarks, PWA shortcuts, push deep links, a mid-session refresh. Making
/// the route tree nested (so the back button can walk down to home) must not
/// move a single one of these strings: nesting changes what is built *below*
/// a location, never the location itself. Each row therefore asserts both
/// halves — the screen is reachable, and the URL is byte-identical to what was
/// asked for.
///
/// The URL assertion is what makes this file a guard rather than a smoke test:
/// a route that silently bounces (an unmatched path falling through to the
/// `_Redirect` that resets to `/health`) still paints *a* screen, but under a
/// different URL.
void main() {
  Future<GoRouter> pumpSignedIn(WidgetTester tester) async {
    final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
    final profileRepository = FakeProfileRepository(
      UserProfile(
        id: 'user-1',
        firebaseUid: 'firebase-abc',
        email: 'user@example.com',
        displayName: 'Test User',
        createdAt: '2026-01-01T00:00:00.000Z',
        isAdmin: false,
      ),
    );
    await pumpApp(
      tester,
      authRepository: authRepository,
      loginController: LoginController(SignIn(authRepository)),
      homeController: HomeController(
        GetProfile(profileRepository),
        SignOut(authRepository),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(
      tester.element(find.byKey(const Key('health-tile'))),
    );
  }

  String currentLocation(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('signed-in URL surface', () {
    final cases = <String, Type>{
      '/health': HealthScaffold,
      '/health/diet': DietDayScreen,
      '/health/diet/dictionary': FoodSearchScreen,
      '/health/vitals?add=glucose': VitalsScreen,
      '/health/water': WaterScreen,
      '/health/bowel': BowelScreen,
      '/health/exercise': ExerciseScreen,
      '/health/menstrual': MenstrualScreen,
      '/finance': FinanceScaffold,
      // A query-carrying deep link still matches the nested route under `/`,
      // and is not rewritten — including the unknown value, which falls back
      // to 總覽 *without* touching the URL (a rewrite would edit the address
      // a user hand-typed or bookmarked).
      '/finance?tab=networth': FinanceScaffold,
      '/finance?tab=split': FinanceScaffold,
      '/finance?tab=bogus': FinanceScaffold,
      '/finance/groups/g1': GroupDetailScreen,
      '/settings': SettingsScreen,
      '/friends': FriendsScreen,
      '/invite?token=t': InviteScreen,
      '/import/chaodays': ChaodaysImportScreen,
      '/reminders': ReminderSettingsScreen,
      '/care-items': CareItemsScreen,
      '/care-today': CareTodayScreen,
      '/care-history': CareHistoryScreen,
      '/assistant': AssistantScreen,
    };

    cases.forEach((location, screen) {
      testWidgets('$location builds ${screen.toString()} at that exact URL', (
        tester,
      ) async {
        final router = await pumpSignedIn(tester);

        // `go`, not `push`: this is the browser/launcher shape — the whole
        // match stack is rebuilt from the URL alone.
        router.go(location);
        await tester.pumpAndSettle();

        expect(
          find.byType(screen, skipOffstage: false),
          findsOneWidget,
          reason: '$location should build $screen',
        );
        expect(
          currentLocation(router),
          location,
          reason: '$location must not be rewritten by a redirect',
        );
      });
    });
  });

  group('the real /finance route builder applies ?tab=', () {
    // The URL-surface table above only proves the *screen* is reached.
    // `app.dart`'s builder is what turns `?tab=` into the selected
    // destination, and nothing else in the suite exercises that wiring: the
    // scaffold's own tests parse the query in their harness.
    for (final entry in {
      '/finance': FinanceTab.overview,
      '/finance?tab=networth': FinanceTab.networth,
      '/finance?tab=split': FinanceTab.split,
      '/finance?tab=bogus': FinanceTab.overview,
    }.entries) {
      testWidgets('${entry.key} selects ${entry.value.slug}', (tester) async {
        final router = await pumpSignedIn(tester);

        router.go(entry.key);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          entry.value.index,
        );
      });
    }
  });

  group('web/manifest.json launcher shortcuts', () {
    testWidgets('every shortcut URL resolves to its own screen', (
      tester,
    ) async {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final shortcuts = (manifest['shortcuts'] as List).cast<Map>();
      expect(
        shortcuts,
        isNotEmpty,
        reason: 'the manifest is supposed to ship launcher shortcuts',
      );

      final router = await pumpSignedIn(tester);
      for (final shortcut in shortcuts) {
        final raw = shortcut['url'] as String;
        // The manifest ships hash-strategy URLs (`/#/health/vitals?add=bp`);
        // the router sees what follows the `#`.
        final location = raw.startsWith('/#') ? raw.substring(2) : raw;

        router.go('/');
        await tester.pumpAndSettle();
        router.go(location);
        await tester.pumpAndSettle();

        expect(
          currentLocation(router),
          location,
          reason:
              'manifest shortcut "${shortcut['name']}" ($raw) does not resolve '
              'to a route of its own — it was rewritten to '
              '"${currentLocation(router)}"',
        );
        expect(
          find.byType(CircularProgressIndicator, skipOffstage: false),
          findsNothing,
          reason:
              'manifest shortcut "${shortcut['name']}" ($raw) settled on a '
              'spinner instead of a usable screen',
        );
      }
    });
  });
}
