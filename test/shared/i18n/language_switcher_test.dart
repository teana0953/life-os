import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/i18n/language_switcher.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/l10n_test_app.dart';

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

/// A [LocaleController] backed by in-memory [SharedPreferences] seeded with
/// [initialLanguageCode] (`'en'`/`'zh'`/`null` for "follow system"), for
/// tests that need the switcher's starting selection to already be explicit
/// (e.g. to exercise reverting to "follow system").
Future<LocaleController> _localeControllerWith(
  String? initialLanguageCode,
) async {
  SharedPreferences.setMockInitialValues(
    initialLanguageCode == null
        ? {}
        : {'locale_language_code': initialLanguageCode},
  );
  final prefs = await SharedPreferences.getInstance();
  return LocaleController(prefs);
}

void main() {
  group('LanguageSwitcher', () {
    testWidgets('shows the current language label when in English', (
      tester,
    ) async {
      final controller = await testLocaleController();
      final en = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        l10nTestApp(
          home: Scaffold(body: LanguageSwitcher(controller: controller)),
        ),
      );

      expect(find.text(en.languageEnglish), findsOneWidget);
      expect(find.byIcon(Icons.translate), findsOneWidget);
    });

    testWidgets('shows the current language label when in zh-Hant', (
      tester,
    ) async {
      final controller = await testLocaleController();
      final zhHant = lookupAppLocalizations(_zhHant);
      await tester.pumpWidget(
        l10nTestApp(
          locale: _zhHant,
          home: Scaffold(body: LanguageSwitcher(controller: controller)),
        ),
      );

      expect(find.text(zhHant.languageTraditionalChinese), findsOneWidget);
    });

    testWidgets(
      'tapping the switcher opens a menu with follow system, English, '
      'and Traditional Chinese options',
      (tester) async {
        final controller = await testLocaleController();
        final en = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(body: LanguageSwitcher(controller: controller)),
          ),
        );

        await tester.tap(find.byKey(const Key('language-switcher')));
        await tester.pumpAndSettle();

        final systemOption = find.byKey(const Key('language-option-system'));
        final enOption = find.byKey(const Key('language-option-en'));
        final zhOption = find.byKey(const Key('language-option-zh'));
        expect(systemOption, findsOneWidget);
        expect(enOption, findsOneWidget);
        expect(zhOption, findsOneWidget);
        expect(
          find.descendant(
            of: systemOption,
            matching: find.text(en.followSystemLanguage),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: enOption,
            matching: find.text(en.languageEnglish),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: zhOption,
            matching: find.text(en.languageTraditionalChinese),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'selecting English from the menu calls controller.setLocale(en)',
      (tester) async {
        final controller = await _localeControllerWith('zh');
        await tester.pumpWidget(
          l10nTestApp(
            locale: _zhHant,
            localeController: controller,
            home: Scaffold(body: LanguageSwitcher(controller: controller)),
          ),
        );

        await tester.tap(find.byKey(const Key('language-switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('language-option-en')));
        await tester.pumpAndSettle();

        expect(controller.locale, const Locale('en'));
      },
    );

    testWidgets('selecting Traditional Chinese from the menu calls '
        'controller.setLocale(zh-Hant)', (tester) async {
      final controller = await testLocaleController();
      await tester.pumpWidget(
        l10nTestApp(
          localeController: controller,
          home: Scaffold(body: LanguageSwitcher(controller: controller)),
        ),
      );

      await tester.tap(find.byKey(const Key('language-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-option-zh')));
      await tester.pumpAndSettle();

      expect(controller.locale, _zhHant);
    });

    testWidgets(
      'selecting "follow system" from the menu calls controller.clear()',
      (tester) async {
        final controller = await _localeControllerWith('zh');
        await tester.pumpWidget(
          l10nTestApp(
            locale: _zhHant,
            localeController: controller,
            home: Scaffold(body: LanguageSwitcher(controller: controller)),
          ),
        );

        await tester.tap(find.byKey(const Key('language-switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('language-option-system')));
        await tester.pumpAndSettle();

        expect(controller.locale, isNull);
      },
    );

    testWidgets('marks the currently active language as checked in the menu', (
      tester,
    ) async {
      final controller = await _localeControllerWith('zh');
      await tester.pumpWidget(
        l10nTestApp(
          locale: _zhHant,
          localeController: controller,
          home: Scaffold(body: LanguageSwitcher(controller: controller)),
        ),
      );

      await tester.tap(find.byKey(const Key('language-switcher')));
      await tester.pumpAndSettle();

      final zhItem = tester.widget<CheckedPopupMenuItem<Object?>>(
        find.byKey(const Key('language-option-zh')),
      );
      final enItem = tester.widget<CheckedPopupMenuItem<Object?>>(
        find.byKey(const Key('language-option-en')),
      );
      final systemItem = tester.widget<CheckedPopupMenuItem<Object?>>(
        find.byKey(const Key('language-option-system')),
      );
      expect(zhItem.checked, isTrue);
      expect(enItem.checked, isFalse);
      expect(systemItem.checked, isFalse);
    });
  });
}
