import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/async_state_scaffold.dart';

import '../../support/l10n_test_app.dart';

void main() {
  group('AsyncStateScaffold', () {
    testWidgets(
      'reauth state shows the message and an enabled sign-in-again control '
      'that invokes the callback when tapped',
      (tester) async {
        var signInAgainCalled = false;
        await tester.pumpWidget(
          l10nTestApp(
            home: AsyncStateScaffold(
              isLoading: false,
              isReauth: true,
              reauthMessage: 'Please sign in again',
              onSignInAgain: () => signInAgainCalled = true,
              builder: (context) => const Text('loaded'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Please sign in again'), findsOneWidget);
        expect(
          find.byKey(const Key('async-state-reauth-sign-in-button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('async-state-reauth-sign-in-button')),
        );
        await tester.pump();

        expect(signInAgainCalled, isTrue);
      },
    );

    testWidgets(
      'isLoading takes precedence over isReauth: loading shows, no '
      'sign-in-again control appears',
      (tester) async {
        await tester.pumpWidget(
          l10nTestApp(
            home: AsyncStateScaffold(
              isLoading: true,
              isReauth: true,
              reauthMessage: 'Please sign in again',
              onSignInAgain: () {},
              builder: (context) => const Text('loaded'),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.byKey(const Key('async-state-reauth-sign-in-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'the sign-in-again control is present and hittable even with no appBar '
      'supplied, so a screen with no back affordance is not a dead end',
      (tester) async {
        await tester.pumpWidget(
          l10nTestApp(
            home: AsyncStateScaffold(
              isLoading: false,
              isReauth: true,
              reauthMessage: 'Please sign in again',
              onSignInAgain: () {},
              // No `appBar` — mirrors the 5 real call sites with none.
              builder: (context) => const Text('loaded'),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AppBar), findsNothing);
        expect(
          find
              .byKey(const Key('async-state-reauth-sign-in-button'))
              .hitTestable(),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the control stays hittable when the message and button cannot fit — '
      'a short viewport at a large text scale',
      (tester) async {
        // 320x240 at textScale 3.0: measured by QA as the case where the
        // button rendered at rect bottom 316 on a 240dp screen, i.e. present
        // but unreachable. The bare `Text` this branch replaced could not
        // overflow, so this failure mode is one this change introduced.
        tester.view.physicalSize = const Size(320, 240);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: l10nTestApp(
              home: AsyncStateScaffold(
                isLoading: false,
                isReauth: true,
                reauthMessage: 'Please sign in again',
                onSignInAgain: () {},
                builder: (context) => const Text('loaded'),
              ),
            ),
          ),
        );
        await tester.pump();

        // Scrolled into view rather than merely rendered off the bottom.
        await tester.scrollUntilVisible(
          find.byKey(const Key('async-state-reauth-sign-in-button')),
          100,
        );
        expect(
          find
              .byKey(const Key('async-state-reauth-sign-in-button'))
              .hitTestable(),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'content stays vertically centred when it fits — making the state '
      'scrollable must not top-align the normal case',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          l10nTestApp(
            home: AsyncStateScaffold(
              isLoading: false,
              isReauth: true,
              reauthMessage: 'Please sign in again',
              onSignInAgain: () {},
              builder: (context) => const Text('loaded'),
            ),
          ),
        );
        await tester.pump();

        final button = tester.getRect(
          find.byKey(const Key('async-state-reauth-sign-in-button')),
        );
        final message = tester.getRect(find.text('Please sign in again'));
        final blockCentre = (message.top + button.bottom) / 2;
        // Within a few dp of the viewport's own centre. A top-aligned
        // `SingleChildScrollView` would put this near the top instead.
        expect((blockCentre - 400).abs(), lessThan(8));
      },
    );

    testWidgets(
      'the control is labelled with the localized signInAgain string, in '
      'whichever locale the app is running',
      (tester) async {
        for (final locale in testSupportedLocales) {
          await tester.pumpWidget(
            l10nTestApp(
              locale: locale,
              home: AsyncStateScaffold(
                isLoading: false,
                isReauth: true,
                reauthMessage: 'ignored here',
                onSignInAgain: () {},
                builder: (context) => const Text('loaded'),
              ),
            ),
          );
          await tester.pump();

          // Asserted against the ARB lookup, not a literal: the label is now
          // resolved inside the widget, so a wrong key (or a hard-coded
          // English string) is exactly what this has to catch.
          final expected = lookupAppLocalizations(locale).signInAgain;
          expect(
            find.descendant(
              of: find.byKey(const Key('async-state-reauth-sign-in-button')),
              matching: find.text(expected),
            ),
            findsOneWidget,
            reason: 'locale $locale',
          );
        }
      },
    );
  });
}
