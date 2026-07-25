import '../domain/care_history.dart';
import '../domain/care_today.dart';

/// Thin use case over [CareHistoryRepository] — no validation or
/// orchestration beyond the pass-through (mirrors `application/care_today.dart`).
class EditCareSlot {
  final CareHistoryRepository _repository;

  EditCareSlot(this._repository);

  Future<void> call(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) => _repository.editSlot(
    idToken,
    careScheduleId: careScheduleId,
    localDate: localDate,
    timeOfDay: timeOfDay,
    status: status,
  );
}
