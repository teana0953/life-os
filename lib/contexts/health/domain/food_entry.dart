/// How a [FoodEntry] was logged.
enum FoodEntrySource { manual, aiPhoto, dict }

FoodEntrySource _sourceFromJson(String value) {
  switch (value) {
    case 'manual':
      return FoodEntrySource.manual;
    case 'ai_photo':
      return FoodEntrySource.aiPhoto;
    case 'dict':
      return FoodEntrySource.dict;
    default:
      return FoodEntrySource.manual;
  }
}

/// A logged food entry, as returned by the backend `/api/diet-entries`
/// endpoints.
class FoodEntry {
  final String id;
  final String day;
  final String meal;
  final String? name;
  final String? photoRef;
  final FoodEntrySource source;
  final bool unclassified;
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sugarG;
  final double fiberG;
  final double kcal;
  final double staple;
  final double meat;
  final double fruit;
  final double veg;

  /// When the food was eaten; user-settable, defaults to creation time.
  final DateTime eatenAt;

  /// System audit time; never user-settable.
  final DateTime loggedAt;

  const FoodEntry({
    required this.id,
    required this.day,
    required this.meal,
    required this.name,
    required this.photoRef,
    required this.source,
    required this.unclassified,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.sugarG,
    required this.fiberG,
    required this.kcal,
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
    required this.eatenAt,
    required this.loggedAt,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'] as String,
      day: json['day'] as String,
      meal: json['meal'] as String,
      name: json['name'] as String?,
      photoRef: json['photo_ref'] as String?,
      source: _sourceFromJson(json['source'] as String),
      unclassified: json['unclassified'] as bool,
      carbG: (json['carb_g'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      sugarG: (json['sugar_g'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
      staple: (json['staple'] as num).toDouble(),
      meat: (json['meat'] as num).toDouble(),
      fruit: (json['fruit'] as num).toDouble(),
      veg: (json['veg'] as num).toDouble(),
      eatenAt: DateTime.parse(json['eaten_at'] as String),
      loggedAt: DateTime.parse(json['logged_at'] as String),
    );
  }
}
