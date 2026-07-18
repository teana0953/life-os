import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/settings/presentation/settings_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<ThemeController> _testThemeController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ThemeController(prefs);
}

Future<
  ({
    ThemeController themeController,
    LocaleController localeController,
    _FakeAuthRepository authRepository,
  })
>
_pumpSettingsScreen(WidgetTester tester, {Locale locale = const Locale('en')}) async {
  // The settings list (three theme rows + three language rows + sign-out)
  // exceeds the default 800x600 test viewport, so widen it to keep
  // everything on-screen without needing scroll gymnastics in every test.
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themeController = await _testThemeController();
  final localeController = await testLocaleController();
  final authRepository = _FakeAuthRepository();
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      localeController: localeController,
      home: SettingsScreen(
        themeController: themeController,
        localeController: localeController,
        signOut: SignOut(authRepository),
      ),
    ),
  );
  return (
    themeController: themeController,
    localeController: localeController,
    authRepository: authRepository,
  );
}

void main() {
  group('SettingsScreen theme section', () {
    testWidgets('selecting Dark calls ThemeController.setThemeMode', (
      tester,
    ) async {
      final harness = await _pumpSettingsScreen(tester);

      await tester.tap(find.byKey(const Key('theme-option-dark')));
      await tester.pumpAndSettle();

      expect(harness.themeController.themeMode, ThemeMode.dark);
    });

    testWidgets('selecting Light calls ThemeController.setThemeMode', (
      tester,
    ) async {
      final harness = await _pumpSettingsScreen(tester);

      await tester.tap(find.byKey(const Key('theme-option-light')));
      await tester.pumpAndSettle();

      expect(harness.themeController.themeMode, ThemeMode.light);
    });

    testWidgets('selecting System calls ThemeController.setThemeMode', (
      tester,
    ) async {
      final harness = await _pumpSettingsScreen(tester);
      await harness.themeController.setThemeMode(ThemeMode.dark);

      await tester.tap(find.byKey(const Key('theme-option-system')));
      await tester.pumpAndSettle();

      expect(harness.themeController.themeMode, ThemeMode.system);
    });

    testWidgets('marks the current theme selection', (tester) async {
      final harness = await _pumpSettingsScreen(tester);
      await harness.themeController.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      final darkTile = tester.widget<ListTile>(
        find.byKey(const Key('theme-option-dark')),
      );
      final lightTile = tester.widget<ListTile>(
        find.byKey(const Key('theme-option-light')),
      );
      expect(darkTile.selected, isTrue);
      expect(lightTile.selected, isFalse);
    });
  });

  group('SettingsScreen language section', () {
    testWidgets(
      'selecting Traditional Chinese calls LocaleController.setLocale',
      (tester) async {
        final harness = await _pumpSettingsScreen(tester);

        await tester.tap(find.byKey(const Key('settings-language-option-zh')));
        await tester.pumpAndSettle();

        expect(
          harness.localeController.locale,
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );
      },
    );

    testWidgets('selecting English calls LocaleController.setLocale', (
      tester,
    ) async {
      final harness = await _pumpSettingsScreen(tester);
      await harness.localeController.setLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );

      await tester.tap(find.byKey(const Key('settings-language-option-en')));
      await tester.pumpAndSettle();

      expect(harness.localeController.locale, const Locale('en'));
    });

    testWidgets('selecting System calls LocaleController.clear', (
      tester,
    ) async {
      final harness = await _pumpSettingsScreen(tester);
      await harness.localeController.setLocale(const Locale('en'));

      await tester.tap(
        find.byKey(const Key('settings-language-option-system')),
      );
      await tester.pumpAndSettle();

      expect(harness.localeController.locale, isNull);
    });
  });

  group('SettingsScreen sign-out', () {
    testWidgets('tapping sign out calls SignOut', (tester) async {
      final harness = await _pumpSettingsScreen(tester);

      await tester.tap(find.byKey(const Key('settings-sign-out-button')));
      await tester.pumpAndSettle();

      expect(harness.authRepository.signOutCalled, isTrue);
    });
  });

  group('SettingsScreen localization', () {
    testWidgets('renders English strings', (tester) async {
      await _pumpSettingsScreen(tester, locale: const Locale('en'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(en.settingsTitle), findsOneWidget);
      expect(find.text(en.themeSectionTitle), findsOneWidget);
      expect(find.text(en.themeSystem), findsOneWidget);
      expect(find.text(en.themeLight), findsOneWidget);
      expect(find.text(en.themeDark), findsOneWidget);
      expect(find.text(en.languageSectionTitle), findsOneWidget);
      expect(find.text(en.signOut), findsOneWidget);
    });

    testWidgets('renders Traditional Chinese strings', (tester) async {
      const zhHant = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      );
      await _pumpSettingsScreen(tester, locale: zhHant);
      final zh = lookupAppLocalizations(zhHant);

      expect(find.text(zh.settingsTitle), findsOneWidget);
      expect(find.text(zh.themeSectionTitle), findsOneWidget);
      expect(find.text(zh.themeSystem), findsOneWidget);
      expect(find.text(zh.themeLight), findsOneWidget);
      expect(find.text(zh.themeDark), findsOneWidget);
      expect(find.text(zh.languageSectionTitle), findsOneWidget);
      expect(find.text(zh.signOut), findsOneWidget);
    });
  });
}
