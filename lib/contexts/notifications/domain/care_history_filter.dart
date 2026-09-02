import 'care_history.dart';
import 'care_item.dart';
import 'care_today.dart';

/// Which slots of an already-loaded care-history range the screen shows.
/// Purely a client-side slice of what `/api/care/range` returned — changing
/// it never re-queries the backend (only the period does).
///
/// [categories] and [statuses] are multi-select, an empty set meaning "all"
/// (so the default, everything unselected, is also everything shown);
/// [careItemId] is single-select, `null` meaning all items. The three
/// dimensions narrow together: a slot is kept only if it satisfies all of
/// them.
class CareHistoryFilter {
  final Set<CareCategory> categories;
  final Set<CareTodayStatus> statuses;
  final String? careItemId;

  const CareHistoryFilter({
    this.categories = const {},
    this.statuses = const {},
    this.careItemId,
  });

  bool get isEmpty =>
      categories.isEmpty && statuses.isEmpty && careItemId == null;

  /// How many individual selections are active — the badge on the filter
  /// button, so the count matches the number of removable chips on screen.
  int get appliedCount =>
      categories.length + statuses.length + (careItemId == null ? 0 : 1);

  /// [clearCareItem] exists because passing `careItemId: null` is
  /// indistinguishable from omitting it — without the flag, choosing "all
  /// items" could not clear a previously picked one.
  CareHistoryFilter copyWith({
    Set<CareCategory>? categories,
    Set<CareTodayStatus>? statuses,
    String? careItemId,
    bool clearCareItem = false,
  }) => CareHistoryFilter(
    categories: categories ?? this.categories,
    statuses: statuses ?? this.statuses,
    careItemId: clearCareItem ? null : (careItemId ?? this.careItemId),
  );

  @override
  bool operator ==(Object other) =>
      other is CareHistoryFilter &&
      other.careItemId == careItemId &&
      other.categories.length == categories.length &&
      other.categories.containsAll(categories) &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses);

  @override
  int get hashCode => Object.hash(
    careItemId,
    // Order-independent, matching `==`: two filters holding the same
    // selections in different insertion orders are the same filter.
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(statuses),
  );
}

/// [days] with every slot that [filter] excludes removed.
///
/// Days are emptied, never dropped: `careHistoryIsEmpty`,
/// `careDayStateCounts` and `careDayState` all rest on the backend's
/// dense-days contract (one entry per calendar date), so a filtered range
/// has to stay dense for them to keep meaning what they mean.
List<CareHistoryDay> applyCareHistoryFilter(
  List<CareHistoryDay> days,
  CareHistoryFilter filter,
) {
  if (filter.isEmpty) return days;
  return [
    for (final day in days)
      CareHistoryDay(
        date: day.date,
        slots: [
          for (final slot in day.slots)
            if ((filter.categories.isEmpty ||
                    filter.categories.contains(slot.category)) &&
                (filter.statuses.isEmpty ||
                    filter.statuses.contains(slot.status)) &&
                (filter.careItemId == null ||
                    filter.careItemId == slot.careItemId))
              slot,
        ],
      ),
  ];
}

/// The care items that actually occur in [days], deduplicated and sorted by
/// title — the options offered by the filter sheet's item picker. Derived
/// from the loaded range rather than from the care-items list so the picker
/// can never offer an item the current period has no records for.
List<({String id, String title})> careHistoryItemOptions(
  List<CareHistoryDay> days,
) {
  final titles = <String, String>{};
  for (final day in days) {
    for (final slot in day.slots) {
      final itemId = slot.careItemId;
      if (itemId != null) titles.putIfAbsent(itemId, () => slot.title);
    }
  }
  final options = [
    for (final entry in titles.entries) (id: entry.key, title: entry.value),
  ]..sort((a, b) => a.title.compareTo(b.title));
  return options;
}
