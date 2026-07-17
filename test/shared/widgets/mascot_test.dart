import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/widgets/mascot.dart';

void main() {
  group('Mascot', () {
    testWidgets('renders at the default size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: Mascot())),
      );

      final size = tester.getSize(find.byType(Mascot));
      expect(size.width, 96);
      expect(size.height, 96);
    });

    testWidgets('renders at a custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: Mascot(size: 48))),
      );

      final size = tester.getSize(find.byType(Mascot));
      expect(size.width, 48);
      expect(size.height, 48);
    });
  });
}
