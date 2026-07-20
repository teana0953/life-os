import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/platform/keyboard_inset.dart';

void main() {
  group('computeKeyboardInset', () {
    test('no keyboard (viewport == layout, offsetTop 0) -> 0', () {
      final inset = computeKeyboardInset(
        layoutHeight: 800,
        viewportHeight: 800,
        offsetTop: 0,
      );
      expect(inset, 0);
    });

    test('keyboard occupies the bottom of the layout viewport', () {
      final inset = computeKeyboardInset(
        layoutHeight: 800,
        viewportHeight: 500,
        offsetTop: 0,
      );
      expect(inset, 300);
    });

    test('offsetTop > 0 (visual viewport offset from the top) is subtracted too', () {
      final inset = computeKeyboardInset(
        layoutHeight: 800,
        viewportHeight: 500,
        offsetTop: 50,
      );
      expect(inset, 250);
    });

    test('over-subtraction clamps to 0', () {
      final inset = computeKeyboardInset(
        layoutHeight: 500,
        viewportHeight: 800,
        offsetTop: 0,
      );
      expect(inset, 0);
    });
  });
}
