import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeController', () {
    test('defaults to ThemeMode.system when nothing is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final controller = ThemeController(prefs);

      expect(controller.themeMode, ThemeMode.system);
    });

    test('setThemeMode notifies listeners and persists the choice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setThemeMode(ThemeMode.dark);

      expect(notified, isTrue);
      expect(controller.themeMode, ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('restores a persisted light choice on the next launch', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();

      final controller = ThemeController(prefs);

      expect(controller.themeMode, ThemeMode.light);
    });

    test('restores a persisted dark choice on the next launch', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final controller = ThemeController(prefs);

      expect(controller.themeMode, ThemeMode.dark);
    });

    test('setThemeMode back to system persists and restores system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController(prefs);

      await controller.setThemeMode(ThemeMode.system);

      expect(controller.themeMode, ThemeMode.system);
      expect(prefs.getString('theme_mode'), 'system');
      expect(ThemeController(prefs).themeMode, ThemeMode.system);
    });
  });
}
