import '../../finance/domain/finance_type.dart';

/// One proposal as the backend returned it: a `kind` and the loose `fields`
/// the model produced. The backend passes these through **unvalidated**
/// (`fields: Record<string, unknown>`), so nothing here may be trusted until
/// [TransactionDraft.fromProposal] has normalized it.
class AssistantProposal {
  final String kind;
  final Map<String, dynamic> fields;

  const AssistantProposal({required this.kind, required this.fields});
}

/// The **single** normalization point from a loose [AssistantProposal] to the
/// strongly-typed values the confirmation card renders and `AddTransaction`
/// saves. Both sides read this same object — normalizing twice (once to
/// display, once to write) is exactly how "the screen shows A, the data says
/// B" bugs are born, so no other code may interpret `fields`.
class TransactionDraft {
  final FinanceType type;

  /// Minor units, always a positive integer (a proposal whose amount is not
  /// one never becomes a draft).
  final int amount;

  /// Uppercased ISO code; `'TWD'` when the proposal named none (the record
  /// sheet's own default).
  final String currency;

  /// A canonical `YYYY-MM-DD`; the caller's "today" when the proposal's day
  /// was absent or malformed.
  final String day;

  /// The category **name** the model proposed (categories are resolved to an
  /// id only at accept time, against the user's live list) — `null` when the
  /// proposal named none, which can never be accepted.
  final String? categoryName;

  final String? note;

  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.currency,
    required this.day,
    required this.categoryName,
    required this.note,
  });

  /// Normalizes [proposal] into a draft, or returns `null` when the proposal
  /// cannot be rendered honestly:
  ///
  /// - a `kind` this app doesn't know;
  /// - a `type` that is neither `expense` nor `income`;
  /// - an `amount` that is not a positive integer (a blank or fractional
  ///   amount rendered on a card the user can accept would write a number
  ///   they never saw).
  ///
  /// Recoverable gaps degrade instead of failing: no currency → TWD, absent
  /// or malformed `day` → [fallbackDay] (the caller's today), absent
  /// `category_name`/`note` → `null`.
  static TransactionDraft? fromProposal(
    AssistantProposal proposal, {
    required String fallbackDay,
  }) {
    if (proposal.kind != 'create_transaction') return null;
    final fields = proposal.fields;

    final FinanceType type;
    switch (fields['type']) {
      case 'expense':
        type = FinanceType.expense;
      case 'income':
        type = FinanceType.income;
      default:
        return null;
    }

    final rawAmount = fields['amount'];
    final int amount;
    if (rawAmount is int) {
      amount = rawAmount;
    } else if (rawAmount is double && rawAmount == rawAmount.truncateToDouble()) {
      // JSON gives `180.0` for a model that emitted a float — same value,
      // different lexeme. A true fraction (180.5) stays unrenderable.
      amount = rawAmount.truncate();
    } else {
      return null;
    }
    if (amount <= 0) return null;

    final rawCurrency = fields['currency'];
    final currency = rawCurrency is String && rawCurrency.trim().isNotEmpty
        ? rawCurrency.trim().toUpperCase()
        : 'TWD';

    final rawDay = fields['day'];
    final day = rawDay is String && _isCanonicalDay(rawDay) ? rawDay : fallbackDay;

    return TransactionDraft(
      type: type,
      amount: amount,
      currency: currency,
      day: day,
      categoryName: _trimmedOrNull(fields['category_name']),
      note: _trimmedOrNull(fields['note']),
    );
  }

  static String? _trimmedOrNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// `true` only for a real, canonically-formatted `YYYY-MM-DD` calendar
  /// date. The round-trip re-format matters: [DateTime] silently *rolls
  /// over* out-of-range components (`2026-02-31` → March 3rd), which a
  /// shape-only check would wave through and file the record under a date
  /// the user never saw. (Local mirror of `shared/date`'s
  /// `tryParseDayString`, which lives in a Flutter file this domain layer
  /// must not import.)
  static bool _isCanonicalDay(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final dayOfMonth = int.tryParse(parts[2]);
    if (year == null || month == null || dayOfMonth == null) return false;
    final date = DateTime(year, month, dayOfMonth);
    final canonical =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return canonical == s;
  }
}
