import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/card_loading.dart';

void main() {
  group('CardLoading', () {
    testWidgets('renders a 48x48 spinner under the caller key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardLoading(indicatorKey: Key('goal-card-loading')),
          ),
        ),
      );

      expect(find.byKey(const Key('goal-card-loading')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('goal-card-loading'))),
        const Size(48, 48),
      );
    });

    testWidgets('centers the spinner in the space the card gives it', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardLoading(indicatorKey: Key('goal-card-loading')),
          ),
        ),
      );

      // Without the Center the 48x48 spinner sits at the top-left corner.
      final body = tester.getRect(find.byType(CardLoading));
      final spinner = tester.getRect(
        find.byKey(const Key('goal-card-loading')),
      );
      expect(spinner.center.dx, moreOrLessEquals(body.center.dx, epsilon: 1));
      expect(spinner.center.dy, moreOrLessEquals(body.center.dy, epsilon: 1));
    });
  });
}
