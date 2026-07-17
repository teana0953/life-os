import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/app_theme.dart';

void main() {
  group('lightTheme', () {
    test('uses Material 3', () {
      expect(lightTheme.useMaterial3, isTrue);
    });

    test('color scheme primary is the Hachiware blue', () {
      expect(lightTheme.colorScheme.primary, hachiwareBlue);
    });

    test('color scheme brightness is light', () {
      expect(lightTheme.colorScheme.brightness, Brightness.light);
    });
  });

  group('darkTheme', () {
    test('uses Material 3', () {
      expect(darkTheme.useMaterial3, isTrue);
    });

    test('color scheme primary is the Hachiware blue', () {
      expect(darkTheme.colorScheme.primary, hachiwareBlue);
    });

    test('color scheme brightness is dark', () {
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });
  });
}
