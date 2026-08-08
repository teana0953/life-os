import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the user's Gemini API key in [SharedPreferences].
///
/// Deliberately named after the provider, not a generic `assistant_api_key`:
/// this value's only legitimate destination is the Gemini adapter, and a
/// generic name would invite a future provider switch to silently reuse the
/// same slot — sending a Gemini key to someone else's API. A provider switch
/// must introduce a new key and migrate deliberately.
const _geminiKeyPrefsKey = 'gemini_api_key';

/// Holds the user's Gemini API key, persisted on-device via
/// [SharedPreferences] (device-local only — reinstalling the PWA or clearing
/// browser data removes it). Mirrors [LocaleController]/[ThemeController].
///
/// The full key is a secret: UI code must only ever render [hasKey] and
/// [last4]. It must never appear in logs, error messages, or serialized
/// state — hence no [toString] override carrying it.
class GeminiKeyController extends ChangeNotifier {
  final SharedPreferences _prefs;

  GeminiKeyController(this._prefs) : _key = _prefs.getString(_geminiKeyPrefsKey);

  String? _key;

  /// Whether a key is stored.
  bool get hasKey => _key != null;

  /// The last four characters of the stored key (`null` when none) — the only
  /// fragment of it the UI may display.
  String? get last4 {
    final key = _key;
    if (key == null) return null;
    return key.length <= 4 ? key : key.substring(key.length - 4);
  }

  /// The full stored key, or `null`. **For the Gemini HTTP adapter only —
  /// never render, log, or serialize this value.**
  String? get key => _key;

  /// Trims and persists [rawKey] as the user's Gemini API key. Pasted keys
  /// routinely carry a trailing newline; stored untrimmed it would corrupt
  /// the auth header. Throws [ArgumentError] when empty after trimming.
  Future<void> setKey(String rawKey) async {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) {
      // Deliberately does not include the raw value: it is (whitespace
      // around) a secret and must not ride along in error messages.
      throw ArgumentError('Gemini API key must not be empty');
    }
    _key = trimmed;
    notifyListeners();
    await _prefs.setString(_geminiKeyPrefsKey, trimmed);
  }

  /// Removes the stored key entirely — `remove`, not `setString('')`, so no
  /// empty husk of the entry survives in prefs.
  Future<void> clear() async {
    _key = null;
    notifyListeners();
    await _prefs.remove(_geminiKeyPrefsKey);
  }
}
