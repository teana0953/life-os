import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the user's chosen [ThemeMode] in [SharedPreferences].
const _themePrefsKey = 'theme_mode';

/// Holds the user's chosen [ThemeMode] (system/light/dark, default
/// [ThemeMode.system]), persisting the choice via [SharedPreferences] so it
/// survives restarts. Mirrors [LocaleController].
class ThemeController extends ChangeNotifier {
  final SharedPreferences _prefs;

  ThemeController(this._prefs) {
    final stored = _prefs.getString(_themePrefsKey);
    if (stored != null) {
      _themeMode = ThemeMode.values.byName(stored);
    }
  }

  ThemeMode _themeMode = ThemeMode.system;

  /// The user's chosen theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Sets and persists [mode] as the user's chosen theme.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themePrefsKey, mode.name);
  }
}
