import 'package:flutter/material.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two locales the app supports, matching `lib/app.dart`.
const testSupportedLocales = [
  Locale('en'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

/// A [LocaleController] backed by empty in-memory [SharedPreferences], for
/// widget tests that need to construct a screen but don't exercise
/// persistence themselves.
Future<LocaleController> testLocaleController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return LocaleController(prefs);
}

/// Wraps [home] in a `MaterialApp` configured with the app's localization
/// delegates and a fixed [locale] (English by default) — the fixed test
/// locale migration path described in design.md, replacing bare
/// `MaterialApp(home: ...)` in widget tests that need `AppLocalizations`.
///
/// Pass [localeController] to make the `MaterialApp.locale` follow it
/// reactively (mirroring how `lib/app.dart` wires it up) — needed by tests
/// that tap an in-app language switcher and assert the UI updates.
Widget l10nTestApp({
  required Widget home,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  LocaleController? localeController,
}) {
  if (localeController == null) {
    return MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: home,
    );
  }
  return AnimatedBuilder(
    animation: localeController,
    builder: (context, _) => MaterialApp(
      theme: theme,
      locale: localeController.locale ?? locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: home,
    ),
  );
}
