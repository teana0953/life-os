import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../support/l10n_test_app.dart';
import '../../support/layout_guard.dart';
import '../../support/month_label.dart';

Future<void> _pumpGuide(
  WidgetTester tester, {
  String title = 'Nothing here',
  String? body,
  List<Widget> actions = const <Widget>[],
  Locale locale = const Locale('en'),
  Widget Function(Widget child)? wrap,
}) {
  final guide = EmptyStateGuide(
    stateKey: const Key('the-empty-state'),
    icon: Icons.search_off,
    title: title,
    body: body,
    actions: actions,
  );
  return tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: Scaffold(body: wrap == null ? guide : wrap(guide)),
    ),
  );
}

/// The vertical gap the `SizedBox` immediately before [child] contributes,
/// read off the guide's own column rather than off a rect difference — a rect
/// difference between two `Text`s also folds in their line boxes' leading,
/// which is not the spacing the design pins.
double _gapBefore(WidgetTester tester, Widget child) {
  final column = tester.widget<Column>(find.byKey(const Key('the-empty-state')));
  final index = column.children.indexOf(child);
  expect(index, greaterThan(0), reason: 'child not found in the guide column');
  final before = column.children[index - 1];
  expect(
    before,
    isA<SizedBox>(),
    reason: 'expected a SizedBox spacer before $child',
  );
  return (before as SizedBox).height!;
}

void main() {
  group('EmptyStateGuide (tier 1: the full guide)', () {
    testWidgets('puts the caller key on the column that holds the guide', (
      tester,
    ) async {
      await _pumpGuide(tester);

      final keyed = find.byKey(const Key('the-empty-state'));
      expect(keyed, findsOneWidget);
      expect(tester.widget(keyed), isA<Column>());
      // The key names the whole guide, so everything in it is under the key.
      expect(
        find.descendant(of: keyed, matching: find.text('Nothing here')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: keyed, matching: find.byIcon(Icons.search_off)),
        findsOneWidget,
      );
    });

    testWidgets('renders the caller icon at 48 in the muted colour', (
      tester,
    ) async {
      await _pumpGuide(tester);

      final icon = tester.widget<Icon>(find.byIcon(Icons.search_off));
      expect(icon.size, 48);
      final theme = Theme.of(tester.element(find.byIcon(Icons.search_off)));
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('renders the title as centred titleMedium, 12 under the icon', (
      tester,
    ) async {
      await _pumpGuide(tester);

      final title = tester.widget<Text>(find.text('Nothing here'));
      final theme = Theme.of(tester.element(find.text('Nothing here')));
      expect(title.style, theme.textTheme.titleMedium);
      expect(title.textAlign, TextAlign.center);
      expect(_gapBefore(tester, title), 12);
    });

    testWidgets('omits the body when the caller gives none', (tester) async {
      await _pumpGuide(tester);

      final column = tester.widget<Column>(
        find.byKey(const Key('the-empty-state')),
      );
      // icon, gap, title — nothing else.
      expect(column.children.length, 3);
    });

    testWidgets('renders the body as muted centred bodyMedium, 4 under the '
        'title', (tester) async {
      await _pumpGuide(tester, body: 'Try something else');

      final body = tester.widget<Text>(find.text('Try something else'));
      final theme = Theme.of(tester.element(find.text('Try something else')));
      expect(
        body.style,
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
      expect(body.textAlign, TextAlign.center);
      expect(_gapBefore(tester, body), 4);
    });

    testWidgets('renders the actions in order, 16 below the text and 8 apart', (
      tester,
    ) async {
      // Buttons, not bare `Text`s: `actions` takes finished controls, and
      // this being the widget's own example, a bare label here would be the
      // repo's only model for how to fill the slot.
      final first = FilledButton(
        onPressed: () {},
        child: const Text('First action'),
      );
      final second = OutlinedButton(
        onPressed: () {},
        child: const Text('Second action'),
      );
      final third = OutlinedButton(
        onPressed: () {},
        child: const Text('Third action'),
      );
      await _pumpGuide(tester, body: 'Body', actions: [first, second, third]);

      expect(_gapBefore(tester, first), 16);
      expect(_gapBefore(tester, second), 8);
      expect(_gapBefore(tester, third), 8);
      expect(
        tester.getRect(find.text('First action')).top,
        lessThan(tester.getRect(find.text('Second action')).top),
      );
      expect(
        tester.getRect(find.text('Second action')).top,
        lessThan(tester.getRect(find.text('Third action')).top),
      );
    });

    testWidgets('sizes itself to its children, so it survives an unbounded '
        'height (a ListView child)', (tester) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(
            body: ListView(
              children: [
                EmptyStateGuide(
                  stateKey: const Key('the-empty-state'),
                  icon: Icons.search_off,
                  title: 'Nothing here',
                  body: 'Body',
                  actions: [FilledButton(onPressed: () {}, child: const Text('Go'))],
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('the-empty-state')), findsOneWidget);
    });

    testWidgets('takes only the height of its content, not all the room a '
        'loose bounded parent offers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // `Center` hands down *loose* constraints: a column that did not size
      // to its children would silently swallow the whole 800dp, and the
      // `LedgeCard` around it at three of the call sites would become a
      // full-height card with its content floating in the middle.
      await _pumpGuide(
        tester,
        body: 'Body',
        actions: [FilledButton(onPressed: () {}, child: const Text('Go'))],
        wrap: (child) => Center(child: child),
      );

      final height = tester.getRect(find.byKey(const Key('the-empty-state'))).height;
      expect(
        height,
        lessThan(400),
        reason: 'the guide stretched to fill its parent instead of hugging '
            'its content (height was $height of an 800dp box)',
      );
    });
  });

  group('EmptyStateNote (tier 2: the inline note)', () {
    testWidgets('is one centred muted bodyMedium line carrying the caller key', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: const Scaffold(
            body: EmptyStateNote(stateKey: Key('the-note'), text: 'No entries yet'),
          ),
        ),
      );

      final finder = find.byKey(const Key('the-note'));
      expect(finder, findsOneWidget);
      final note = tester.widget<Text>(finder);
      final theme = Theme.of(tester.element(finder));
      expect(note.data, 'No entries yet');
      expect(note.textAlign, TextAlign.center);
      expect(
        note.style,
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
      expect(paintedTextLineCount(tester, finder), 1);
    });

    testWidgets('may carry no key at all (today_screen has none)', (
      tester,
    ) async {
      await tester.pumpWidget(
        l10nTestApp(
          home: const Scaffold(body: EmptyStateNote(text: 'No entries yet')),
        ),
      );

      expect(find.text('No entries yet'), findsOneWidget);
    });
  });

  // 320dp × textScale 2.0, both locales. The guide is a bare Column by
  // design (D2a), so a *bounded* ancestor is where an overflow would be
  // thrown — the call site is responsible for the scroll. These two cases
  // pin both halves of that contract.
  group('the guide at 320dp, textScale 2.0', () {
    // The longest real copy in the app's empty states: the care-history
    // guide's title + body, plus split_tab's three actions.
    ({String title, String body, List<String> actions}) worstCase(Locale l) {
      final loc = lookupAppLocalizations(l);
      return (
        title: loc.careHistoryNoCareItemsTitle,
        body: loc.friendsEmptyMessage,
        actions: [
          loc.splitAddFriendAction,
          loc.splitEmptyCta,
          loc.splitAddGroupButton,
        ],
      );
    }

    for (final locale in testSupportedLocales) {
      testWidgets('inside a scrolling call site everything is painted in full '
          'and every action is tappable, locale=$locale', (tester) async {
        useTextScaleFactor(tester, 2.0);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final content = worstCase(locale);
        await expectNoLayoutErrors(
          () => _pumpGuide(
            tester,
            locale: locale,
            title: content.title,
            body: content.body,
            actions: [
              for (final label in content.actions)
                FilledButton(onPressed: () {}, child: Text(label)),
            ],
            // What every bounded call site does: the scroll lives here.
            wrap: (child) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        );

        // Not clipped: each label laid out every one of its glyphs.
        // Measured, not read off `RenderParagraph.didExceedMaxLines` — that
        // flag is only ever true when `maxLines` or an overflow is set, and
        // none of these `Text`s sets either, so reading it here asserted
        // nothing at all (see `expectPaintedInFull`).
        for (final text in [content.title, content.body, ...content.actions]) {
          final finder = find.text(text);
          expect(finder, findsOneWidget, reason: '"$text" is missing');
          expectPaintedInFull(
            tester,
            finder,
            reason: '"$text" was cut off at 320dp × 2.0',
          );
        }

        // Reachable: scrolled to, each action takes a hit test.
        for (final label in content.actions) {
          await tester.scrollUntilVisible(find.text(label), 100);
          expect(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(FilledButton),
            ).hitTestable(),
            findsOneWidget,
            reason: 'the "$label" action could not be hit-tested',
          );
        }
      });

      testWidgets('a bounded call site with no scroll overflows — which is '
          'why the scroll belongs at the call site, locale=$locale', (
        tester,
      ) async {
        useTextScaleFactor(tester, 2.0);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final content = worstCase(locale);
        final errors = await collectLayoutErrors(
          () => _pumpGuide(
            tester,
            locale: locale,
            title: content.title,
            body: content.body,
            actions: [
              for (final label in content.actions)
                FilledButton(onPressed: () {}, child: Text(label)),
            ],
            // A fixed box far too short for the worst case: this is the
            // shape that *does* throw, and the reason the guide never
            // assumes it can scroll.
            wrap: (child) => Center(child: SizedBox(height: 120, child: child)),
          ),
        );

        expect(
          errors,
          isNotEmpty,
          reason:
              'a bare Column that overflows a bounded box must report a '
              'layout error — if this stops being true, every '
              'expectNoLayoutErrors guard over a bounded empty state is '
              'guarding nothing',
        );
      });
    }
  });
}
