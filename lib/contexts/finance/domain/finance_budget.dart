/// A recurring monthly TWD budget (overall when [categoryId] is `null`,
/// otherwise scoped to that expense category), together with the selected
/// month's progress, as returned by `GET /api/finance/budgets?month=YYYY-MM`.
/// [percent] is the backend's rounded integer — the UI's three-tier color
/// judgement always uses this value, never a value recomputed from
/// [spent]/[amount] on the frontend (design.md: avoids a 79/80-boundary
/// mismatch with the backend's rounding).
class FinanceBudget {
  final String id;
  final String? categoryId;
  final int amount;
  final int spent;
  final int remaining;
  final int percent;

  const FinanceBudget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.percent,
  });

  factory FinanceBudget.fromJson(Map<String, dynamic> json) {
    return FinanceBudget(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num).toInt(),
      spent: (json['spent'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      percent: (json['percent'] as num).toInt(),
    );
  }
}
