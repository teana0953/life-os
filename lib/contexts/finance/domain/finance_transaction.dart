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

  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.date,
    this.note,
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
    );
  }
}
