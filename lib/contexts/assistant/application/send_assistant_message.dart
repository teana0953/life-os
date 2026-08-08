import '../domain/assistant_message.dart';
import '../domain/assistant_repository.dart';

/// Use case: run the conversation-so-far through the assistant and get the
/// next reply. Thin by design (house style, same as `AddTransaction`).
class SendAssistantMessage {
  final AssistantRepository _repository;

  SendAssistantMessage(this._repository);

  Future<AssistantReply> call(
    String idToken, {
    required String geminiKey,
    required List<AssistantMessage> messages,
  }) {
    return _repository.send(idToken, geminiKey: geminiKey, messages: messages);
  }
}
