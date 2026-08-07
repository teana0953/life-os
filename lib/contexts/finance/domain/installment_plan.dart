/// The two creation modes of an instalment plan (backend `mode` values
/// `"total"` | `"per_installment"`).
///
/// The distinction is not cosmetic: in [total] mode the plan's [InstallmentPlan.amount]
/// is the whole sum split across the periods, in [perInstallment] it is the
/// fixed per-period charge — and settling is computable by the system only
/// for [total] (the per-instalment payoff must come from the bank, because
/// remaining × per-period would wrongly include future interest).
enum InstallmentMode { total, perInstallment }

/// `mode` as the backend spells it (`installmentPlanToJson`).
String installmentModeToJson(InstallmentMode mode) =>
    mode == InstallmentMode.total ? 'total' : 'per_installment';

InstallmentMode installmentModeFromJson(String value) =>
    value == 'total' ? InstallmentMode.total : InstallmentMode.perInstallment;

/// One recurring-charge plan, as returned by
/// `/api/finance/installment-plans` (`installmentPlanToJson`): period count,
/// creation mode, and start month — what a client needs to render
/// "第 N 期 / 共 M 期" and to know whether settling should prompt for an
/// amount, on top of the `plan_id`/`installment_no` already on every
/// transaction.
class InstallmentPlan {
  final String id;
  final InstallmentMode mode;
  final int periods;

  /// `YYYY-MM-DD` (backend `start_day`).
  final String startDay;

  /// Minor units. The **total** sum for [InstallmentMode.total], the fixed
  /// **per-period** charge for [InstallmentMode.perInstallment].
  final int amount;
  final String currency;
  final String categoryId;
  final String? note;

  const InstallmentPlan({
    required this.id,
    required this.mode,
    required this.periods,
    required this.startDay,
    required this.amount,
    required this.currency,
    required this.categoryId,
    this.note,
  });

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) {
    return InstallmentPlan(
      id: json['id'] as String,
      mode: installmentModeFromJson(json['mode'] as String),
      periods: (json['periods'] as num).toInt(),
      startDay: json['start_day'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      categoryId: json['category_id'] as String,
      note: json['note'] as String?,
    );
  }
}
