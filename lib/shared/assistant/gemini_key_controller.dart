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
/// state — including [toString], which is overridden below to prove it: the
/// default `Object.toString()` never touches fields at all, so a test
/// asserting "toString doesn't contain the key" against the default
/// implementation can never fail and proves nothing.
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
    // The write comes first, and its failure propagates. Notifying before it
    // resolves would paint "已設定 ✓" over a key that never reached storage —
    // and on a PWA that is not hypothetical: private browsing, a blocked
    // storage quota, or cleared site data all make this write fail. The user
    // would only find out on the next reload, which is this repo's most
    // familiar failure shape.
    await _prefs.setString(_geminiKeyPrefsKey, trimmed);
    _key = trimmed;
    notifyListeners();
  }

  /// Removes the stored key entirely — `remove`, not `setString('')`, so no
  /// empty husk of the entry survives in prefs.
  Future<void> clear() async {
    // Same ordering, same reason: a clear that appears to work while the key
    // is still on disk is worse than one that visibly failed.
    await _prefs.remove(_geminiKeyPrefsKey);
    _key = null;
    notifyListeners();
  }

  /// Deliberately reports only [hasKey] — the safe half of this object's
  /// state — so any accidental future edit that interpolates [_key] or [key]
  /// in here is the one line standing between the secret and every log line
  /// this object's default representation would otherwise flow through.
  @override
  String toString() => 'GeminiKeyController(hasKey: $hasKey)';
}
