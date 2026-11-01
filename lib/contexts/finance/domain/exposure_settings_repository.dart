import 'networth_exposure.dart';

abstract interface class ExposureSettingsRepository {
  Future<Map<String, ExposureFactor>> read(String uid);
  Future<void> write(String uid, String accountId, ExposureFactor? factor);
}

class ExposureSettingsFailure implements Exception {
  const ExposureSettingsFailure();
}
