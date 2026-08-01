import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/tracker_busy_bar.dart';

Future<void> _pump(WidgetTester tester, {required bool busy}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerBusyBar(
            busy: busy,
            indicatorKey: const Key('water-busy'),
          ),
        ),
      ),
    );

void main() {
  group('TrackerBusyBar', () {
    testWidgets('busy shows an indicator under the caller key', (tester) async {
      await _pump(tester, busy: true);

      expect(find.byKey(const Key('water-busy')), findsOneWidget);
    });

    testWidgets('idle shows no indicator but keeps the 3px of height', (
      tester,
    ) async {
      await _pump(tester, busy: false);

      expect(find.byKey(const Key('water-busy')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(TrackerBusyBar)).height, 3);
    });
  });
}
