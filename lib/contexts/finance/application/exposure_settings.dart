import '../domain/exposure_settings_repository.dart';
import '../domain/networth_exposure.dart';

class ExposureSettings {
  final ExposureSettingsRepository _repository;
  const ExposureSettings(this._repository);

  Future<Map<String, ExposureFactor>> read(String uid) => _repository.read(uid);

  Future<void> save(String uid, String accountId, ExposureFactor? factor) =>
      _repository.write(uid, accountId, factor);
}
