import 'transaction_draft.dart';

/// One turn of the conversation as `POST /api/assistant` understands it. The
/// backend requires a role of `user` or `assistant` and non-empty content —
/// callers must not put an empty-text turn on the wire.
class AssistantMessage {
  final String role;
  final String content;

  const AssistantMessage({required this.role, required this.content});
}

/// What one send comes back with: the assistant's prose and zero or more
/// transaction proposals. Proposals are **not** part of the message history
/// sent back on the next turn — the wire format is `{role, content}` only.
class AssistantReply {
  final String text;
  final List<AssistantProposal> proposals;

  const AssistantReply({required this.text, required this.proposals});
}
