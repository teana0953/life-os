import '../domain/medication_reminder.dart';

/// Thin use cases over [MedicationReminderRepository] — no validation or
/// orchestration beyond the pass-through; front-end validation lives in the
/// form (client-basic, server-authoritative per design D4).
class ListMedicationReminders {
  final MedicationReminderRepository _repository;

  ListMedicationReminders(this._repository);

  Future<List<MedicationReminder>> call(String idToken) =>
      _repository.list(idToken);
}

class CreateMedicationReminder {
  final MedicationReminderRepository _repository;

  CreateMedicationReminder(this._repository);

  Future<void> call(String idToken, MedicationReminderDraft draft) =>
      _repository.create(idToken, draft);
}

class UpdateMedicationReminder {
  final MedicationReminderRepository _repository;

  UpdateMedicationReminder(this._repository);

  Future<void> call(
    String idToken,
    String id,
    MedicationReminderUpdate changes,
  ) => _repository.update(idToken, id, changes);
}

class DeleteMedicationReminder {
  final MedicationReminderRepository _repository;

  DeleteMedicationReminder(this._repository);

  Future<void> call(String idToken, String id) =>
      _repository.delete(idToken, id);
}

class SetReminderTimezone {
  final MedicationReminderRepository _repository;

  SetReminderTimezone(this._repository);

  Future<void> call(String idToken, String timezone) =>
      _repository.setTimezone(idToken, timezone);
}
