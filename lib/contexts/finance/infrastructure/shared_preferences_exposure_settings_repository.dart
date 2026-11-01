import 'package:shared_preferences/shared_preferences.dart';

import '../domain/exposure_settings_repository.dart';
import '../domain/networth_exposure.dart';

class SharedPreferencesExposureSettingsRepository
    implements ExposureSettingsRepository {
  final SharedPreferences _prefs;
  const SharedPreferencesExposureSettingsRepository(this._prefs);

  String _prefix(String uid) =>
      'networth.exposure.v1:${Uri.encodeComponent(uid)}:';

  @override
  Future<Map<String, ExposureFactor>> read(String uid) async {
    // Setters update the preferences cache before the platform confirms a
    // write. Reload so a failed save cannot become a saved factor on re-entry.
    await _prefs.reload();
    final prefix = _prefix(uid);
    final result = <String, ExposureFactor>{};
    for (final key in _prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final factor = ExposureFactor.fromStored(_prefs.get(key));
      if (factor == null) continue;
      try {
        result[Uri.decodeComponent(key.substring(prefix.length))] = factor;
      } on ArgumentError {
        continue;
      }
    }
    return result;
  }

  @override
  Future<void> write(
    String uid,
    String accountId,
    ExposureFactor? factor,
  ) async {
    final key = '${_prefix(uid)}${Uri.encodeComponent(accountId)}';
    final saved = factor == null
        ? await _prefs.remove(key)
        : await _prefs.setInt(key, factor.multiplier);
    if (!saved) throw const ExposureSettingsFailure();
  }
}
