import 'dart:async';

import 'package:life_os/contexts/finance/domain/exposure_settings_repository.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';

class FakeExposureSettingsRepository implements ExposureSettingsRepository {
  final Map<String, Map<String, ExposureFactor>> values = {};
  final Map<String, Completer<void>> readGates = {};
  Completer<void>? writeGate;
  bool failRead = false;
  bool failWrite = false;
  final List<String> writes = [];
  int concurrentWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<Map<String, ExposureFactor>> read(String uid) async {
    final snapshot = Map<String, ExposureFactor>.of(values[uid] ?? {});
    await readGates[uid]?.future;
    if (failRead) throw const ExposureSettingsFailure();
    return snapshot;
  }

  @override
  Future<void> write(
    String uid,
    String accountId,
    ExposureFactor? factor,
  ) async {
    writes.add('$uid:$accountId:${factor?.multiplier}');
    concurrentWrites++;
    if (concurrentWrites > maxConcurrentWrites) {
      maxConcurrentWrites = concurrentWrites;
    }
    try {
      await writeGate?.future;
      if (failWrite) throw const ExposureSettingsFailure();
      final factors = values.putIfAbsent(uid, () => {});
      if (factor == null) {
        factors.remove(accountId);
      } else {
        factors[accountId] = factor;
      }
    } finally {
      concurrentWrites--;
    }
  }
}
