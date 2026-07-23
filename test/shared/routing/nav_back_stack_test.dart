import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/l10n_test_app.dart';

/// Regression for the web back-button bug: with the old Navigator-1.0 +
/// SingleEntryBrowserHistory setup, the system/browser back button left the app
/// before the route stack was emptied. Under the Router API each push is its own
/// entry, so N system-backs from a depth-N stack return through every screen
/// before leaving. This exercises that stacking via [handlePopRoute] (the
/// framework's system-back signal), independent of the web engine.
class _Pusher extends StatelessWidget {
  final String label;
  final String? pushPath;
  final Widget? pushChild;
  const _Pusher({required this.label, this.pushPath, this.pushChild});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, key: Key('label-$label')),
            if (pushPath != null)
              TextButton(
                key: Key('push-$label'),
                onPressed: () => context.push(pushPath!, extra: pushChild),
                child: const Text('push'),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'a URL-driven deep route (go) rebuilds the whole nested stack, so pop '
    'returns one level — not to the base',
    (tester) async {
      // `go()` mirrors what a web browser back / refresh does: it reconstructs
      // the page stack from the URL. With FLAT top-level routes this rebuilt only
      // the leaf, so a pop collapsed to `/` (the reported "back goes to grid"
      // bug). Nested routes rebuild every ancestor, so pop steps up one level.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('BASE'))),
          GoRoute(
            path: '/health',
            builder: (c, s) => const Scaffold(body: Text('HEALTH')),
            routes: [
              GoRoute(
                path: 'diet',
                builder: (c, s) => const Scaffold(body: Text('DIET')),
                routes: [
                  GoRoute(
                    path: 'target',
                    builder: (c, s) => const Scaffold(body: Text('TARGET')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/health/diet/target');
      await tester.pumpAndSettle();
      expect(find.text('TARGET'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('DIET'), findsOneWidget);
      expect(find.text('BASE'), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('HEALTH'), findsOneWidget);
    },
  );

  testWidgets(
    'two system-backs from a two-push stack return to base in order',
    (tester) async {
      await tester.pumpWidget(
        l10nRouterTestApp(
          home: const _Pusher(
            label: 'BASE',
            pushPath: '/a',
            pushChild: _Pusher(
              label: 'A',
              pushPath: '/a/b',
              pushChild: _Pusher(label: 'B'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('push-BASE')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('label-A')), findsOneWidget);

      await tester.tap(find.byKey(const Key('push-A')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('label-B')), findsOneWidget);

      // First system back → screen A (not out of the app).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('label-A')), findsOneWidget);
      expect(find.byKey(const Key('label-B')), findsNothing);

      // Second system back → base (still in the app; only a third would leave).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('label-BASE')), findsOneWidget);
      expect(find.byKey(const Key('label-A')), findsNothing);
    },
  );
}
