import 'portions.dart';

/// One item within a [MealEntry], as returned by the meals API — either a
/// day-view item (`GET /api/meals`) or a POST-response item. Only the fields
/// Today actually renders are parsed here: `id`, `name`, and `consumed`
/// (a [Portions] built from the item JSON's *nested* `consumed` object).
///
/// The item's own flat per-unit fields (`staple/meat/fruit/veg`,
/// `carb_g`…`kcal`, `quantity`, `base_grams`, `food_item_id`, `source`,
/// `unclassified`, `photo_ref`) are **not parsed this PR** — Today shows only
/// consumed portions and item editing is read-only here; PR③'s in-place
/// edit adds the per-unit + quantity + baseGrams fields it needs.
class MealItem {
  final String id;
  final String? name;
  final Portions consumed;

  const MealItem({required this.id, required this.name, required this.consumed});

  factory MealItem.fromJson(Map<String, dynamic> json) {
    final consumed = json['consumed'] as Map<String, dynamic>;
    return MealItem(
      id: json['id'] as String,
      name: json['name'] as String?,
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
