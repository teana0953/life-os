import 'dart:async';

import 'package:life_os/contexts/assistant/domain/assistant_message.dart';
import 'package:life_os/contexts/assistant/domain/assistant_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';

import '../finance/finance_test_support.dart';

/// Records every send's message list (a defensive copy — the controller may
/// mutate its own list afterwards), replies with [reply], and throws
/// [failure] once when set. [gate] holds the request open so a test can
/// observe the in-flight state.
class RecordingAssistantRepository implements AssistantRepository {
  final List<List<AssistantMessage>> calls = [];

  /// The health consent each send carried, one entry per call and in the same
  /// order as [calls] — so a retry's value can be told apart from the
  /// original send's.
  final List<bool> healthFlags = [];

  AssistantReply reply = const AssistantReply(text: 'ok', proposals: []);
  Object? failure;
  Completer<void>? gate;

  @override
  Future<AssistantReply> send(
    String idToken, {
    required String geminiKey,
    required bool healthEnabled,
    required List<AssistantMessage> messages,
  }) async {
    calls.add(List.of(messages));
    healthFlags.add(healthEnabled);
    final held = gate;
    if (held != null) await held.future;
    final thrown = failure;
    if (thrown != null) {
      failure = null;
      throw thrown;
    }
    return reply;
  }
}

/// [FakeFinanceRepository] whose `addTransaction` counts calls and can be
/// held open with [addGate] — the double-tap guards need a save that is
/// still in flight when the second tap lands.
class GatedFinanceRepository extends FakeFinanceRepository {
  int addTransactionCalls = 0;
  Completer<void>? addGate;

  @override
  Future<FinanceTransaction> addTransaction(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) async {
    addTransactionCalls++;
    final held = addGate;
    if (held != null) await held.future;
    return super.addTransaction(
      idToken,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
  }
}
