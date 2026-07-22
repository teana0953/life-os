/// A day's bowel record, as returned by `GET /api/bowel?day=`: the number of
/// bowel movements, whether the day was normal ([isNormal] is `bool?` — `null`
/// means not recorded, not "normal"), and a free-text [note].
class BowelDay {
  final String day;
  final int count;
  final bool? isNormal;
  final String note;

  const BowelDay({
    required this.day,
    required this.count,
    required this.isNormal,
    required this.note,
  });

  factory BowelDay.fromJson(Map<String, dynamic> json) {
    return BowelDay(
      day: json['day'] as String,
      count: (json['count'] as num).toInt(),
      isNormal: json['is_normal'] as bool?,
      note: (json['note'] as String?) ?? '',
    );
  }
}
