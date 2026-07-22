/// A single activity in the static, read-only exercise library (from
/// `GET /api/exercise/activities`): a stable [id], a [name] (backend data,
/// Chinese-labeled — not localized), a [category] (`'aerobic' | 'anaerobic'`),
/// and a descriptive [intensity] label (empty string when none).
class ExerciseActivity {
  final String id;
  final String name;
  final String category;
  final String intensity;

  const ExerciseActivity({
    required this.id,
    required this.name,
    required this.category,
    required this.intensity,
  });

  factory ExerciseActivity.fromJson(Map<String, dynamic> json) =>
      ExerciseActivity(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        intensity: (json['intensity'] as String?) ?? '',
      );
}

/// A single logged exercise entry for a day (from `GET /api/exercise?day=`,
/// already enriched with the referenced activity's name/category): a
/// [durationMinutes] (a positive whole number of minutes), an optional [note]
/// (empty when none), and a [createdAt] timestamp. [activityName] and
/// [category] are the enrich fields (`null` when not provided).
class ExerciseEntry {
  final String id;
  final String activityId;
  final String? activityName;
  final String? category;
  final int durationMinutes;
  final String note;
  final DateTime createdAt;

  const ExerciseEntry({
    required this.id,
    required this.activityId,
    required this.activityName,
    required this.category,
    required this.durationMinutes,
    required this.note,
    required this.createdAt,
  });

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
    id: json['id'] as String,
    activityId: json['activity_id'] as String,
    activityName: json['activity_name'] as String?,
    category: json['category'] as String?,
    durationMinutes: (json['duration_minutes'] as num).toInt(),
    note: (json['note'] as String?) ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// A day's exercise record (from `GET /api/exercise?day=`): the [day]'s
/// [entries] and their [totalMinutes].
class ExerciseDay {
  final String day;
  final List<ExerciseEntry> entries;
  final int totalMinutes;

  const ExerciseDay({
    required this.day,
    required this.entries,
    required this.totalMinutes,
  });

  factory ExerciseDay.fromJson(Map<String, dynamic> json) => ExerciseDay(
    day: json['day'] as String,
    entries: [
      for (final e in (json['entries'] as List? ?? const []))
        ExerciseEntry.fromJson(e as Map<String, dynamic>),
    ],
    totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
  );
}
