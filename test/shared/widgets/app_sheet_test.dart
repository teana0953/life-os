import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/app_sheet.dart';

import '../../support/sheet_finders.dart';

/// Records every route pushed through this observer, so a test can tell
/// which `Navigator` a route actually landed on.
class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  group('showAppSheet', () {
    testWidgets('shows a drag handle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (_) => const SizedBox(height: 100),
                  ),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expectSheetHasDragHandle(tester);
    });

    testWidgets('opens on the nearest Navigator, not the root', (
      tester,
    ) async {
      final outerObserver = _RecordingNavigatorObserver();
      final innerObserver = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [outerObserver],
          home: Scaffold(
            body: Navigator(
              observers: [innerObserver],
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showAppSheet<void>(
                      context,
                      builder: (_) => const SizedBox(height: 100),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // The pump above already pushed the initial routes on both
      // Navigators; only the sheet's push matters from here.
      outerObserver.pushed.clear();
      innerObserver.pushed.clear();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        innerObserver.pushed,
        isNotEmpty,
        reason: 'the sheet should push onto the nested Navigator it was '
            'opened from',
      );
      expect(
        outerObserver.pushed,
        isEmpty,
        reason: 'the sheet should not reach the root Navigator (this app '
            'uses nested go_router shells, so a root-navigator sheet '
            'would outlive the shell route it was opened from)',
      );
    });

    // Regression pin, not a claim about `showAppSheet`'s own choices:
    // `isDismissible` defaults to true and the helper never sets it, so this
    // stays green under a mutation of any of the three options. It exists to
    // catch someone turning the default off while adding a fourth option.
    testWidgets('pins the Flutter default: tapping the barrier dismisses the '
        'sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => const SizedBox(
                    height: 100,
                    child: Text('sheet content'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet content'), findsOneWidget);

      // Tap the barrier well above the sheet, which is a fraction of the
      // (unconstrained-height) test surface.
      await tester.tapAt(const Offset(400, 10));
      await tester.pumpAndSettle();

      expect(find.text('sheet content'), findsNothing);
    });

    // Same kind of pin as above: drag-to-dismiss comes from `enableDrag`
    // (default true, never set here), and the fling below targets the
    // builder's own content, not the handle. `shows a drag handle` is the
    // test that actually covers `showDragHandle`.
    testWidgets('pins the Flutter default: dragging the sheet down dismisses '
        'it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => const SizedBox(
                    height: 100,
                    child: Text('sheet content'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet content'), findsOneWidget);

      await tester.fling(
        find.byType(SizedBox).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('sheet content'), findsNothing);
    });

    testWidgets('content taller than 9/16 of the screen is not clipped', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(400, 800));

      const bottomKey = Key('sheet-bottom-marker');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 700),
                      Container(
                        key: bottomKey,
                        height: 20,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 9/16 of the 800-tall screen is 450 — the content here is taller
      // than that. Removing `isScrollControlled` from the helper reddens
      // this test twice over: the capped sheet's Column overflows
      // ("A RenderFlex overflowed by 318 pixels on the bottom") and this
      // bottom marker stops being hittable.
      expect(find.byKey(bottomKey).hitTestable(), findsOneWidget);
    });

    testWidgets('useSafeArea removes top/left/right padding from the sheet '
        'content, but not bottom', (tester) async {
      EdgeInsets? capturedPadding;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 34),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (sheetContext) {
                      capturedPadding = MediaQuery.paddingOf(sheetContext);
                      return const SizedBox(height: 100);
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // `useSafeArea: true` wraps the content in `SafeArea(bottom: false)`
      // — left/right intrusions are avoided, bottom is deliberately left to
      // the sheet itself (see `showAppSheet`'s doc comment). `top` is
      // deliberately not asserted here: without `useSafeArea`, Flutter's
      // sheet route still applies `MediaQuery.removePadding(removeTop:
      // true)` on its own, so a zeroed `top` doesn't distinguish this
      // helper's behaviour — only left/right do. Likewise `bottom` stays
      // 34 (the ambient value) whether or not `useSafeArea` is passed, so
      // it isn't asserted either.
      expect(capturedPadding, isNotNull);
      expect(capturedPadding!.left, 0);
      expect(capturedPadding!.right, 0);
    });
  });
}
