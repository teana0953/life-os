import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';
import 'package:life_os/contexts/menstrual/presentation/cycle_badge_style.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/app_theme.dart';

final _scheme = lightTheme.colorScheme;
final _loc = lookupAppLocalizations(const Locale('en'));

void main() {
  group('cycleBadgeStyleFor', () {
    test('an ongoing period is a filled badge in the period colour', () {
      final style = cycleBadgeStyleFor(NextPeriodState.ongoing, _scheme)!;
      expect(style.filled, isTrue);
      expect(style.color, _scheme.primary);
      expect(style.textColor, _scheme.onPrimary);
    });

    test('a prediction due today is a filled badge in the neutral colour', () {
      // Neutral, matching how the calendar already marks today — the period
      // colour here would claim the period had started.
      final style = cycleBadgeStyleFor(NextPeriodState.today, _scheme)!;
      expect(style.filled, isTrue);
      expect(style.color, _scheme.outline);
      expect(style.textColor, _scheme.onSurface);
    });

    test('a prediction still ahead is an outlined badge in the period colour', () {
      final style = cycleBadgeStyleFor(NextPeriodState.upcoming, _scheme)!;
      expect(style.filled, isFalse);
      expect(style.color, _scheme.primary);
      // Not `primary`: the pastel fails AA as foreground text (design.md's
      // hard constraint). The ring carries the "period colour" meaning.
      expect(style.textColor, _scheme.onSurface);
    });

    test('a passed prediction stays outlined and turns warning-coloured', () {
      // Outlined, not filled: an overdue date is still an unconfirmed
      // prediction, and only the colour changes.
      final style = cycleBadgeStyleFor(NextPeriodState.overdue, _scheme)!;
      expect(style.filled, isFalse);
      expect(style.color, financeBudgetWarningColor(_scheme));
      expect(style.textColor, financeBudgetWarningColor(_scheme));
    });

    test('the two states with nothing to predict get no badge at all', () {
      // Not an empty circle — that reads as a count of zero.
      expect(cycleBadgeStyleFor(NextPeriodState.needsOneMore, _scheme), isNull);
      expect(cycleBadgeStyleFor(NextPeriodState.noRecords, _scheme), isNull);
    });

    test('the dark theme keeps the warning colour AA-safe on its own ground', () {
      final dark = darkTheme.colorScheme;
      expect(
        cycleBadgeStyleFor(NextPeriodState.overdue, dark)!.color,
        financeBudgetWarningColor(dark),
      );
    });
  });

  group('cycleBadgeLabel', () {
    test('carries the day count for the three counted states', () {
      expect(
        cycleBadgeLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.ongoing, days: 4),
        ),
        _loc.cycleBadgeOngoing(4),
      );
      expect(
        cycleBadgeLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.upcoming, days: 6),
        ),
        _loc.cycleBadgeUpcoming(6),
      );
      expect(
        cycleBadgeLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.overdue, days: 3),
        ),
        _loc.cycleBadgeOverdue(3),
      );
    });

    test('says "today" instead of a zero-day countdown', () {
      expect(
        cycleBadgeLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.today),
        ),
        _loc.cycleBadgeToday,
      );
    });

    test('is null for the states that carry no badge', () {
      expect(
        cycleBadgeLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.needsOneMore),
        ),
        isNull,
      );
      expect(
        cycleBadgeLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.noRecords),
        ),
        isNull,
      );
    });
  });

  group('ongoingPeriodStart', () {
    test('day 1 is today itself, not yesterday', () {
      // The off-by-one this helper exists to get right once: `days` is
      // `daysBetween(start, today) + 1`, so inverting it subtracts days - 1.
      expect(
        ongoingPeriodStart(
          const NextPeriodStatus(state: NextPeriodState.ongoing, days: 1),
          DateTime(2026, 7, 28),
        ),
        DateTime(2026, 7, 28),
      );
    });

    test('day 4 is three days before today', () {
      expect(
        ongoingPeriodStart(
          const NextPeriodStatus(state: NextPeriodState.ongoing, days: 4),
          DateTime(2026, 7, 28),
        ),
        DateTime(2026, 7, 25),
      );
    });

    test('an uncapped day count reaches back across months', () {
      // A period left open long ago reads "day 41" and must date back 40
      // days, not to some capped floor.
      expect(
        ongoingPeriodStart(
          const NextPeriodStatus(state: NextPeriodState.ongoing, days: 41),
          DateTime(2026, 7, 28),
        ),
        DateTime(2026, 6, 18),
      );
    });

    test('is null for every state that has no ongoing period', () {
      // No caller can render a start date for a state that has none.
      for (final state in NextPeriodState.values) {
        if (state == NextPeriodState.ongoing) continue;
        expect(
          ongoingPeriodStart(
            NextPeriodStatus(state: state, days: 4),
            DateTime(2026, 7, 28),
          ),
          isNull,
          reason: '$state must not derive a start date',
        );
      }
    });
  });

  group('cycleStatusSemanticLabel', () {
    test('is one whole sentence per badged state', () {
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.ongoing, days: 4),
          'Jul 25, 2026',
        ),
        _loc.cycleStatusOngoingA11y(4, 'Jul 25, 2026'),
      );
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.upcoming, days: 6),
          'Aug 3, 2026',
        ),
        _loc.cycleStatusUpcomingA11y(6, 'Aug 3, 2026'),
      );
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.today),
          'Jul 28, 2026',
        ),
        _loc.cycleStatusTodayA11y('Jul 28, 2026'),
      );
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.overdue, days: 3),
          'Jul 25, 2026',
        ),
        _loc.cycleStatusOverdueA11y(3, 'Jul 25, 2026'),
      );
    });

    test('is null for the states with nothing to announce', () {
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.needsOneMore),
          null,
        ),
        isNull,
      );
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.noRecords),
          null,
        ),
        isNull,
      );
    });

    test('a badged state with no date to name announces nothing rather than '
        'a sentence with a hole in it', () {
      expect(
        cycleStatusSemanticLabel(
          _loc,
          const NextPeriodStatus(state: NextPeriodState.upcoming, days: 6),
          null,
        ),
        isNull,
      );
    });
  });
}
