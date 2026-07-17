import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/i18n/language_switcher.dart';

import '../../support/l10n_test_app.dart';

void main() {
  group('LanguageSwitcher', () {
    testWidgets('tapping while in English switches the locale to zh-Hant', (
      tester,
    ) async {
      final controller = await testLocaleController();
      await tester.pumpWidget(
        l10nTestApp(home: LanguageSwitcher(controller: controller)),
      );

      await tester.tap(find.byKey(const Key('language-switcher')));
      await tester.pump();

      expect(
        controller.locale,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
    });

    testWidgets('tapping while in zh-Hant switches the locale to English', (
      tester,
    ) async {
      final controller = await testLocaleController();
      await tester.pumpWidget(
        l10nTestApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
          home: LanguageSwitcher(controller: controller),
        ),
      );

      await tester.tap(find.byKey(const Key('language-switcher')));
      await tester.pump();

      expect(controller.locale, const Locale('en'));
    });
  });
}
