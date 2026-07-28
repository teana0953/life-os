import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../support/l10n_test_app.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('says the card could not be refreshed, with a retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      l10nTestApp(home: Scaffold(body: StaleNotice(onRetry: () {}))),
    );
    await tester.pumpAndSettle();

    expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
    expect(find.byKey(const Key('stale-notice-retry')), findsOneWidget);
    expect(find.text(_loc.retry), findsOneWidget);
  });

  testWidgets('tapping retry calls back', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(body: StaleNotice(onRetry: () => retries++)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pumpAndSettle();

    expect(retries, 1);
  });

  testWidgets('carries its own padding so every card indents it the same', (
    tester,
  ) async {
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 360, child: StaleNotice(onRetry: () {})),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The notice is inset from the surface it is dropped into without the
    // caller passing any layout parameter — the four overview cards would
    // otherwise each indent it differently. Measured against the notice's own
    // row rather than against the copy: the copy already sits behind an icon
    // and a gap, so an assertion on where the *text* starts passes even with
    // no padding at all.
    final notice = tester.getRect(find.byType(StaleNotice));
    final row = tester.getRect(
      find
          .descendant(of: find.byType(StaleNotice), matching: find.byType(Row))
          .first,
    );
    expect(row.left - notice.left, 20);
    expect(notice.right - row.right, 20);
    expect(row.top - notice.top, 12);
    expect(notice.bottom - row.bottom, 12);
  });

  testWidgets('does not overflow on narrow screens at large text sizes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // The marking is a copy-plus-button row, the shape most at risk of
    // running off the side of the narrowest phone at the largest text size.
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final locale in testSupportedLocales) {
          await tester.pumpWidget(
            l10nTestApp(
              locale: locale,
              home: Scaffold(body: StaleNotice(onRetry: () {})),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$locale overflowed at ${width}px / textScale $scale',
          );
        }
      }
    }
  });
}
