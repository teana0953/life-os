import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the user's chosen locale in [SharedPreferences].
const _localePrefsKey = 'locale_language_code';

/// Holds the user's explicitly-chosen locale (`null` = follow the system),
/// persisting the choice via [SharedPreferences] so it survives restarts.
class LocaleController extends ChangeNotifier {
  final SharedPreferences _prefs;

  LocaleController(this._prefs) {
    switch (_prefs.getString(_localePrefsKey)) {
      case 'zh':
        _locale = const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        );
      case 'en':
        _locale = const Locale('en');
    }
  }

  Locale? _locale;

  /// The user's chosen locale, or `null` to follow the system locale.
  Locale? get locale => _locale;

  /// Sets and persists [locale] as the user's chosen language.
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _prefs.setString(_localePrefsKey, locale.languageCode);
  }

  /// Reverts to following the system locale and clears the persisted choice.
  Future<void> clear() async {
    _locale = null;
    notifyListeners();
    await _prefs.remove(_localePrefsKey);
  }
}
