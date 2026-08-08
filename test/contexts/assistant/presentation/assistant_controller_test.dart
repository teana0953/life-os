import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/assistant/application/send_assistant_message.dart';
import 'package:life_os/contexts/assistant/domain/assistant_failure.dart';
import 'package:life_os/contexts/assistant/domain/assistant_message.dart';
import 'package:life_os/contexts/assistant/domain/transaction_draft.dart';
import 'package:life_os/contexts/assistant/presentation/assistant_controller.dart';
import 'package:life_os/contexts/finance/application/add_transaction.dart';
import 'package:life_os/contexts/finance/application/list_finance_categories.dart';
import 'package:life_os/contexts/finance/domain/finance_category.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';

import '../assistant_test_support.dart';

// Pinned WELL AWAY from the real today: any code path that reaches for the
// real clock instead of the injected one lands on a different date and turns
// the day assertions red.
final _now = DateTime(2031, 3, 15, 9, 30);

AssistantController _controller(
  RecordingAssistantRepository assistantRepository,
  GatedFinanceRepository financeRepository,
) {
  return AssistantController(
    SendAssistantMessage(assistantRepository),
    AddTransaction(financeRepository),
    ListFinanceCategories(financeRepository),
    clock: () => _now,
  );
}

AssistantProposal _foodProposal({int amount = 1234}) => AssistantProposal(
  kind: 'create_transaction',
  // Deliberately no `currency` and no `day`: normalization must fill both,
  // and rendering/writing must agree on the filled values.
  fields: {'type': 'expense', 'amount': amount, 'category_name': '餐飲'},
);

void main() {
  group('AssistantController.send', () {
    test('sends the WHOLE history: roles and contents, in order', () async {
      final repo = RecordingAssistantRepository()
        ..reply = const AssistantReply(text: '共 3,600 元。', proposals: []);
      final controller = _controller(repo, GatedFinanceRepository());

      await controller.send('tok', 'key', '這個月吃飯花多少?');
      await controller.send('tok', 'key', '那交通呢?');

      final second = repo.calls[1];
      expect(second.map((m) => m.role).toList(), ['user', 'assistant', 'user']);
      expect(second.map((m) => m.content).toList(), [
        '這個月吃飯花多少?',
        '共 3,600 元。',
        '那交通呢?',
      ]);
    });

    test('proposals never leak into the wire history; empty assistant text '
        'is skipped entirely (the backend rejects empty content)', () async {
      final repo = RecordingAssistantRepository()
        ..reply = AssistantReply(text: '', proposals: [_foodProposal()]);
      final controller = _controller(repo, GatedFinanceRepository());

      await controller.send('tok', 'key', '幫我記 1234 元餐飲');
      repo.reply = const AssistantReply(text: 'ok', proposals: []);
      await controller.send('tok', 'key', '好');

      final second = repo.calls[1];
      // Not [user, assistant(''), user]: the empty-text turn is dropped.
      expect(second.map((m) => m.role).toList(), ['user', 'user']);
      for (final message in second) {
        expect(message.content.trim(), isNotEmpty);
        expect(message.content, isNot(contains('1234 TWD')));
      }
    });

    test('a failed send keeps the user entry and surfaces the typed failure', () async {
      final repo = RecordingAssistantRepository()
        ..failure = const AssistantSendFailure(AssistantFailure.quotaExhausted);
      final controller = _controller(repo, GatedFinanceRepository());

      await controller.send('tok', 'key', 'hello');

      expect(controller.lastError, AssistantFailure.quotaExhausted);
      expect(controller.entries.single.role, 'user');
      expect(controller.status, AssistantStatus.idle);
    });

    test('retryLast re-sends the SAME history — no duplicated user entry', () async {
      final repo = RecordingAssistantRepository()
        ..failure =
            const AssistantSendFailure(AssistantFailure.serviceUnavailable);
      final controller = _controller(repo, GatedFinanceRepository());

      await controller.send('tok', 'key', 'hello');
      expect(controller.lastError, AssistantFailure.serviceUnavailable);

      await controller.retryLast('tok', 'key');

      expect(controller.entries.where((e) => e.role == 'user').length, 1);
      expect(repo.calls, hasLength(2));
      expect(
        repo.calls[1].map((m) => '${m.role}:${m.content}').toList(),
        repo.calls[0].map((m) => '${m.role}:${m.content}').toList(),
      );
      expect(controller.lastError, isNull);
    });

    test('401 flips needsReauth instead of an error row', () async {
      final repo = RecordingAssistantRepository()
        ..failure = const AssistantReauthRequired();
      final controller = _controller(repo, GatedFinanceRepository());

      await controller.send('tok', 'key', 'hello');

      expect(controller.needsReauth, isTrue);
      expect(controller.lastError, isNull);
    });

    test('a second send while one is in flight is dropped, not queued', () async {
      final repo = RecordingAssistantRepository()..gate = Completer<void>();
      final controller = _controller(repo, GatedFinanceRepository());

      final first = controller.send('tok', 'key', 'first');
      final second = controller.send('tok', 'key', 'second');
      repo.gate!.complete();
      await first;
      await second;

      expect(repo.calls, hasLength(1));
      expect(controller.entries.where((e) => e.role == 'user').length, 1);
    });
  });

  group('AssistantController.accept', () {
    Future<AssistantController> sendOneProposal(
      RecordingAssistantRepository repo,
      GatedFinanceRepository finance,
    ) async {
      repo.reply = AssistantReply(text: '要記下這筆嗎?', proposals: [_foodProposal()]);
      final controller = _controller(repo, finance);
      await controller.send('tok', 'key', '幫我記帳');
      return controller;
    }

    test('saves the card\'s own draft: normalized currency, normalized day, '
        'resolved category id', () async {
      final finance = GatedFinanceRepository();
      final controller =
          await sendOneProposal(RecordingAssistantRepository(), finance);

      await controller.accept('tok', 1, 0);

      final saved = finance.byMonth['2031-03']!.single;
      expect(saved.amount, 1234);
      expect(saved.currency, 'TWD'); // filled by the draft, not by AddTransactionSheet
      expect(saved.date, '2031-03-15'); // the injected clock's today
      expect(saved.categoryId, 'cat-food'); // resolved from name 餐飲
      expect(saved.type, FinanceType.expense);
      expect(controller.entries[1].proposals.single.status, ProposalStatus.saved);
    });

    test('category match is case-insensitive and exact', () async {
      final finance = GatedFinanceRepository()
        ..categoriesToReturn = const [
          FinanceCategory(
            id: 'cat-dining',
            name: 'Dining',
            type: FinanceType.expense,
            icon: 'other',
            sortOrder: 0,
            archived: false,
          ),
        ];
      final repo = RecordingAssistantRepository()
        ..reply = const AssistantReply(
          text: 'ok',
          proposals: [
            AssistantProposal(
              kind: 'create_transaction',
              fields: {'type': 'expense', 'amount': 55, 'category_name': 'dining'},
            ),
          ],
        );
      final controller = _controller(repo, finance);
      await controller.send('tok', 'key', 'hi');

      await controller.accept('tok', 1, 0);

      expect(finance.byMonth['2031-03']!.single.categoryId, 'cat-dining');
    });

    test('a same-named category of the WRONG TYPE does not match', () async {
      // 薪資 exists — as income. An expense proposal naming it must dead-end,
      // not write an expense into an income category.
      final finance = GatedFinanceRepository();
      final repo = RecordingAssistantRepository()
        ..reply = const AssistantReply(
          text: 'ok',
          proposals: [
            AssistantProposal(
              kind: 'create_transaction',
              fields: {'type': 'expense', 'amount': 55, 'category_name': '薪資'},
            ),
          ],
        );
      final controller = _controller(repo, finance);
      await controller.send('tok', 'key', 'hi');

      await controller.accept('tok', 1, 0);

      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.categoryNotFound,
      );
      expect(finance.addTransactionCalls, 0);
    });

    test('an archived category does not match', () async {
      final finance = GatedFinanceRepository()
        ..categoriesToReturn = const [
          FinanceCategory(
            id: 'cat-food-archived',
            name: '餐飲',
            type: FinanceType.expense,
            icon: 'other',
            sortOrder: 0,
            archived: true,
          ),
        ];
      final controller =
          await sendOneProposal(RecordingAssistantRepository(), finance);

      await controller.accept('tok', 1, 0);

      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.categoryNotFound,
      );
      expect(finance.addTransactionCalls, 0);
    });

    test('a failed save re-arms the card; accepting again succeeds', () async {
      final finance = GatedFinanceRepository()
        ..failNext = const FinanceFetchFailure('boom');
      final controller =
          await sendOneProposal(RecordingAssistantRepository(), finance);

      await controller.accept('tok', 1, 0);
      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.failed,
      );

      await controller.accept('tok', 1, 0);
      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.saved,
      );
      expect(finance.byMonth['2031-03']!.single.amount, 1234);
    });

    test('a 401 on accept flips needsReauth and leaves the card pending', () async {
      final finance = GatedFinanceRepository()
        ..failNext = const FinanceReauthenticationRequired();
      final controller =
          await sendOneProposal(RecordingAssistantRepository(), finance);

      await controller.accept('tok', 1, 0);

      expect(controller.needsReauth, isTrue);
      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.pending,
      );
    });

    test('the same card can NEVER record twice: not concurrently, not after '
        'saved', () async {
      final finance = GatedFinanceRepository()..addGate = Completer<void>();
      final controller =
          await sendOneProposal(RecordingAssistantRepository(), finance);

      // Two accepts while the first save is still in flight.
      final first = controller.accept('tok', 1, 0);
      final second = controller.accept('tok', 1, 0);
      finance.addGate!.complete();
      await first;
      await second;
      expect(finance.addTransactionCalls, 1);
      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.saved,
      );

      // And a direct call on the saved card — the UI's missing button is not
      // the only lock.
      finance.addGate = null;
      await controller.accept('tok', 1, 0);
      expect(finance.addTransactionCalls, 1);
    });

    test('an unrenderable proposal (no draft) cannot be accepted at all', () async {
      final finance = GatedFinanceRepository();
      final repo = RecordingAssistantRepository()
        ..reply = const AssistantReply(
          text: 'ok',
          proposals: [
            AssistantProposal(
              kind: 'create_transaction',
              fields: {'type': 'expense', 'amount': 0, 'category_name': '餐飲'},
            ),
          ],
        );
      final controller = _controller(repo, finance);
      await controller.send('tok', 'key', 'hi');
      expect(controller.entries[1].proposals.single.draft, isNull);

      await controller.accept('tok', 1, 0);

      expect(finance.addTransactionCalls, 0);
      expect(
        controller.entries[1].proposals.single.status,
        ProposalStatus.pending,
      );
    });
  });

  group('AssistantController.reset', () {
    test('clears entries, error, and reauth — the sign-out contract', () async {
      final repo = RecordingAssistantRepository()
        ..reply = AssistantReply(text: 'secret answer', proposals: [_foodProposal()]);
      final controller = _controller(repo, GatedFinanceRepository());
      await controller.send('tok', 'key', 'my finances?');
      repo.failure = const AssistantSendFailure(AssistantFailure.keyRejected);
      await controller.send('tok', 'key', 'again');
      expect(controller.entries, isNotEmpty);
      expect(controller.lastError, isNotNull);

      controller.reset();

      expect(controller.entries, isEmpty);
      expect(controller.lastError, isNull);
      expect(controller.needsReauth, isFalse);
      expect(controller.status, AssistantStatus.idle);
    });
  });
}
