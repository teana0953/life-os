import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  LocaleController? localeController,
}) {
  if (localeController == null) {
    return MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
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
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: localeController.locale ?? locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: home,
    ),
  );
}

/// Like [l10nTestApp] but backed by a `go_router` so a unit under test that
/// navigates with `context.push`/`context.pop` resolves (mirrors `lib/app.dart`,
/// where pushed full screens ride in `state.extra`). [home] is the `/` route;
/// any pushed path renders the widget carried in `extra`, so
/// `context.push('/whatever', extra: SomeScreen())` shows `SomeScreen` and back
/// returns to [home]. Depths up to three segments are covered.
Widget l10nRouterTestApp({
  required Widget home,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  LocaleController? localeController,
}) {
  // A pushed full screen may ride in `extra`; when it doesn't (the app router
  // builds it from DI in production), render the matched location so a unit test
  // can still assert *where* a tap navigated.
  Widget extra(GoRouterState state) => state.extra is Widget
      ? state.extra as Widget
      : Scaffold(body: Text(state.matchedLocation));
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(path: '/:a', builder: (context, state) => extra(state)),
      GoRoute(path: '/:a/:b', builder: (context, state) => extra(state)),
      GoRoute(path: '/:a/:b/:c', builder: (context, state) => extra(state)),
    ],
  );
  MaterialApp buildApp(Locale effectiveLocale) => MaterialApp.router(
    theme: theme,
    locale: effectiveLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: testSupportedLocales,
    routerConfig: router,
  );
  if (localeController == null) return buildApp(locale);
  return AnimatedBuilder(
    animation: localeController,
    builder: (context, _) => buildApp(localeController.locale ?? locale),
  );
}
