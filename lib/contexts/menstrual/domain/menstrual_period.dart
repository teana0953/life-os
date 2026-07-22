/// Parses a date-only string (`YYYY-MM-DD`, or an ISO datetime) into a
/// [DateTime] stripped to its calendar date, so period ranges compare cleanly
/// against calendar days in the mini-calendar.
DateTime _parseDate(String value) {
  final parsed = DateTime.parse(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// A single recorded menstrual period (from `GET /api/menstrual`): a stable
/// [id], a [startDate] (date-only), and an optional [endDate] (`null` while the
/// period is still open / ongoing).
class MenstrualPeriod {
  final String id;
  final DateTime startDate;
  final DateTime? endDate;

  const MenstrualPeriod({
    required this.id,
    required this.startDate,
    this.endDate,
  });

  /// Whether the period has no recorded end date yet (ongoing).
  bool get isOpen => endDate == null;

  factory MenstrualPeriod.fromJson(Map<String, dynamic> json) => MenstrualPeriod(
    id: json['id'] as String,
    startDate: _parseDate(json['start_date'] as String),
    endDate: json['end_date'] == null
        ? null
        : _parseDate(json['end_date'] as String),
  );
}

/// Derived cycle statistics (from `GET /api/menstrual`). The stats object is
/// always present, but each field is independently `null` until there is enough
/// data to derive it.
class MenstrualStats {
  final int? averageCycleDays;
  final int? averagePeriodDays;
  final DateTime? predictedNextStart;

  const MenstrualStats({
    this.averageCycleDays,
    this.averagePeriodDays,
    this.predictedNextStart,
  });

  factory MenstrualStats.fromJson(Map<String, dynamic> json) => MenstrualStats(
    averageCycleDays: (json['average_cycle_days'] as num?)?.toInt(),
    averagePeriodDays: (json['average_period_days'] as num?)?.toInt(),
    predictedNextStart: json['predicted_next_start'] == null
        ? null
        : _parseDate(json['predicted_next_start'] as String),
  );
}

/// The whole menstrual overview (from `GET /api/menstrual`): the recorded
/// [periods], the derived [stats], and the [lastPeriod] (the most recent
/// period, `null` when none is recorded).
class MenstrualOverview {
  final List<MenstrualPeriod> periods;
  final MenstrualStats stats;
  final MenstrualPeriod? lastPeriod;

  const MenstrualOverview({
    required this.periods,
    required this.stats,
    this.lastPeriod,
  });

  factory MenstrualOverview.fromJson(Map<String, dynamic> json) =>
      MenstrualOverview(
        periods: [
          for (final p in (json['periods'] as List? ?? const []))
            MenstrualPeriod.fromJson(p as Map<String, dynamic>),
        ],
        stats: MenstrualStats.fromJson(
          (json['stats'] as Map<String, dynamic>? ?? const {}),
        ),
        lastPeriod: json['last_period'] == null
            ? null
            : MenstrualPeriod.fromJson(
                json['last_period'] as Map<String, dynamic>,
              ),
      );
}
