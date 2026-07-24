import '../domain/care_today.dart';

/// Thin use cases over [CareTodayRepository] — no validation or
/// orchestration beyond the pass-through (mirrors `application/care_items.dart`).
class GetCareToday {
  final CareTodayRepository _repository;

  GetCareToday(this._repository);

  Future<CareToday> call(String idToken) => _repository.getToday(idToken);
}

class MarkCareDone {
  final CareTodayRepository _repository;

  MarkCareDone(this._repository);

  Future<void> call(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
  }) => _repository.logSlot(
    idToken,
    careScheduleId: careScheduleId,
    localDate: localDate,
    timeOfDay: timeOfDay,
    status: CareLogStatus.done,
  );
}

class MarkCareSkipped {
  final CareTodayRepository _repository;

  MarkCareSkipped(this._repository);

  Future<void> call(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
  }) => _repository.logSlot(
    idToken,
    careScheduleId: careScheduleId,
    localDate: localDate,
    timeOfDay: timeOfDay,
    status: CareLogStatus.skipped,
  );
}
