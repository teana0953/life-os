/// A single blood-pressure reading: [systolic]/[diastolic] with an optional
/// [pulse] ([pulse] is `int?` — `null` means not recorded). Value type
/// (`==`/`hashCode`) so drafts can be compared element-wise against the loaded
/// day (see `VitalsController.hasUnsavedChanges`).
class BpReading {
  final int systolic;
  final int diastolic;
  final int? pulse;

  /// When the reading was taken, as a strict "HH:mm" (24h) string. Required by
  /// the backend; may be `''` when tolerantly parsed from a pre-time record.
  final String time;

  const BpReading({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.time,
  });

  factory BpReading.fromJson(Map<String, dynamic> json) => BpReading(
    systolic: (json['systolic'] as num).toInt(),
    diastolic: (json['diastolic'] as num).toInt(),
    pulse: (json['pulse'] as num?)?.toInt(),
    time: (json['time'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
    'time': time,
  };

  BpReading copyWith({
    int? systolic,
    int? diastolic,
    Object? pulse = _unset,
    String? time,
  }) => BpReading(
    systolic: systolic ?? this.systolic,
    diastolic: diastolic ?? this.diastolic,
    pulse: pulse == _unset ? this.pulse : pulse as int?,
    time: time ?? this.time,
  );

  @override
  bool operator ==(Object other) =>
      other is BpReading &&
      other.systolic == systolic &&
      other.diastolic == diastolic &&
      other.pulse == pulse &&
      other.time == time;

  @override
  int get hashCode => Object.hash(systolic, diastolic, pulse, time);
}

/// When a glucose reading was taken relative to eating. Mirrors the backend's
/// snake_case wire values (`fasting` / `pre_meal` / `post_meal`).
enum GlucoseMealContext {
  fasting('fasting'),
  preMeal('pre_meal'),
  postMeal('post_meal');

  const GlucoseMealContext(this.wire);

  /// The backend's snake_case value for this context.
  final String wire;

  /// The context for a wire value, or null when absent/unrecognized.
  static GlucoseMealContext? fromWire(Object? wire) => switch (wire) {
    'fasting' => GlucoseMealContext.fasting,
    'pre_meal' => GlucoseMealContext.preMeal,
    'post_meal' => GlucoseMealContext.postMeal,
    _ => null,
  };
}

/// Sentinel so [GlucoseReading.copyWith] can tell "leave mealContext unchanged"
/// apart from "clear it to null".
const Object _unsetMealContext = Object();

/// A single blood-glucose reading: an optional free-text [label], a numeric
/// [value] (mg/dL), and an optional [mealContext] (空腹/餐前/餐後). Value type for
/// element-wise draft comparison.
class GlucoseReading {
  final String label;
  final num value;

  /// The reading's meal context, or null when unspecified.
  final GlucoseMealContext? mealContext;

  /// When the reading was taken, as a strict "HH:mm" (24h) string. Required by
  /// the backend; may be `''` when tolerantly parsed from a pre-time record.
  final String time;

  const GlucoseReading({
    required this.label,
    required this.value,
    required this.mealContext,
    required this.time,
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> json) => GlucoseReading(
    label: (json['label'] as String?) ?? '',
    value: json['value'] as num,
    mealContext: GlucoseMealContext.fromWire(json['meal_context']),
    time: (json['time'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'meal_context': mealContext?.wire,
    'time': time,
  };

  GlucoseReading copyWith({
    String? label,
    num? value,
    Object? mealContext = _unsetMealContext,
    String? time,
  }) => GlucoseReading(
    label: label ?? this.label,
    value: value ?? this.value,
    mealContext: identical(mealContext, _unsetMealContext)
        ? this.mealContext
        : mealContext as GlucoseMealContext?,
    time: time ?? this.time,
  );

  @override
  bool operator ==(Object other) =>
      other is GlucoseReading &&
      other.label == label &&
      other.value == value &&
      other.mealContext == mealContext &&
      other.time == time;

  @override
  int get hashCode => Object.hash(label, value, mealContext, time);
}

/// A single blood-oxygen reading: [spo2] percentage with an optional [pulse]
/// ([pulse] is `int?` — `null` means not recorded). Value type for element-wise
/// draft comparison.
class Spo2Reading {
  final num spo2;
  final int? pulse;

  /// When the reading was taken, as a strict "HH:mm" (24h) string. Required by
  /// the backend; may be `''` when tolerantly parsed from a pre-time record.
  final String time;

  const Spo2Reading({
    required this.spo2,
    required this.pulse,
    required this.time,
  });

  factory Spo2Reading.fromJson(Map<String, dynamic> json) => Spo2Reading(
    spo2: json['spo2'] as num,
    pulse: (json['pulse'] as num?)?.toInt(),
    time: (json['time'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {'spo2': spo2, 'pulse': pulse, 'time': time};

  Spo2Reading copyWith({num? spo2, Object? pulse = _unset, String? time}) =>
      Spo2Reading(
        spo2: spo2 ?? this.spo2,
        pulse: pulse == _unset ? this.pulse : pulse as int?,
        time: time ?? this.time,
      );

  @override
  bool operator ==(Object other) =>
      other is Spo2Reading &&
      other.spo2 == spo2 &&
      other.pulse == pulse &&
      other.time == time;

  @override
  int get hashCode => Object.hash(spo2, pulse, time);
}

/// Sentinel distinguishing "argument omitted" from an explicit `null` in the
/// `copyWith` methods above (so a nullable field can be cleared to `null`).
const Object _unset = Object();

/// A day's health-vitals record, as returned by `GET /api/vitals?day=`: an
/// optional [weightKg] and [bodyFatPct] (each `null` == not recorded, not 0),
/// and three reading lists (blood pressure, blood glucose, blood oxygen).
class VitalsDay {
  final String day;
  final num? weightKg;
  final num? bodyFatPct;
  final List<BpReading> bpReadings;
  final List<GlucoseReading> glucoseReadings;
  final List<Spo2Reading> spo2Readings;

  const VitalsDay({
    required this.day,
    required this.weightKg,
    required this.bodyFatPct,
    required this.bpReadings,
    required this.glucoseReadings,
    required this.spo2Readings,
  });

  factory VitalsDay.fromJson(Map<String, dynamic> json) => VitalsDay(
    day: json['day'] as String,
    weightKg: json['weight_kg'] as num?,
    bodyFatPct: json['body_fat_pct'] as num?,
    bpReadings: [
      for (final r in (json['bp_readings'] as List? ?? const []))
        BpReading.fromJson(r as Map<String, dynamic>),
    ],
    glucoseReadings: [
      for (final r in (json['glucose_readings'] as List? ?? const []))
        GlucoseReading.fromJson(r as Map<String, dynamic>),
    ],
    spo2Readings: [
      for (final r in (json['spo2_readings'] as List? ?? const []))
        Spo2Reading.fromJson(r as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'weight_kg': weightKg,
    'body_fat_pct': bodyFatPct,
    'bp_readings': [for (final r in bpReadings) r.toJson()],
    'glucose_readings': [for (final r in glucoseReadings) r.toJson()],
    'spo2_readings': [for (final r in spo2Readings) r.toJson()],
  };
}
