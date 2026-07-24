import '../domain/care_item.dart';

/// Thin use cases over [CareItemRepository] — no validation or
/// orchestration beyond the pass-through; front-end validation lives in the
/// form (client-basic, server-authoritative).
class ListCareItems {
  final CareItemRepository _repository;

  ListCareItems(this._repository);

  Future<List<CareItem>> call(String idToken) => _repository.list(idToken);
}

class CreateCareItem {
  final CareItemRepository _repository;

  CreateCareItem(this._repository);

  Future<CareItem> call(String idToken, CareItemDraft draft) =>
      _repository.create(idToken, draft);
}

class UpdateCareItem {
  final CareItemRepository _repository;

  UpdateCareItem(this._repository);

  Future<CareItem> call(String idToken, String id, CareItemUpdate changes) =>
      _repository.update(idToken, id, changes);
}

class DeleteCareItem {
  final CareItemRepository _repository;

  DeleteCareItem(this._repository);

  Future<void> call(String idToken, String id) =>
      _repository.delete(idToken, id);
}
