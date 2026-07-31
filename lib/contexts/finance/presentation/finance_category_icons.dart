import 'package:flutter/material.dart';

import '../domain/finance_category.dart';

/// Icon for the seeded default categories, keyed by name — the backend
/// always stores `icon: 'other'` for the defaults (design.md), so a
/// per-icon-field lookup would show the same generic icon for every
/// category. [category.icon] is tried second (for any category that does
/// carry a distinct icon value in the future), falling back to a generic
/// icon when neither matches.
IconData financeCategoryIcon(FinanceCategory category) {
  return _byName[category.name] ?? _byIconField[category.icon] ?? Icons.category;
}

const _byName = {
  '餐飲': Icons.restaurant,
  '交通': Icons.directions_bus,
  '購物': Icons.shopping_bag,
  '娛樂': Icons.movie,
  '居住': Icons.home,
  '醫療': Icons.local_hospital,
  '薪資': Icons.payments,
  '獎金': Icons.card_giftcard,
  '利息': Icons.percent,
};

const _byIconField = <String, IconData>{};
