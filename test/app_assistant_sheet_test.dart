import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_test.dart';

/// Guards `app.dart`'s `/assistant` route being non-opaque
/// (`CustomTransitionPage(opaque: false, ...)`, framed by
/// `AssistantSheetPage`) — the panel presentation this change introduces,
/// and the four things that presentation must not break: the screen behind
/// the panel stays visible, the gap above it dismisses on tap, a URL-driven
/// entry gets the same panel over home that an in-app entry does, and the
/// keyboard never covers the composer.
final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
  isAdmin: false,
);

Future<void> _pumpHomeAndOpenAssistant(
  WidgetTester tester, {
  GeminiKeyController? geminiKeyController,
}) async {
  final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
  final profileRepository = FakeProfileRepository(_testProfile);
  await pumpApp(
    tester,
    authRepository: authRepository,
    loginController: LoginController(SignIn(authRepository)),
    homeController: HomeController(
      GetProfile(profileRepository),
      SignOut(authRepository),
    ),
    geminiKeyController: geminiKeyController,
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('home-assistant-bar')));
  await tester.pumpAndSettle();
}

Future<GeminiKeyController> _keyedGeminiKeyController() async {
  SharedPreferences.setMockInitialValues({});
  final controller = GeminiKeyController(await SharedPreferences.getInstance());
  await controller.setKey('test-key');
  return controller;
}

void main() {
  group('Assistant sheet panel', () {
    testWidgets(
      'opening the panel from home leaves primary navigation visible underneath',
      (tester) async {
        await _pumpHomeAndOpenAssistant(tester);

        // The panel itself is on screen (no key stored → setup state)...
        expect(find.byKey(const Key('assistant-setup')), findsOneWidget);
        // ...and the route it was opened from is STILL there, not offstage.
        // `opaque: true` would stop it being built at all, and `find`
        // skips offstage widgets by default — this is what would go red.
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the gap above the panel dismisses it back to the home screen',
      (tester) async {
        await _pumpHomeAndOpenAssistant(tester);
        expect(find.byKey(const Key('assistant-setup')), findsOneWidget);

        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        // Well inside the empty gap above the panel (the panel's rounded
        // top sits well below this), which is nothing but the route's own
        // modal barrier — a tap there must dismiss like tapping a scrim.
        await tester.tapAt(Offset(width / 2, 10));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-setup')), findsNothing);
        final router = GoRouter.of(
          tester.element(find.byKey(const Key('health-dashboard-section'))),
        );
        expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
      },
    );

    testWidgets(
      'a direct /assistant entry is the same panel over home as entering '
      'from inside the app',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
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

        // `go`, not `push`/tapping the bar: this replaces the whole match
        // stack from the URL alone — the shape of a deep link or a web
        // refresh landing directly on this URL. `/assistant` is a child of
        // `/`, so that rebuilt stack is [home, assistant]: the assistant is
        // never the bottom of the stack any more, and this entry looks
        // exactly like the in-app one above.
        final router = GoRouter.of(
          tester.element(find.byKey(const Key('home-assistant-bar'))),
        );
        router.go('/assistant');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assistant-setup')), findsOneWidget);
        // Home is genuinely built below — not merely retained offstage.
        // `find` skips offstage by default, so this is the strong form.
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        // The panel's gap is drawn (it only is when there is something
        // beneath to reveal) and is a real, READABLE strip. Not
        // `greaterThan(0)`: a 1px gap satisfies that while being visually
        // indistinguishable from the old full-screen presentation, so that
        // form of the assertion cannot be killed by the thing it is guarding
        // against. `kToolbarHeight` is the floor because the gap has to read
        // as "home is showing through" rather than as a hairline — the
        // widget's own rule (`max(min(72, height * 0.12), topPadding + 16)`)
        // clears it on any surface this test runs at.
        final gap = find.byKey(const Key('assistant-sheet-gap'));
        expect(gap, findsOneWidget);
        expect(
          tester.getSize(gap).height,
          greaterThanOrEqualTo(kToolbarHeight),
          reason: 'the gap must be a visible strip, not a hairline',
        );

        // And the back button walks INTO the app, not out of it: the whole
        // point of nesting `/assistant` under `/`.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assistant-setup')), findsNothing);
        expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
      },
    );

    testWidgets('the keyboard does not cover the composer', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      addTearDown(tester.view.resetViewInsets);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await _pumpHomeAndOpenAssistant(
        tester,
        geminiKeyController: await _keyedGeminiKeyController(),
      );
      expect(find.byKey(const Key('assistant-composer-field')), findsOneWidget);

      // Simulate the on-screen keyboard opening: 300 logical px of the
      // screen's bottom are now the keyboard, reported the same way a
      // real keyboard is — as `viewInsets.bottom`.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      final composerBottom = tester
          .getRect(find.byKey(const Key('assistant-composer-field')))
          .bottom;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(composerBottom, lessThanOrEqualTo(screenHeight - 300));
    });

    testWidgets(
      'the gap above the panel widens for a notch/status-bar inset instead '
      'of being swallowed by it',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());
        addTearDown(tester.view.resetPadding);
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        // A notched-phone-sized top safe-area inset (status bar/notch).
        // Caught in review: the old `min(72, height * 0.12)` gap didn't
        // account for this at all, so on a device like this the visible
        // strip of home below the status bar would be 72 - 59 = 13px —
        // barely perceptible as "something is layered on top".
        tester.view.padding = const FakeViewPadding(top: 59);

        await _pumpHomeAndOpenAssistant(tester);

        final gapHeight = tester
            .getSize(find.byKey(const Key('assistant-sheet-gap')))
            .height;
        // 800 * 0.12 = 96, so the proportional cap (72) would otherwise
        // apply; the fix floors the gap at topPadding (59) + 16, i.e. 75,
        // so at least 16 logical px of home stay visible below the inset.
        expect(gapHeight, 75.0);
        expect(gapHeight - 59, greaterThanOrEqualTo(16));
      },
    );

    testWidgets(
      'the panel carries a back button that really returns to home — the '
      'visible way out, since there is no drag-to-dismiss',
      (tester) async {
        await _pumpHomeAndOpenAssistant(tester);

        // A `BackButton` finder, not a bare icon: the assertion is about the
        // affordance the framed Scaffold's AppBar puts on screen because the
        // route can pop — the thing a user actually looks for when the panel
        // shows no handle.
        expect(find.byType(BackButton), findsOneWidget);

        // Tapped, not merely found. A back button that is present but
        // unreachable (covered by the panel's clip, say) would still satisfy
        // `findsOneWidget`; only the return to home proves it works.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('assistant-setup')), findsNothing);
      },
    );

    testWidgets(
      'the transcript keeps a readable height when the keyboard is up on a '
      'small screen',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());
        addTearDown(tester.view.resetViewInsets);
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;

        await _pumpHomeAndOpenAssistant(
          tester,
          geminiKeyController: await _keyedGeminiKeyController(),
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        // Composer must stay reachable (guarded above), but the messages
        // above it must also stay legible — not squeezed to a sliver by the
        // panel's own gap plus AppBar plus keyboard. Measured as the space
        // between the AppBar's bottom edge and the composer's top edge,
        // since that is the whole message area regardless of whether any
        // messages have been sent yet. Floored well under the ~300px this
        // layout actually leaves, so this only trips if the panel's chrome
        // grows enough to matter.
        final composer = find.byKey(const Key('assistant-composer-field'));
        final assistantScaffold = find.ancestor(
          of: composer,
          matching: find.byType(Scaffold),
        );
        final assistantAppBar = find.descendant(
          of: assistantScaffold,
          matching: find.byType(AppBar),
        );
        final appBarBottom = tester.getRect(assistantAppBar).bottom;
        final composerTop = tester.getRect(composer).top;
        expect(composerTop - appBarBottom, greaterThanOrEqualTo(100));
      },
    );
  });
}
