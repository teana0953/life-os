import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../finance/domain/finance_money.dart';
import '../domain/split_activity.dart';
import 'split_activity_direction.dart';

/// One entry of the split change log.
///
/// Shaped like [SplitExpenseRow]/[SettlementRow] — leading icon, a headline,
/// a timestamp, an amount on the right — but with **no** edit or delete
/// affordance and **no** `onTap`: the record it describes may not exist any
/// more, so there is nothing to open. A row that looked tappable and did
/// nothing would be worse than one that plainly isn't.
class SplitActivityRow extends StatelessWidget {
  final SplitActivity entry;

  /// The reader. `null` (profile not resolved) is nobody — never the actor.
  final String? selfUserId;

  /// Converts a parsed instant to the local zone. Injectable so a test can
  /// pin it and get the same rendering under `TZ=UTC` as under UTC+8.
  final DateTime Function(DateTime) toLocalTime;

  const SplitActivityRow({
    super.key,
    required this.entry,
    required this.selfUserId,
    this.toLocalTime = _toLocal,
  });

  static DateTime _toLocal(DateTime instant) => instant.toLocal();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final headline = _headline(loc);
    final direction = _directionLine(loc);
    final amountLabel = _amountLabel(loc);
    // The spoken form differs from the painted one for exactly one shape: an
    // edit's before→after pair. "2,000 → 1,500" is read out as the two
    // numbers with the arrow glyph announced (or silently dropped), so the
    // row tells a screen-reader user two amounts and never which is which.
    final spokenAmountLabel = _amountLabel(loc, spoken: true);
    final timeLabel = _localDateTimeLabel(context, toLocalTime, entry.createdAt);

    // One sentence, not four fragments: a screen reader otherwise reads the
    // headline, the direction, the number and the timestamp as unrelated
    // nodes and the row stops being a statement about anything.
    final what = direction == null
        ? headline
        : loc.splitActivityRowDetail(headline, direction);
    final semanticLabel = spokenAmountLabel == null
        ? loc.splitActivityRowSemanticsNoAmount(what, timeLabel)
        : loc.splitActivityRowSemantics(what, spokenAmountLabel, timeLabel);

    return Semantics(
      key: Key('split-activity-semantics-${entry.id}'),
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: ListTile(
        key: Key('split-activity-row-${entry.id}'),
        isThreeLine: direction != null || amountLabel != null,
        leading: Icon(_icon),
        // The headline gets the whole row, and the amount is **stacked under
        // it** rather than sharing the row with it. `SplitExpenseRow` puts
        // the two side by side in a `LabelValueRow`, and that works there
        // because its label is a short description; here the label is a whole
        // sentence ("Amy edited Dinner at Ichiran") and the value can be a
        // *pair* of amounts ("18,000 → 12,500"), so `LabelValueRow`'s fixed
        // 65% cap starved both halves at once. Measured by QA at 320dp,
        // textScale 2.0: the amount painted as `18,` / `000 ` / `→ ` / `12,` /
        // `500` — a monetary figure broken mid-thousands-group, readable as a
        // different number — and the headline came back one glyph per line,
        // 15 lines, a 1288dp row against the 128dp `SplitExpenseRow` renders
        // the same expense in. No `FlutterError` is raised by any of that, so
        // every `expectNoLayoutErrors` guard stayed green.
        //
        // `_TransactionRow` in `finance_overview_tab.dart` hit the same wall
        // and answered it with an absolute floor instead of a fraction; that
        // works there because it has one amount to fit. Two amounts and an
        // arrow do not fit beside a sentence at 320dp/2x under *any* split of
        // the row, so the second half of the row is the wrong place for them
        // — the constraint is legibility, not preserving the shape.
        //
        // Full width also means a wrap can only happen at the spaces around
        // the arrow (a `Text` breaks inside a word only when the word alone
        // exceeds the line), so neither number can be cut mid-digit-group.
        title: Text(headline),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (direction != null) Text(direction),
            if (amountLabel != null)
              Text(
                amountLabel,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            Text(timeLabel),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (entry.type) {
    SplitActivityType.expenseCreated => Icons.receipt_long,
    SplitActivityType.expenseUpdated => Icons.edit_outlined,
    SplitActivityType.expenseDeleted => Icons.delete_outline,
    SplitActivityType.settlementCreated => Icons.sync_alt,
    SplitActivityType.settlementDeleted => Icons.delete_outline,
    SplitActivityType.groupCreated => Icons.group_add_outlined,
    SplitActivityType.groupMemberAdded => Icons.person_add_alt,
    SplitActivityType.groupArchived => Icons.archive_outlined,
    SplitActivityType.unknown => Icons.autorenew,
  };

  bool get _actorIsReader => selfUserId != null && selfUserId == entry.actorUserId;

  /// Whether the *other* person in the entry is the reader.
  ///
  /// The actor is not the only person a row can name. Repayments were given
  /// this treatment already (see [resolveRepaymentDirection]) after "Amy paid
  /// Me" shipped; `group_member_added` is the other type the backend fills a
  /// counterpart on, and it had the identical bug — someone adding the reader
  /// to a group rendered the reader's own display name in the third person.
  /// Those two are the whole set: every other type leaves
  /// `counterpart_user_id` null.
  bool get _counterpartIsReader =>
      selfUserId != null && selfUserId == entry.counterpartUserId;

  /// A person's name, or the neutral placeholder.
  ///
  /// The test is `displayName == userId`, **not** `displayName == null`
  /// alone: `actor_display_name` is not nullable — the backend fills it with
  /// the actor's raw user id when it has no name or email — so a `??`
  /// fallback is a guard that can never fire while the id goes on screen.
  /// `counterpart_display_name` genuinely is nullable, and the same
  /// expression catches it.
  String _personName(AppLocalizations loc, String? userId, String? displayName) {
    if (displayName == null || displayName == userId) return loc.splitUnknownMember;
    return displayName;
  }

  String _headline(AppLocalizations loc) {
    final actor = _personName(loc, entry.actorUserId, entry.actorDisplayName);
    final item = entry.description ?? loc.splitActivityUnnamedItem;
    final group = entry.groupName ?? loc.splitActivityUnnamedGroup;
    final member = _personName(loc, entry.counterpartUserId, entry.counterpartDisplayName);

    return switch (entry.type) {
      SplitActivityType.expenseCreated => _actorIsReader
          ? loc.splitActivityExpenseCreatedYou(item)
          : loc.splitActivityExpenseCreatedOther(actor, item),
      SplitActivityType.expenseUpdated => _actorIsReader
          ? loc.splitActivityExpenseUpdatedYou(item)
          : loc.splitActivityExpenseUpdatedOther(actor, item),
      SplitActivityType.expenseDeleted => _actorIsReader
          ? loc.splitActivityExpenseDeletedYou(item)
          : loc.splitActivityExpenseDeletedOther(actor, item),
      SplitActivityType.settlementCreated => _actorIsReader
          ? loc.splitActivitySettlementCreatedYou
          : loc.splitActivitySettlementCreatedOther(actor),
      SplitActivityType.settlementDeleted => _actorIsReader
          ? loc.splitActivitySettlementDeletedYou
          : loc.splitActivitySettlementDeletedOther(actor),
      SplitActivityType.groupCreated => _actorIsReader
          ? loc.splitActivityGroupCreatedYou(group)
          : loc.splitActivityGroupCreatedOther(actor, group),
      SplitActivityType.groupMemberAdded => _actorIsReader
          ? loc.splitActivityGroupMemberAddedYou(member, group)
          : _counterpartIsReader
          ? loc.splitActivityGroupMemberAddedYouWere(actor, group)
          : loc.splitActivityGroupMemberAddedOther(actor, member, group),
      SplitActivityType.groupArchived => _actorIsReader
          ? loc.splitActivityGroupArchivedYou(group)
          : loc.splitActivityGroupArchivedOther(actor, group),
      SplitActivityType.unknown => _actorIsReader
          ? loc.splitActivityUnknownYou
          : loc.splitActivityUnknownOther(actor),
    };
  }

  /// "You paid Ben" / "Ben paid you" / "Amy paid Ben", or `null` when the
  /// entry is not a repayment. The direction itself is resolved by
  /// [resolveRepaymentDirection] — see there for why it is not decided here.
  String? _directionLine(AppLocalizations loc) {
    final direction = resolveRepaymentDirection(entry, selfUserId);
    if (direction == null) return null;
    String name(RepaymentParty party) =>
        _personName(loc, party.userId, party.displayName);
    return switch (direction.viewpoint) {
      RepaymentViewpoint.readerPaid =>
        loc.splitActivityRepaymentYouPaid(name(direction.other)),
      RepaymentViewpoint.readerWasPaid =>
        loc.splitActivityRepaymentPaidYou(name(direction.other)),
      RepaymentViewpoint.betweenOthers => loc.splitActivityRepaymentBetween(
        name(direction.payer),
        name(direction.payee),
      ),
    };
  }

  /// The amount, or before→after when an edit actually moved it. With
  /// [spoken] the pair is worded ("from X to Y") instead of drawn with an
  /// arrow — see the call site.
  ///
  /// `previousAmount != amount`, not `previousAmount != null`: the backend
  /// writes `previous_amount` on **every** edit, including ones that only
  /// touched the description, the day or the participants — the `!= null`
  /// form renders "2,000 → 2,000" on all of those.
  String? _amountLabel(AppLocalizations loc, {bool spoken = false}) {
    final amount = entry.amount;
    final currency = entry.currency;
    if (amount == null || currency == null) return null;
    final now = formatMinorUnitsForDisplay(amount, currency);
    final previous = entry.previousAmount;
    if (previous == null || previous == amount) return now;
    final before = formatMinorUnitsForDisplay(previous, currency);
    return spoken
        ? loc.splitActivityAmountChangeSpoken(before, now)
        : loc.splitActivityAmountChange(before, now);
  }
}

/// A UTC ISO instant → "medium local date HH:mm", the shape
/// `friends_screen._localDateTimeLabel` uses (`parseInstant` +
/// `mediumDateLabelOrDash` + an inline 24h `DateFormat`). Two changes made on
/// the same day are otherwise indistinguishable.
String _localDateTimeLabel(
  BuildContext context,
  DateTime Function(DateTime) toLocalTime,
  String iso,
) {
  final instant = parseInstant(iso);
  if (instant == null) return mediumDateLabelOrDash(context, '');
  final local = toLocalTime(instant);
  return '${mediumDateLabelOrDash(context, dayString(local))} '
      '${DateFormat('HH:mm').format(local)}';
}
