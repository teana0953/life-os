import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../domain/next_period_status.dart';

/// How a [CycleBadge] looks for one [NextPeriodState] — the mapping the home
/// tile and the health overview's next-period card share, so the same state
/// can never be depicted differently on the two surfaces.
///
/// It lives here rather than in `shared/widgets/` so the badge widget itself
/// stays free of menstrual-domain knowledge.
class CycleBadgeStyle {
  final bool filled;
  final Color color;
  final Color textColor;

  const CycleBadgeStyle({
    required this.filled,
    required this.color,
    required this.textColor,
  });
}

/// `null` for the two states with nothing to predict — an empty circle reads
/// as a count of zero.
///
/// The two forms are the menstrual calendar's: **filled** for a period day
/// that is actually happening, **outlined** for a prediction. `overdue` stays
/// outlined for that reason and only changes colour — filling it would claim
/// the period had started.
///
/// The text colours are not the badge colours: `primary` and the warning
/// pastel are border/fill tokens that fail AA as foreground text on the light
/// theme (design.md's hard constraint), so the outlined forms take
/// `onSurface`, and the warning text comes from the AA-safe
/// [financeBudgetWarningColor] rather than the raw pastel.
CycleBadgeStyle? cycleBadgeStyleFor(NextPeriodState state, ColorScheme scheme) {
  switch (state) {
    case NextPeriodState.ongoing:
      return CycleBadgeStyle(
        filled: true,
        color: scheme.primary,
        textColor: scheme.onPrimary,
      );
    case NextPeriodState.today:
      return CycleBadgeStyle(
        filled: true,
        color: scheme.outline,
        textColor: scheme.onSurface,
      );
    case NextPeriodState.upcoming:
      return CycleBadgeStyle(
        filled: false,
        color: scheme.primary,
        textColor: scheme.onSurface,
      );
    case NextPeriodState.overdue:
      return CycleBadgeStyle(
        filled: false,
        color: financeBudgetWarningColor(scheme),
        textColor: financeBudgetWarningColor(scheme),
      );
    case NextPeriodState.needsOneMore:
    case NextPeriodState.noRecords:
      return null;
  }
}

/// The badge's short number-plus-unit text — `null` wherever
/// [cycleBadgeStyleFor] is, so a badge can never be drawn without one.
String? cycleBadgeLabel(AppLocalizations loc, NextPeriodStatus status) {
  final days = status.days;
  switch (status.state) {
    case NextPeriodState.ongoing:
      return days == null ? null : loc.cycleBadgeOngoing(days);
    case NextPeriodState.upcoming:
      return days == null ? null : loc.cycleBadgeUpcoming(days);
    case NextPeriodState.overdue:
      return days == null ? null : loc.cycleBadgeOverdue(days);
    case NextPeriodState.today:
      return loc.cycleBadgeToday;
    case NextPeriodState.needsOneMore:
    case NextPeriodState.noRecords:
      return null;
  }
}

/// The date the ongoing period started, derived as `today - (days - 1)` —
/// `null` for every other state.
///
/// Derived in presentation rather than added to [NextPeriodStatus]: `days` is
/// defined by `computeNextPeriodStatus` as `daysBetween(start, today) + 1`, so
/// inverting it cannot disagree with its source, and a domain type would be
/// widened for one screen's formatting need. One helper, not one per surface,
/// so the tile and the card cannot compute a different date.
///
/// Anchored in UTC before subtracting, for the same reason
/// `menstrualCycleDay` in `menstrual_calendar.dart` is: `today` carries a
/// local time-of-day, and `Duration(days: N)` is a fixed N×24h offset, not a
/// calendar-day one — subtracting it from a local `DateTime` across a DST
/// transition can land on the wrong calendar day. Without this anchor, this
/// function could disagree with `menstrualCycleDay` about the same day,
/// which is exactly the disagreement this pair of functions exists to rule
/// out.
DateTime? ongoingPeriodStart(NextPeriodStatus status, DateTime today) {
  final days = status.days;
  if (status.state != NextPeriodState.ongoing || days == null) return null;
  final todayUtc = DateTime.utc(today.year, today.month, today.day);
  final startUtc = todayUtc.subtract(Duration(days: days - 1));
  return DateTime(startUtc.year, startUtc.month, startUtc.day);
}

/// The one sentence a screen reader hears for a badged state: the state, the
/// count and the date together, so the badge's bare number is never announced
/// on its own (the badge itself is inside an `ExcludeSemantics`).
///
/// [dateLabel] is the already-formatted date the state names — the derived
/// start date while a period is ongoing, the predicted next start otherwise —
/// formatted by the calling surface, which owns which date format it uses.
/// `null` when there is no badge, and also when the state has no date to name:
/// a sentence with a hole in it is worse than the painted text alone.
String? cycleStatusSemanticLabel(
  AppLocalizations loc,
  NextPeriodStatus status,
  String? dateLabel,
) {
  if (dateLabel == null) return null;
  final days = status.days;
  switch (status.state) {
    case NextPeriodState.ongoing:
      return days == null ? null : loc.cycleStatusOngoingA11y(days, dateLabel);
    case NextPeriodState.upcoming:
      return days == null ? null : loc.cycleStatusUpcomingA11y(days, dateLabel);
    case NextPeriodState.overdue:
      return days == null ? null : loc.cycleStatusOverdueA11y(days, dateLabel);
    case NextPeriodState.today:
      return loc.cycleStatusTodayA11y(dateLabel);
    case NextPeriodState.needsOneMore:
    case NextPeriodState.noRecords:
      return null;
  }
}
