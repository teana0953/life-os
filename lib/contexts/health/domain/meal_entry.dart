import 'portions.dart';

/// One item within a [MealEntry], as returned by the meals API — either a
/// day-view item (`GET /api/meals`) or a POST/PATCH-response item
/// (`mealItemToJson` on the backend). Parses the fields Today needs to
/// display an amount and drive in-place editing: `id`, `foodItemId`,
/// `name`, `source`, `quantity`, the flat per-unit `staple/meat/fruit/veg`,
/// `baseAmount`, `measureUnit`, and the nested `consumed` (a [Portions]).
///
/// The response never carries a `measure` field or a separate `portions`
/// object — `measure` is request-only (the backend converts it to
/// `quantity` on write) and a manual item's portions live in the flat
/// per-unit fields at `quantity = 1` — so neither is parsed here.
class MealItem {
  final String id;
  final String? foodItemId;
  final String? name;
  final String source;
  final double quantity;
  final double staple;
  final double meat;
  final double fruit;
  final double veg;
  final double? baseAmount;
  final String? measureUnit;
  final Portions consumed;

  const MealItem({
    required this.id,
    required this.foodItemId,
    required this.name,
    required this.source,
    required this.quantity,
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
    required this.baseAmount,
    required this.measureUnit,
    required this.consumed,
  });

  /// A manually-entered item — recognised by `source == 'manual'` or a null
  /// [foodItemId] — is edited by sending `portions` (the four flat per-unit
  /// values above); a dictionary item is edited by sending `quantity` or
  /// `measure`.
  bool get isManual => source == 'manual' || foodItemId == null;

  factory MealItem.fromJson(Map<String, dynamic> json) {
    final consumed = json['consumed'] as Map<String, dynamic>;
    return MealItem(
      id: json['id'] as String,
      foodItemId: json['food_item_id'] as String?,
      name: json['name'] as String?,
      source: json['source'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      staple: (json['staple'] as num).toDouble(),
      meat: (json['meat'] as num).toDouble(),
      fruit: (json['fruit'] as num).toDouble(),
      veg: (json['veg'] as num).toDouble(),
      baseAmount: (json['base_amount'] as num?)?.toDouble(),
      measureUnit: json['measure_unit'] as String?,
      consumed: Portions(
        staple: (consumed['staple'] as num).toDouble(),
        meat: (consumed['meat'] as num).toDouble(),
        fruit: (consumed['fruit'] as num).toDouble(),
        veg: (consumed['veg'] as num).toDouble(),
      ),
    );
  }
}

/// One meal (a standard meal or a snack) with a single eaten-at `time`, as
/// returned by the meals API. Day-view meals (`GET /api/meals`) omit a
/// per-meal `day` (it's on the envelope); the POST response's meal carries
/// one, but no caller this PR needs it, so it is not modeled here.
class MealEntry {
  final String id;

  /// A standard-meal code (`breakfast`/`lunch`/`dinner`), or a snack's own
  /// display name (e.g. "點心2").
  final String meal;

  /// The meal's single eaten-at time, parsed as UTC.
  final DateTime time;
  final List<MealItem> items;

  const MealEntry({
    required this.id,
    required this.meal,
    required this.time,
    required this.items,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'] as String,
      meal: json['meal'] as String,
      time: DateTime.parse(json['time'] as String).toUtc(),
      items: (json['items'] as List)
          .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
