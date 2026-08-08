import 'split_exceptions.dart';

/// What happened, one value per write use case in the split context
/// (backend `src/contexts/split/domain/split-activity.ts`). Eight of them,
/// plus [unknown]: a timeline that records only some changes is worse than
/// none, because the reader believes they saw everything.
enum SplitActivityType {
  expenseCreated,
  expenseUpdated,
  expenseDeleted,
  settlementCreated,
  settlementDeleted,
  groupCreated,
  groupMemberAdded,
  groupArchived,

  /// A `type` this build does not know. **Not** a wire value: the backend
  /// ships independently of this app (that is this change's premise), so a
  /// ninth write use case reaches an old client as a string nothing here
  /// maps. Rejecting the row would take the whole page down with it — and
  /// with it every entry the reader could have read — so an unrecognised
  /// type degrades to "something changed" instead: the timeline stays
  /// complete in count, honest about what it cannot name, and pages on.
  unknown,
}

const _wireTypes = <String, SplitActivityType>{
  'expense_created': SplitActivityType.expenseCreated,
  'expense_updated': SplitActivityType.expenseUpdated,
  'expense_deleted': SplitActivityType.expenseDeleted,
  'settlement_created': SplitActivityType.settlementCreated,
  'settlement_deleted': SplitActivityType.settlementDeleted,
  'group_created': SplitActivityType.groupCreated,
  'group_member_added': SplitActivityType.groupMemberAdded,
  'group_archived': SplitActivityType.groupArchived,
};

/// One entry in the split change log (`GET /api/split/activity`).
///
/// It carries its own copy of what it takes to render it, because the record
/// it describes may be gone — a deleted expense's amount and description live
/// here and nowhere else.
class SplitActivity {
  final String id;
  final SplitActivityType type;
  final String actorUserId;

  /// **Not nullable, and not necessarily a name.** The backend fills it with
  /// the actor's raw user id when there is no display name or email
  /// (`drizzle-split-activity-repository.ts`), so `?? something` is a guard
  /// that can never fire. The test for "no name" is
  /// `actorDisplayName == actorUserId` — see `SplitActivityRow`.
  final String actorDisplayName;

  final String? groupId;
  final String? groupName;

  /// The expense/settlement/group this is about. May name a row that no
  /// longer exists, which is why nothing in the change log is tappable.
  final String? subjectId;

  final String? counterpartUserId;

  /// Genuinely nullable, unlike [actorDisplayName] — `?? splitUnknownMember`
  /// is the right fallback here.
  final String? counterpartDisplayName;

  final int? amount;

  /// The amount before an edit. Written by **every** `expense_updated`
  /// entry, whether or not the amount moved — it is *not* a "the amount
  /// changed" flag. Rendering the before→after arrow on `!= null` produces
  /// "$2000 → $2000"; the test is `previousAmount != amount`.
  final int? previousAmount;

  /// What an `expense_updated` edit touched, from the backend's fixed
  /// vocabulary (`amount`, `currency`, `description`, `day`, `payer`,
  /// `shares`). `null` on every other type — and on **any** entry written
  /// before the backend recorded this at all, which is why the parse treats a
  /// missing key as null rather than as a broken response.
  ///
  /// An **empty** list is a real answer: the update endpoint replaces the
  /// whole record, so a client re-sending identical values is ordinary, and
  /// "this edit changed nothing" is a different statement from "this is not
  /// an edit". Collapsing the two loses the only thing that tells them apart.
  final List<String>? changedFields;

  /// Who joined and who left the split, as the names they had at the time —
  /// names, not ids, because the entry has to stay readable after the expense
  /// it describes is gone. Being dropped from a split moves what you owe, and
  /// this is the only place the timeline says it happened.
  final List<String>? addedDisplayNames;
  final List<String>? removedDisplayNames;

  /// A repayment's direction **relative to the actor**: `true` = the actor
  /// paid the counterpart. `null` on every non-settlement type. Turning this
  /// into "who paid whom" for a given reader is
  /// `resolveRepaymentDirection`'s job, not a widget's.
  final bool? actorIsPayer;

  final String? currency;
  final String? description;

  /// ISO-8601 instant, kept as the wire string (the repo's convention —
  /// `SplitExpense.createdAt`); parsed for display by `parseInstant`.
  final String createdAt;

  const SplitActivity({
    required this.id,
    required this.type,
    required this.actorUserId,
    required this.actorDisplayName,
    required this.groupId,
    required this.groupName,
    required this.subjectId,
    required this.counterpartUserId,
    required this.counterpartDisplayName,
    required this.amount,
    required this.previousAmount,
    this.changedFields,
    this.addedDisplayNames,
    this.removedDisplayNames,
    required this.actorIsPayer,
    required this.currency,
    required this.description,
    required this.createdAt,
  });

  /// Throws [SplitFetchFailure] for a missing or wrong-typed field, rather
  /// than letting a cast error escape — the convention every other entity in
  /// this context follows.
  ///
  /// An unrecognised `type` string is **not** such a failure: it is a newer
  /// backend, and it maps to [SplitActivityType.unknown] so the rest of the
  /// page survives (see that value). A missing or non-string `type` still
  /// throws — that is a broken response, not a newer one.
  factory SplitActivity.fromJson(Map<String, dynamic> json) {
    try {
      final type = _wireTypes[json['type'] as String] ?? SplitActivityType.unknown;
      return SplitActivity(
        id: json['id'] as String,
        type: type,
        actorUserId: json['actor_user_id'] as String,
        actorDisplayName: json['actor_display_name'] as String,
        groupId: json['group_id'] as String?,
        groupName: json['group_name'] as String?,
        subjectId: json['subject_id'] as String?,
        counterpartUserId: json['counterpart_user_id'] as String?,
        counterpartDisplayName: json['counterpart_display_name'] as String?,
        amount: json['amount'] as int?,
        previousAmount: json['previous_amount'] as int?,
        changedFields: _stringList(json['changed_fields']),
        addedDisplayNames: _stringList(json['added_display_names']),
        removedDisplayNames: _stringList(json['removed_display_names']),
        actorIsPayer: json['actor_is_payer'] as bool?,
        currency: json['currency'] as String?,
        description: json['description'] as String?,
        createdAt: json['created_at'] as String,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}

/// A wire array of strings, or null when the key is absent or null. An empty
/// array stays an empty list: it is the answer "this edit changed nothing",
/// not the absence of an answer.
List<String>? _stringList(dynamic value) =>
    value == null ? null : [for (final item in value as List<dynamic>) item as String];

/// One page of the change log.
///
/// [nextCursor] is **not** a has-more flag. The backend only returns `null`
/// when the page came back short, so a last page that happens to be exactly
/// `limit` long still carries a cursor and the *next* request is the one
/// that comes back empty (`list-activity.ts`). An empty page is therefore
/// the ordinary terminal state, not an error and not an empty change log.
class SplitActivityPage {
  final List<SplitActivity> entries;
  final String? nextCursor;

  const SplitActivityPage({required this.entries, required this.nextCursor});
}
