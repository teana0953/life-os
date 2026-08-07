import 'finance_type.dart';

/// A single ledger entry, as returned by the `/api/finance/transactions`
/// endpoints. [amount] is the backend's minor-unit integer (TWD 元, USD
/// cents, ...) — see `finance_money.dart` for formatting/parsing against a
/// currency's decimal-digit convention. Category name/icon are not embedded
/// here; callers look the category up by [categoryId] in the loaded category
/// list.
class FinanceTransaction {
  final String id;
  final FinanceType type;
  final int amount;
  final String currency;
  final String categoryId;
  final String date;
  final String? note;

  /// Set when the server mirrored this row out of a split expense the user
  /// took a share of, `null` when the user recorded it themselves. The
  /// backend refuses writes that rewrite a mirror's split facts (amount,
  /// date, currency, type) and refuses to delete one at all, so this is not
  /// decoration — it is what the list and the edit sheet have to read to stop
  /// offering actions the server will reject with a 400.
  final String? splitExpenseId;

  /// Set when the server wrote this row as one period of an instalment plan
  /// (`plan_id`), `null` otherwise. **Independent of [splitExpenseId]** —
  /// the two are separate nullable columns with nothing forbidding their
  /// coexistence, and 分帳分期 (the known next step) will produce rows
  /// carrying both. No branch may treat them as exclusive.
  final String? planId;

  /// 1-based period number within the plan (`installment_no`); `null` off a
  /// plan.
  final int? installmentNo;

  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.date,
    this.note,
    this.splitExpenseId,
    this.planId,
    this.installmentNo,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      type: financeTypeFromJson(json['type'] as String),
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      categoryId: json['category_id'] as String,
      date: json['date'] as String,
      note: json['note'] as String?,
      splitExpenseId: json['split_expense_id'] as String?,
      planId: json['plan_id'] as String?,
      installmentNo: (json['installment_no'] as num?)?.toInt(),
    );
  }
}
