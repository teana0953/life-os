import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/card_error_retry.dart';

import '../../support/l10n_test_app.dart';

final _loc = lookupAppLocalizations(const Locale('en'));

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onRetry,
  List<Widget> header = const <Widget>[],
  double headerSpacing = 16,
}) => tester.pumpWidget(
  l10nTestApp(
    home: Scaffold(
      body: CardErrorRetry(
        message: 'Could not load',
        messageKey: const Key('card-error'),
        retryKey: const Key('card-retry'),
        onRetry: onRetry,
        header: header,
        headerSpacing: headerSpacing,
      ),
    ),
  ),
);

void main() {
  group('CardErrorRetry', () {
    testWidgets('renders the message and retry under the caller keys', (
      tester,
    ) async {
      await _pump(tester, onRetry: () {});

      expect(find.byKey(const Key('card-error')), findsOneWidget);
      expect(find.byKey(const Key('card-retry')), findsOneWidget);
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text(_loc.retry), findsOneWidget);
    });

    testWidgets('tapping retry invokes onRetry', (tester) async {
      var retries = 0;
      await _pump(tester, onRetry: () => retries++);

      await tester.tap(find.byKey(const Key('card-retry')));
      expect(retries, 1);
    });

    testWidgets('without a header the column centers its children itself', (
      tester,
    ) async {
      await _pump(tester, onRetry: () {});

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.crossAxisAlignment, CrossAxisAlignment.center);
      expect(column.mainAxisSize, MainAxisSize.min);
      expect(find.byType(Center), findsNothing);
    });

    testWidgets('header widgets render above the message and stay '
        'interactive', (tester) async {
      var headerTaps = 0;
      await _pump(
        tester,
        onRetry: () {},
        header: [
          TextButton(
            key: const Key('card-header-action'),
            onPressed: () => headerTaps++,
            child: const Text('Header action'),
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('card-header-action')));
      expect(headerTaps, 1);

      final headerY = tester
          .getTopLeft(find.byKey(const Key('card-header-action')))
          .dy;
      final messageY = tester
          .getTopLeft(find.byKey(const Key('card-error')))
          .dy;
      expect(headerY, lessThan(messageY));
    });

    testWidgets('a header aligns the column to start and centers the message '
        'and retry individually', (tester) async {
      await _pump(
        tester,
        onRetry: () {},
        header: const [Text('Header')],
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);
      // The message and the retry each get their own Center; the header is
      // spread in as a sibling rather than wrapped in a nested Column.
      expect(find.byType(Center), findsNWidgets(2));
      expect(find.byType(Column), findsOneWidget);

      final width = tester.getSize(find.byType(CardErrorRetry)).width;
      expect(tester.getCenter(find.byKey(const Key('card-retry'))).dx,
          moreOrLessEquals(width / 2, epsilon: 1));
    });

    testWidgets('headerSpacing sets the gap between header and message', (
      tester,
    ) async {
      await _pump(
        tester,
        onRetry: () {},
        header: const [Text('Header')],
        headerSpacing: 40,
      );

      final spacers = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .map((s) => s.height)
          .toList();
      expect(spacers, contains(40.0));
      expect(spacers, contains(12.0));
    });
  });
}
