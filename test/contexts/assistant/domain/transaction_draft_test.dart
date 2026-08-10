import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/assistant/domain/transaction_draft.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';

// The fallback deliberately differs from every fixture `day` (and is not the
// real today): a normalization that quietly substitutes it — or one that
// reaches for the real clock — lands on a value no other fixture shares.
const _fallback = '2031-01-02';

AssistantProposal _proposal(Map<String, dynamic> fields) =>
    AssistantProposal(kind: 'create_transaction', fields: fields);

void main() {
  group('TransactionDraft.fromProposal', () {
    test('normalizes a full well-formed proposal, trimming and uppercasing', () {
      final draft = TransactionDraft.fromProposal(
        _proposal({
          'type': 'expense',
          'amount': 1234,
          'currency': ' usd ',
          'day': '2026-04-05',
          'category_name': ' 餐飲 ',
          'note': ' lunch ',
        }),
        fallbackDay: _fallback,
      );

      expect(draft, isNotNull);
      expect(draft!.type, FinanceType.expense);
      expect(draft.amount, 1234);
      expect(draft.currency, 'USD');
      expect(draft.day, '2026-04-05');
      expect(draft.categoryName, '餐飲');
      expect(draft.note, 'lunch');
    });

    test('missing currency falls back to TWD; empty string too', () {
      for (final fields in [
        {'type': 'income', 'amount': 500},
        {'type': 'income', 'amount': 500, 'currency': '  '},
      ]) {
        final draft = TransactionDraft.fromProposal(
          _proposal(fields),
          fallbackDay: _fallback,
        );
        expect(draft!.currency, 'TWD');
        expect(draft.type, FinanceType.income);
      }
    });

    test('absent or malformed day falls back to the caller\'s today', () {
      for (final day in [null, '2026/04/05', '04-05-2026', 'tomorrow', '']) {
        final draft = TransactionDraft.fromProposal(
          _proposal({
            'type': 'expense',
            'amount': 77,
            if (day != null) 'day': day,
          }),
          fallbackDay: _fallback,
        );
        expect(draft!.day, _fallback, reason: 'day fixture: $day');
      }
    });

    test('a rollover date like 2026-02-31 is malformed, not March 3rd', () {
      // DateTime.parse would silently turn this into 2026-03-03 — the
      // round-trip check must refuse it, or the card shows a date the model
      // never proposed.
      final draft = TransactionDraft.fromProposal(
        _proposal({'type': 'expense', 'amount': 88, 'day': '2026-02-31'}),
        fallbackDay: _fallback,
      );
      expect(draft!.day, _fallback);
    });

    test('non-positive or fractional amounts make the proposal unrenderable', () {
      for (final amount in [0, -50, 180.5, '180', null]) {
        final draft = TransactionDraft.fromProposal(
          _proposal({
            'type': 'expense',
            if (amount != null) 'amount': amount,
            'category_name': '餐飲',
          }),
          fallbackDay: _fallback,
        );
        expect(draft, isNull, reason: 'amount fixture: $amount');
      }
    });

    test('an integral double amount (JSON 180.0) is the integer 180', () {
      final draft = TransactionDraft.fromProposal(
        _proposal({'type': 'expense', 'amount': 180.0}),
        fallbackDay: _fallback,
      );
      expect(draft!.amount, 180);
    });

    test('an unknown type or kind is unrenderable', () {
      expect(
        TransactionDraft.fromProposal(
          _proposal({'type': 'transfer', 'amount': 99}),
          fallbackDay: _fallback,
        ),
        isNull,
      );
      expect(
        TransactionDraft.fromProposal(
          _proposal({'amount': 99}),
          fallbackDay: _fallback,
        ),
        isNull,
      );
      expect(
        TransactionDraft.fromProposal(
          const AssistantProposal(
            kind: 'delete_transaction',
            fields: {'type': 'expense', 'amount': 99},
          ),
          fallbackDay: _fallback,
        ),
        isNull,
      );
    });

    test('blank category name and note become null, not empty strings', () {
      final draft = TransactionDraft.fromProposal(
        _proposal({
          'type': 'expense',
          'amount': 42,
          'category_name': '   ',
          'note': '',
        }),
        fallbackDay: _fallback,
      );
      expect(draft!.categoryName, isNull);
      expect(draft.note, isNull);
    });
  });
}
