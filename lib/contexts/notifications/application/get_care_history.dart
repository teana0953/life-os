import '../domain/care_history.dart';

/// Thin use case over [CareHistoryRepository] — no validation or
/// orchestration beyond the pass-through (mirrors `application/care_today.dart`).
class GetCareHistory {
  final CareHistoryRepository _repository;

  GetCareHistory(this._repository);

  Future<List<CareHistoryDay>> call(String idToken, String from, String to) =>
      _repository.getRange(idToken, from, to);
}
