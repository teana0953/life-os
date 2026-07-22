/// A single blood-pressure reading: [systolic]/[diastolic] with an optional
/// [pulse] ([pulse] is `int?` — `null` means not recorded). Value type
/// (`==`/`hashCode`) so drafts can be compared element-wise against the loaded
/// day (see `VitalsController.hasUnsavedChanges`).
class BpReading {
  final int systolic;
  final int diastolic;
  final int? pulse;

  const BpReading({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
  });

  factory BpReading.fromJson(Map<String, dynamic> json) => BpReading(
    systolic: (json['systolic'] as num).toInt(),
    diastolic: (json['diastolic'] as num).toInt(),
    pulse: (json['pulse'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
  };

  BpReading copyWith({int? systolic, int? diastolic, Object? pulse = _unset}) =>
      BpReading(
        systolic: systolic ?? this.systolic,
        diastolic: diastolic ?? this.diastolic,
        pulse: pulse == _unset ? this.pulse : pulse as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is BpReading &&
      other.systolic == systolic &&
      other.diastolic == diastolic &&
      other.pulse == pulse;

  @override
  int get hashCode => Object.hash(systolic, diastolic, pulse);
}

/// A single blood-glucose reading: a [label] (e.g. "餐前"/"餐後" or free text)
/// and a numeric [value] (mg/dL). Value type for element-wise draft comparison.
class GlucoseReading {
  final String label;
  final num value;

  const GlucoseReading({required this.label, required this.value});

  factory GlucoseReading.fromJson(Map<String, dynamic> json) => GlucoseReading(
    label: (json['label'] as String?) ?? '',
    value: json['value'] as num,
  );

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  GlucoseReading copyWith({String? label, num? value}) => GlucoseReading(
    label: label ?? this.label,
    value: value ?? this.value,
  );

  @override
  bool operator ==(Object other) =>
      other is GlucoseReading && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}

/// A single blood-oxygen reading: [spo2] percentage with an optional [pulse]
/// ([pulse] is `int?` — `null` means not recorded). Value type for element-wise
/// draft comparison.
class Spo2Reading {
  final num spo2;
  final int? pulse;

  const Spo2Reading({required this.spo2, required this.pulse});

  factory Spo2Reading.fromJson(Map<String, dynamic> json) => Spo2Reading(
    spo2: json['spo2'] as num,
    pulse: (json['pulse'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {'spo2': spo2, 'pulse': pulse};

  Spo2Reading copyWith({num? spo2, Object? pulse = _unset}) => Spo2Reading(
    spo2: spo2 ?? this.spo2,
    pulse: pulse == _unset ? this.pulse : pulse as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is Spo2Reading && other.spo2 == spo2 && other.pulse == pulse;

  @override
  int get hashCode => Object.hash(spo2, pulse);
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
