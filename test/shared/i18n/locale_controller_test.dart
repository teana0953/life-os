import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocaleController', () {
    test(
      'defaults to null (follow the system) when nothing is persisted',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final controller = LocaleController(prefs);

        expect(controller.locale, isNull);
      },
    );

    test('setLocale notifies listeners and persists the choice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = LocaleController(prefs);
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );

      expect(notified, isTrue);
      expect(
        controller.locale,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(prefs.getString('locale_language_code'), 'zh');
    });

    test('restores the persisted choice on the next launch', () async {
      SharedPreferences.setMockInitialValues({'locale_language_code': 'zh'});
      final prefs = await SharedPreferences.getInstance();

      final controller = LocaleController(prefs);

      expect(
        controller.locale,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
    });

    test(
      'clear resets to following the system and removes the persisted choice',
      () async {
        SharedPreferences.setMockInitialValues({
          'locale_language_code': 'zh',
        });
        final prefs = await SharedPreferences.getInstance();
        final controller = LocaleController(prefs);

        await controller.clear();

        expect(controller.locale, isNull);
        expect(prefs.getString('locale_language_code'), isNull);
      },
    );
  });
}
