import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../support/l10n_test_app.dart';
import '../../support/semantics_tree.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

const _subject = 'Weight goal';

/// WCAG 2.x relative luminance / contrast ratio (same maths as
/// `test/shared/theme/app_theme_test.dart`), used to hold the retry's
/// foreground to AA on the card it is drawn on.
double _relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = max(la, lb);
  final darker = min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// The card's two booleans, flipped by the test the way a controller would
/// flip them: a retry puts the card into `loading`, and the load that lands
/// puts it back into failed / not-failed.
typedef _Reload = ({bool failed, bool loading});

/// Pumps the notice against a mutable [_Reload], returning the notifier so a
/// test can pose the reload landing. [onRetry] defaults to the realistic
/// thing: the tap starts a load, so `failed` drops and `loading` rises.
Future<ValueNotifier<_Reload>> _pump(
  WidgetTester tester, {
  _Reload initial = (failed: true, loading: false),
  void Function(ValueNotifier<_Reload> state)? onRetry,
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) async {
  final state = ValueNotifier<_Reload>(initial);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    l10nTestApp(
      theme: theme,
      locale: locale,
      home: Scaffold(
        body: ValueListenableBuilder<_Reload>(
          valueListenable: state,
          builder: (context, value, child) => StaleNotice(
            failed: value.failed,
            loading: value.loading,
            subject: _subject,
            onRetry: () => (onRetry ??
                (s) => s.value = (failed: false, loading: true))(state),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return state;
}

TextButton _retryButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.byKey(const Key('stale-notice-retry')));

Finder _spinner() => find.descendant(
  of: find.byType(StaleNotice),
  matching: find.byType(CircularProgressIndicator),
);

void main() {
  testWidgets('says the card could not be refreshed, with a retry', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
    expect(find.byKey(const Key('stale-notice-retry')), findsOneWidget);
    expect(find.text(_loc.retry), findsOneWidget);
    expect(_retryButton(tester).onPressed, isNotNull);
    expect(_spinner(), findsNothing);
  });

  testWidgets('nothing failed — the card carries no marking at all', (
    tester,
  ) async {
    await _pump(tester, initial: (failed: false, loading: false));

    expect(find.text(_loc.cardRefreshFailed), findsNothing);
    expect(find.byKey(const Key('stale-notice-retry')), findsNothing);
  });

  testWidgets(
    'a reload nobody asked for does not raise a marking of its own',
    (tester) async {
      // Only a retry the user pressed keeps the row on screen while it runs;
      // a background refresh over healthy content stays silent.
      await _pump(tester, initial: (failed: false, loading: true));

      expect(find.text(_loc.cardRefreshFailed), findsNothing);
      expect(_spinner(), findsNothing);
    },
  );

  testWidgets('tapping retry calls back', (tester) async {
    var retries = 0;
    await _pump(tester, onRetry: (state) {
      retries++;
      state.value = (failed: false, loading: true);
    });

    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pump();

    expect(retries, 1);
  });

  group('the retry it started, while that retry is in flight', () {
    testWidgets(
      'keeps the row rather than letting it vanish as if the card had '
      'refreshed',
      (tester) async {
        await _pump(tester);
        await tester.tap(find.byKey(const Key('stale-notice-retry')));
        await tester.pump();

        // The request is still in the air. Taking the marking away here is
        // the silent-stale-data failure this widget exists to prevent, only
        // triggered by the user's own tap.
        expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
      },
    );

    testWidgets('disables the button and puts a spinner in it', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('stale-notice-retry')));
      await tester.pump();

      expect(_retryButton(tester).onPressed, isNull);
      expect(_spinner(), findsOneWidget);
    });
  });

  testWidgets('a retry that succeeds takes the whole marking away', (
    tester,
  ) async {
    final state = await _pump(tester);
    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pump();

    state.value = (failed: false, loading: false);
    await tester.pumpAndSettle();

    expect(find.text(_loc.cardRefreshFailed), findsNothing);
    expect(find.byKey(const Key('stale-notice-retry')), findsNothing);
  });

  testWidgets('a retry that fails again leaves a row that can be pressed once '
      'more', (tester) async {
    var retries = 0;
    final state = await _pump(tester, onRetry: (s) {
      retries++;
      s.value = (failed: false, loading: true);
    });
    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pump();

    state.value = (failed: true, loading: false);
    await tester.pumpAndSettle();

    expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
    expect(_spinner(), findsNothing);
    expect(_retryButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('stale-notice-retry')));
    await tester.pump();
    expect(retries, 2);
  });

  group('the whole row is the target, not just the button', () {
    testWidgets('tapping the copy retries', (tester) async {
      var retries = 0;
      await _pump(tester, onRetry: (state) {
        retries++;
        state.value = (failed: false, loading: true);
      });

      await tester.tap(find.text(_loc.cardRefreshFailed));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('tapping the icon retries', (tester) async {
      var retries = 0;
      await _pump(tester, onRetry: (state) {
        retries++;
        state.value = (failed: false, loading: true);
      });

      await tester.tap(find.byIcon(Icons.cloud_off_outlined));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('the row stops taking taps while its retry is in flight', (
      tester,
    ) async {
      var retries = 0;
      await _pump(tester, onRetry: (state) {
        retries++;
        state.value = (failed: false, loading: true);
      });

      await tester.tap(find.text(_loc.cardRefreshFailed));
      await tester.pump();
      await tester.tap(find.text(_loc.cardRefreshFailed));
      await tester.pump();

      expect(retries, 1);
    });
  });

  group('accessibility', () {
    testWidgets('is a node of its own that names the card it belongs to — four '
        'markings on one overview must not all read as a bare "Retry"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      final data = tester
          .getSemantics(find.byType(StaleNotice))
          .getSemanticsData();
      expect(data.label, '$_subject: ${_loc.cardRefreshFailed}. ${_loc.retry}');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      // And it is the *only* node here: left to itself the retry button
      // contributes a second one labelled nothing but "Retry", which is the
      // four-identical-buttons problem in miniature.
      expect(find.bySemanticsLabel(_loc.retry), findsNothing);

      handle.dispose();
    });

    testWidgets('reads as disabled while its retry is in flight', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await tester.tap(find.byKey(const Key('stale-notice-retry')));
      await tester.pump();

      final data = tester
          .getSemantics(find.byType(StaleNotice))
          .getSemanticsData();
      expect(data.flagsCollection.hasEnabledState, isTrue);
      expect(data.flagsCollection.isEnabled, isFalse);

      handle.dispose();
    });

    // Reads the real `SemanticsOwner` tree via `semanticsDataForLabel`
    // (`test/support/semantics_tree.dart`), not `tester.getSemantics`
    // (a widget's *cached* node) — this row can appear with no gesture
    // from the reader (a background reload elsewhere failing while they're
    // mid-scroll), so what actually reaches the platform's accessibility
    // tree is what matters, not merely what the widget asked for.
    testWidgets(
      'is announced as a live region when a reload has actually failed',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, initial: (failed: true, loading: false));

        final data = semanticsDataForLabel(
          tester,
          '$_subject: ${_loc.cardRefreshFailed}. ${_loc.retry}',
        );
        expect(data, isNotNull);
        expect(data!.flagsCollection.isLiveRegion, isTrue);

        handle.dispose();
      },
    );

    testWidgets(
      'is not a live region while merely showing an in-flight retry — '
      'nothing has failed yet for a screen-reader user to be interrupted for',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, initial: (failed: false, loading: true));
        // Nothing renders here (see "a reload nobody asked for..." above),
        // so there is no live-region node to find at all.
        expect(
          semanticsDataForLabel(
            tester,
            '$_subject: ${_loc.cardRefreshFailed}. ${_loc.retry}',
          ),
          isNull,
        );

        // The state that actually renders `retrying` (a press followed by a
        // still-in-flight reload) carries the distinct "refreshing" label —
        // this is the case that must NOT be a live region, since
        // `widget.failed` is false.
        await _pump(tester);
        await tester.tap(find.byKey(const Key('stale-notice-retry')));
        await tester.pump();

        final data = semanticsDataForLabel(
          tester,
          '$_subject: ${_loc.cardRefreshing}',
        );
        expect(data, isNotNull);
        expect(data!.flagsCollection.isLiveRegion, isFalse);

        handle.dispose();
      },
    );

    // The finance tabs (`FinanceOverviewTab`/`FinanceTransactionsTab`) key
    // [StaleNotice.failed] off a flag that only clears on the *next success*
    // — unlike the other callers, whose `failed` is `status == error` and so
    // drops to `false` the moment a retry starts loading. That means finance
    // is the one caller that can actually reach `failed: true, loading:
    // true` mid-retry, which the two tests above never exercise.
    testWidgets(
      'switches off the live region and away from the failure label while '
      'retrying even if the caller keeps `failed` true through the retry '
      "(finance tabs' shape)",
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          initial: (failed: true, loading: false),
          // Unlike `_pump`'s default `onRetry`, mirror the finance tabs:
          // `failed` stays true while the retry is in flight.
          onRetry: (state) => state.value = (failed: true, loading: true),
        );
        await tester.tap(find.byKey(const Key('stale-notice-retry')));
        await tester.pump();

        final failureLabel = semanticsDataForLabel(
          tester,
          '$_subject: ${_loc.cardRefreshFailed}. ${_loc.retry}',
        );
        expect(
          failureLabel,
          isNull,
          reason:
              'the failure label must not still be announced once a retry '
              'this row itself started is in flight',
        );

        final retryingLabel = semanticsDataForLabel(
          tester,
          '$_subject: ${_loc.cardRefreshing}',
        );
        expect(retryingLabel, isNotNull);
        expect(
          retryingLabel!.flagsCollection.isLiveRegion,
          isFalse,
          reason:
              'a live region here would re-announce the same failure the '
              'reader just pressed Retry on, as if the retry had already '
              'failed again',
        );

        handle.dispose();
      },
    );
  });

  group('the retry label meets AA contrast on the card it sits on', () {
    for (final (name, theme) in [
      ('light', lightTheme),
      ('dark', darkTheme),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, theme: theme);

        // The colour actually painted, not the one the widget asked for: the
        // button's own theming sits between the two.
        final painted = tester
            .widget<RichText>(
              find.descendant(
                of: find.byKey(const Key('stale-notice-retry')),
                matching: find.byType(RichText),
              ),
            )
            .text
            .style!
            .color!;
        expect(
          _contrastRatio(painted, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
          reason:
              '$name: the retry is body-sized text on the card surface, so it '
              'needs 4.5:1',
        );
      });
    }
  });

  testWidgets('a retry that starts nothing does not colour the next reload', (
    tester,
  ) async {
    // `CareTodayController.load` opens with `if (_fetching) return`, so a
    // retry pressed while a quiet reload is already in flight sets the press
    // but starts nothing — `loading` never goes true. Forgetting the press
    // has to be level-triggered (`!loading`), not edge-triggered: an edge that
    // never fires would leave the press to dress the NEXT background reload as
    // the user's, spinner and all.
    final state = await _pump(tester, onRetry: (s) {});

    await tester.tap(find.byKey(const Key('stale-notice-row')));
    await tester.pump();

    // The press started nothing, so the row is unchanged and still pressable.
    expect(_spinner(), findsNothing);
    expect(_retryButton(tester).onPressed, isNotNull);

    // The quiet reload that was already running lands. It never touched
    // `loading`, so the card rebuilds with `loading` still false — the level
    // check forgets the press here. An edge check would not, having never seen
    // `loading` go true.
    state.value = (failed: false, loading: false);
    await tester.pump();

    // A later background reload — one nobody asked for — must not wear the
    // press as a spinner.
    state.value = (failed: false, loading: true);
    await tester.pump();
    expect(_spinner(), findsNothing);
  });

  testWidgets('carries its own padding so every card indents it the same', (
    tester,
  ) async {
    await tester.pumpWidget(
      l10nTestApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: StaleNotice(
                failed: true,
                loading: false,
                subject: _subject,
                onRetry: () {},
              ),
            ),
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
              home: Scaffold(
                body: StaleNotice(
                  failed: true,
                  loading: false,
                  subject: _subject,
                  onRetry: () {},
                ),
              ),
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
