import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/settings/presentation/settings_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/assistant/gemini_key_controller.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:life_os/shared/pwa/pwa_install.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

// Deliberately implausible: nothing else in the widget tree can contain this
// string by coincidence, so "does not appear anywhere" assertions mean
// something.
const _fakeKey = 'AIzaSyFAKE-TEST-KEY-1234wxyz';

class _FakePwaInstall implements PwaInstall {
  @override
  final bool canInstall;
  @override
  final bool isIosHint;
  @override
  final bool isStandalone;
  bool promptInstallCalled = false;

  _FakePwaInstall({
    this.canInstall = false,
    this.isIosHint = false,
    this.isStandalone = false,
  });

  @override
  Future<void> promptInstall() async {
    promptInstallCalled = true;
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

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
    GeminiKeyController geminiKeyController,
    SharedPreferences prefs,
    _FakeAuthRepository authRepository,
  })
>
_pumpSettingsScreen(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  PwaInstall? pwaInstall,

  /// Pre-seeds the [SharedPreferences] backing [GeminiKeyController] — pass
  /// `{'gemini_api_key': ...}` to start the assistant section in its
  /// key-already-stored state.
  Map<String, Object> initialPrefs = const {},
  /// Records whether the key-console link was actually invoked. A link that
  /// renders but is wired to nothing is the shape this repo has shipped.
  Future<bool> Function()? openKeyConsole,
  Size size = const Size(800, 1400),
  double textScale = 1.0,
}) async {
  // The settings list (theme + language + friends + assistant + sign-out)
  // exceeds the default 800x600 test viewport, so widen it to keep
  // everything on-screen without needing scroll gymnastics in every test.
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final themeController = await _testThemeController();
  final localeController = await testLocaleController();
  // Built last: the helpers above each reset the prefs mock, so this is the
  // instance whose contents the assistant-key assertions read.
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  final geminiKeyController = GeminiKeyController(prefs);
  final authRepository = _FakeAuthRepository();
  Widget home = SettingsScreen(
    themeController: themeController,
    localeController: localeController,
    geminiKeyController: geminiKeyController,
    openKeyConsole: openKeyConsole ?? () async => true,
    signOut: SignOut(authRepository),
    pwaInstall: pwaInstall ?? _FakePwaInstall(isStandalone: true),
  );
  if (textScale != 1.0) {
    home = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: home,
    );
  }
  await tester.pumpWidget(
    l10nRouterTestApp(
      locale: locale,
      localeController: localeController,
      home: home,
    ),
  );
  return (
    themeController: themeController,
    localeController: localeController,
    geminiKeyController: geminiKeyController,
    prefs: prefs,
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

  group('SettingsScreen install section', () {
    testWidgets('shows Install button when canInstall and tapping it prompts', (
      tester,
    ) async {
      final pwa = _FakePwaInstall(canInstall: true);
      await _pumpSettingsScreen(tester, pwaInstall: pwa);
      final en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(en.settingsInstallSectionTitle), findsOneWidget);
      expect(find.byKey(const Key('settings-install-button')), findsOneWidget);
      expect(find.text(en.settingsInstallIosHint), findsNothing);

      await tester.tap(find.byKey(const Key('settings-install-button')));
      await tester.pumpAndSettle();

      expect(pwa.promptInstallCalled, isTrue);
    });

    testWidgets('shows the iOS hint (no button) when isIosHint', (
      tester,
    ) async {
      await _pumpSettingsScreen(
        tester,
        pwaInstall: _FakePwaInstall(isIosHint: true),
      );
      final en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(en.settingsInstallSectionTitle), findsOneWidget);
      expect(find.text(en.settingsInstallIosHint), findsOneWidget);
      expect(find.byKey(const Key('settings-install-button')), findsNothing);
    });

    testWidgets('shows nothing when isStandalone', (tester) async {
      await _pumpSettingsScreen(
        tester,
        pwaInstall: _FakePwaInstall(isStandalone: true),
      );
      final en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(en.settingsInstallSectionTitle), findsNothing);
      expect(find.byKey(const Key('settings-install-button')), findsNothing);
      expect(find.text(en.settingsInstallIosHint), findsNothing);
    });

    testWidgets('shows nothing when neither installable nor iOS', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester, pwaInstall: _FakePwaInstall());
      final en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(en.settingsInstallSectionTitle), findsNothing);
      expect(find.byKey(const Key('settings-install-button')), findsNothing);
      expect(find.text(en.settingsInstallIosHint), findsNothing);
    });
  });

  group('SettingsScreen friends entry', () {
    testWidgets('activating the friends row navigates to the friends page', (
      tester,
    ) async {
      await _pumpSettingsScreen(tester);

      await tester.ensureVisible(
        find.byKey(const Key('settings-friends-row')),
      );
      await tester.tap(find.byKey(const Key('settings-friends-row')));
      await tester.pumpAndSettle();

      // `l10nRouterTestApp` renders any push it doesn't otherwise know as
      // `Text(state.matchedLocation)` — see test/support/l10n_test_app.dart.
      expect(find.text('/friends'), findsOneWidget);
    });
  });

  group('SettingsScreen assistant key section', () {
    testWidgets(
      'without a key: intro, obscured field, disabled save, both notices',
      (tester) async {
        await _pumpSettingsScreen(tester);
        final en = lookupAppLocalizations(const Locale('en'));

        expect(find.text(en.settingsAssistantSectionTitle), findsOneWidget);
        expect(find.text(en.settingsAssistantIntro), findsOneWidget);
        expect(find.byKey(const Key('assistant-key-field')), findsOneWidget);

        // The key is a secret: dots on screen, and nothing fed to the
        // keyboard's learning/suggestion dictionary.
        final field = tester.widget<TextField>(
          find.byKey(const Key('assistant-key-field')),
        );
        expect(field.obscureText, isTrue);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);

        // Empty field → saving nothing is not an option.
        final save = tester.widget<FilledButton>(
          find.byKey(const Key('assistant-key-save-button')),
        );
        expect(save.onPressed, isNull);

        // Both warnings are visible before the user commits to anything.
        expect(find.text(en.settingsAssistantDeviceNotice), findsOneWidget);
        expect(find.text(en.settingsAssistantTrainingNotice), findsOneWidget);
      },
    );

    testWidgets(
      'whitespace-only input keeps save disabled',
      (tester) async {
        await _pumpSettingsScreen(tester);

        await tester.enterText(
          find.byKey(const Key('assistant-key-field')),
          '  \n ',
        );
        await tester.pump();

        final save = tester.widget<FilledButton>(
          find.byKey(const Key('assistant-key-save-button')),
        );
        expect(save.onPressed, isNull);
      },
    );

    testWidgets(
      'saving stores the key and the UI shows only the last four characters',
      (tester) async {
        final harness = await _pumpSettingsScreen(tester);
        final en = lookupAppLocalizations(const Locale('en'));

        await tester.enterText(
          find.byKey(const Key('assistant-key-field')),
          _fakeKey,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-key-save-button')));
        await tester.pumpAndSettle();

        expect(harness.prefs.getString('gemini_api_key'), _fakeKey);

        // The masked status line carries the tail of the key …
        expect(find.byKey(const Key('assistant-key-set-label')), findsOneWidget);
        expect(find.textContaining('wxyz'), findsOneWidget);
        // … and the full value appears nowhere in the tree, in any widget.
        expect(find.text(_fakeKey), findsNothing);
        expect(find.textContaining(_fakeKey), findsNothing);

        // Input UI is gone; clear is offered instead.
        expect(find.byKey(const Key('assistant-key-field')), findsNothing);
        expect(
          find.byKey(const Key('assistant-key-clear-button')),
          findsOneWidget,
        );
        // Both notices survive the state switch.
        expect(find.text(en.settingsAssistantDeviceNotice), findsOneWidget);
        expect(find.text(en.settingsAssistantTrainingNotice), findsOneWidget);
      },
    );

    testWidgets(
      'a stored key surfaces as masked status on a fresh screen',
      (tester) async {
        await _pumpSettingsScreen(
          tester,
          initialPrefs: const {'gemini_api_key': _fakeKey},
        );

        expect(find.byKey(const Key('assistant-key-set-label')), findsOneWidget);
        expect(find.textContaining('wxyz'), findsOneWidget);
        expect(find.textContaining(_fakeKey), findsNothing);
        expect(find.byKey(const Key('assistant-key-field')), findsNothing);
      },
    );

    testWidgets(
      'clear removes the prefs entry entirely and returns an empty field',
      (tester) async {
        final harness = await _pumpSettingsScreen(tester);

        // Full round trip through the UI so the input field's own
        // TextEditingController has actually held the secret once.
        await tester.enterText(
          find.byKey(const Key('assistant-key-field')),
          _fakeKey,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-key-save-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('assistant-key-clear-button')));
        await tester.pumpAndSettle();

        // Really removed — not overwritten with '' (that mutation keeps
        // containsKey true and turns this red).
        expect(harness.prefs.containsKey('gemini_api_key'), isFalse);

        // Back to the input state, and the field did NOT keep the old
        // secret: dropping `_keyFieldController.clear()` from the save path
        // re-surfaces the full key right here.
        final field = tester.widget<TextField>(
          find.byKey(const Key('assistant-key-field')),
        );
        expect(field.controller!.text, isEmpty);
        expect(find.textContaining(_fakeKey), findsNothing);
      },
    );

    testWidgets(
      'the full enter→save→clear flow prints nothing containing the key',
      (tester) async {
        // Honest limitation (by design, see the plan): this covers only the
        // paths this flow executes — it is a tripwire for debug-print
        // leftovers in the controller/section code, not a global guarantee.
        final log = <String>[];
        final previousDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) log.add(message);
        };

        final harness = await _pumpSettingsScreen(tester);
        try {
          await runZoned(
            () async {
              await tester.enterText(
                find.byKey(const Key('assistant-key-field')),
                _fakeKey,
              );
              await tester.pump();
              await tester.tap(
                find.byKey(const Key('assistant-key-save-button')),
              );
              await tester.pumpAndSettle();
              // Danger-side proof: the secret really traversed setKey — an
              // assertion on logs of a flow the key never entered would be
              // green forever.
              expect(harness.prefs.getString('gemini_api_key'), _fakeKey);
              await tester.tap(
                find.byKey(const Key('assistant-key-clear-button')),
              );
              await tester.pumpAndSettle();
            },
            zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, line) => log.add(line),
            ),
          );
        } finally {
          // Inline, not addTearDown: the binding verifies foundation debug
          // variables are back to normal before teardowns run.
          debugPrint = previousDebugPrint;
        }

        expect(log.join('\n'), isNot(contains(_fakeKey)));
      },
    );

    testWidgets(
      'lays out and saves at 320dp with textScale 2.0',
      (tester) async {
        final harness = await _pumpSettingsScreen(
          tester,
          size: const Size(320, 800),
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull);

        // Not just "no overflow": the input and the save button must still
        // be reachable and hittable once everything doubled in height.
        // scrollUntilVisible, not ensureVisible: the ListView builds lazily,
        // so at this height the section doesn't exist until scrolled to.
        await tester.scrollUntilVisible(
          find.byKey(const Key('assistant-key-field')),
          100,
        );
        await tester.enterText(
          find.byKey(const Key('assistant-key-field')),
          _fakeKey,
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('assistant-key-save-button')),
          100,
          // The settings ListView, explicitly: once the key field holds
          // text, its EditableText contributes a second Scrollable.
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('assistant-key-save-button')));
        await tester.pumpAndSettle();

        expect(harness.prefs.getString('gemini_api_key'), _fakeKey);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SettingsScreen localization', () {
    testWidgets('renders English strings', (tester) async {
      await _pumpSettingsScreen(tester, locale: const Locale('en'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(en.settingsTitle), findsOneWidget);
      expect(find.text(en.themeSectionTitle), findsOneWidget);
      // themeSystem and followSystemLanguage share the same "Follow system"
      // copy, so scope this assertion to the theme row to disambiguate it
      // from the language section's identical-text row.
      expect(
        find.descendant(
          of: find.byKey(const Key('theme-option-system')),
          matching: find.text(en.themeSystem),
        ),
        findsOneWidget,
      );
      expect(find.text(en.themeLight), findsOneWidget);
      expect(find.text(en.themeDark), findsOneWidget);
      expect(find.text(en.languageSectionTitle), findsOneWidget);
      expect(find.text(en.settingsAssistantSectionTitle), findsOneWidget);
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
      // themeSystem and followSystemLanguage share the same "跟隨系統"
      // copy, so scope this assertion to the theme row to disambiguate it
      // from the language section's identical-text row.
      expect(
        find.descendant(
          of: find.byKey(const Key('theme-option-system')),
          matching: find.text(zh.themeSystem),
        ),
        findsOneWidget,
      );
      expect(find.text(zh.themeLight), findsOneWidget);
      expect(find.text(zh.themeDark), findsOneWidget);
      expect(find.text(zh.languageSectionTitle), findsOneWidget);
      expect(find.text(zh.settingsAssistantSectionTitle), findsOneWidget);
      expect(find.text(zh.signOut), findsOneWidget);
    });
  });

  group('the key-console link', () {
    testWidgets('is wired to something, not just rendered', (tester) async {
      // The one thing the user has to do outside this app. A link that exists
      // and does nothing is worse than no link: they tap it, nothing happens,
      // and they have no address to fall back on.
      var opened = 0;
      await _pumpSettingsScreen(tester, openKeyConsole: () async {
        opened++;
        return true;
      });

      await tester.tap(find.byKey(const Key('assistant-get-key-link')));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.byKey(const Key('assistant-get-key-failed')), findsNothing);
    });

    testWidgets('names the address when the browser will not open', (tester) async {
      // A dead button that says nothing leaves no way forward at all.
      await _pumpSettingsScreen(tester, openKeyConsole: () async => false);

      await tester.tap(find.byKey(const Key('assistant-get-key-link')));
      await tester.pumpAndSettle();

      final snack = tester.widget<Text>(
        find.descendant(of: find.byKey(const Key('assistant-get-key-failed')), matching: find.byType(Text)),
      );
      expect(snack.data, contains('aistudio.google.com'));
    });
  });
}
