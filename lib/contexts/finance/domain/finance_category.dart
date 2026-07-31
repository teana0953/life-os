import 'finance_type.dart';

/// A per-user finance category, as returned by `GET /api/finance/categories`.
/// The default set is seeded lazily by the backend on first fetch.
class FinanceCategory {
  final String id;
  final String name;
  final FinanceType type;
  final String icon;
  final int sortOrder;
  final bool archived;

  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.sortOrder,
    required this.archived,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      type: financeTypeFromJson(json['type'] as String),
      icon: json['icon'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
      archived: json['archived'] as bool,
    );
  }
}
