import 'finance_type.dart';

/// One currency's totals for a month — never converted or summed with other
/// currencies (design.md).
class CurrencyTotal {
  final String currency;
  final int expense;
  final int income;
  final int net;

  const CurrencyTotal({
    required this.currency,
    required this.expense,
    required this.income,
    required this.net,
  });

  factory CurrencyTotal.fromJson(Map<String, dynamic> json) {
    return CurrencyTotal(
      currency: json['currency'] as String,
      expense: (json['expense'] as num).toInt(),
      income: (json['income'] as num).toInt(),
      net: (json['net'] as num).toInt(),
    );
  }
}

/// One category's amount within a month, per currency.
class CategoryAmount {
  final String categoryId;
  final FinanceType type;
  final String currency;
  final int amount;

  const CategoryAmount({
    required this.categoryId,
    required this.type,
    required this.currency,
    required this.amount,
  });

  factory CategoryAmount.fromJson(Map<String, dynamic> json) {
    return CategoryAmount(
      categoryId: json['category_id'] as String,
      type: financeTypeFromJson(json['type'] as String),
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toInt(),
    );
  }
}

/// A month's aggregated totals and per-category breakdown, as returned by
/// `GET /api/finance/summary?month=YYYY-MM`.
class MonthlySummary {
  final String month;
  final List<CurrencyTotal> totals;
  final List<CategoryAmount> byCategory;

  const MonthlySummary({
    required this.month,
    required this.totals,
    required this.byCategory,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      month: json['month'] as String,
      totals: (json['totals'] as List)
          .map((e) => CurrencyTotal.fromJson(e as Map<String, dynamic>))
          .toList(),
      byCategory: (json['by_category'] as List)
          .map((e) => CategoryAmount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
