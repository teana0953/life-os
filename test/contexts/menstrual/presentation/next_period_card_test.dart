import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/menstrual/presentation/next_period_card.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/stale_notice.dart';

import '../../../support/l10n_test_app.dart';

/// A repository that is never reached: the card is a listener, not a loader
/// (design D4), so any call here is a bug the tests below should surface.
class _UnusedMenstrualRepository implements MenstrualRepository {
  @override
  Future<MenstrualOverview> getOverview(String idToken) async =>
      throw UnimplementedError();

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async => throw UnimplementedError();

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deletePeriod(String idToken, String id) async =>
      throw UnimplementedError();
}

/// A controller whose status/overview are set directly, so every state the
/// card has to render — including "reloading with content already on screen" —
/// can be posed without driving a repository. [loadCount] proves the card
/// never loads on its own.
class _FakeMenstrualController extends MenstrualController {
  _FakeMenstrualController()
    : super(
        GetMenstrualOverview(_UnusedMenstrualRepository()),
        AddPeriod(_UnusedMenstrualRepository()),
        UpdatePeriod(_UnusedMenstrualRepository()),
        DeletePeriod(_UnusedMenstrualRepository()),
      );

  int loadCount = 0;
  String? lastLoadToken;

  /// When set, a [load] poses a successful reload (status back to `loaded`
  /// with this overview) — lets a test check that a retry clears the marking.
  MenstrualOverview? loadSucceedsWith;

  @override
  Future<void> load(String idToken) async {
    loadCount++;
    lastLoadToken = idToken;
    if (loadSucceedsWith != null) {
      status = MenstrualStatus.loaded;
      overview = loadSucceedsWith;
      notifyListeners();
    }
  }
}

MenstrualPeriod _period(DateTime start, [DateTime? end]) =>
    MenstrualPeriod(id: 'p-${start.toIso8601String()}', startDate: start, endDate: end);

MenstrualOverview _overview({
  List<MenstrualPeriod> periods = const [],
  DateTime? predictedNextStart,
}) => MenstrualOverview(
  periods: periods,
  stats: MenstrualStats(predictedNextStart: predictedNextStart),
  lastPeriod: periods.isEmpty ? null : periods.last,
);

/// The date exactly as the card formats it (the app's `mediumDateLabel`), so
/// the assertions don't hard-code a locale's date shape.
String _dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

final _loc = lookupAppLocalizations(const Locale('en'));

Future<_FakeMenstrualController> _pumpCard(
  WidgetTester tester, {
  required MenstrualStatus status,
  MenstrualOverview? overview,
  DateTime? clock,
  VoidCallback? onOpen,
}) async {
  final controller = _FakeMenstrualController()
    ..status = status
    ..overview = overview;
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: NextPeriodCard(
          controller: controller,
          idToken: () async => 'token-1',
          onOpen: onOpen ?? () {},
          clock: () => clock ?? DateTime(2026, 7, 28),
        ),
      ),
    ),
  );
  // `pump`, not `pumpAndSettle`: the first-load state renders an indeterminate
  // progress indicator, which never settles.
  await tester.pump();
  return controller;
}

void main() {
  group('NextPeriodCard states', () {
    testWidgets('a future prediction shows the date and the days to it', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
      );

      expect(find.text(_loc.nextPeriodTitle), findsOneWidget);
      // Main line and sub-line, asserted separately: the day count and the
      // date are two lines now, and a single combined assertion would pass
      // with either of them missing.
      expect(find.text(_loc.nextPeriodUpcomingDays(5)), findsOneWidget);
      expect(
        find.text(_loc.nextPeriodOngoingNext(_dateLabel(DateTime(2026, 8, 2)))),
        findsOneWidget,
      );
    });

    testWidgets('a prediction for today says so', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 28),
        ),
      );

      expect(find.text(_loc.nextPeriodToday), findsOneWidget);
    });

    testWidgets('a past prediction shows the date and how late it is', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 2),
        ),
      );

      expect(
        find.text(_loc.nextPeriodOverdue(_dateLabel(DateTime(2026, 7, 2)), 26)),
        findsOneWidget,
      );
    });

    testWidgets('an ongoing period shows its day and still shows the '
        'prediction', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [
            _period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
            _period(DateTime(2026, 7, 26)),
          ],
          predictedNextStart: DateTime(2026, 8, 20),
        ),
      );

      expect(find.text(_loc.nextPeriodOngoing(3)), findsOneWidget);
      expect(
        find.text(
          _loc.nextPeriodOngoingNext(_dateLabel(DateTime(2026, 8, 20))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an ongoing period with no prediction drops the secondary line '
        'entirely', (tester) async {
      // A brand-new user on the day of their first recording. Formatting a
      // null prediction here is the crash the pure-function tests cannot
      // catch, because the pure function only hands back a nullable date.
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(periods: [_period(DateTime(2026, 7, 28))]),
      );

      expect(find.text(_loc.nextPeriodOngoing(1)), findsOneWidget);
      expect(find.byKey(const Key('next-period-secondary')), findsNothing);
    });

    testWidgets('an ongoing period whose prediction has gone by drops the '
        'secondary line too', (tester) async {
      // A period left open past a whole average cycle has a prediction that is
      // already in the past. Showing it as "next expected" would put a past
      // date under an upcoming label — the exact thing the overdue copy exists
      // to avoid, arriving through the ongoing state instead.
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 14))],
          predictedNextStart: DateTime(2026, 7, 12),
        ),
        clock: DateTime(2026, 7, 28),
      );

      expect(find.text(_loc.nextPeriodOngoing(45)), findsOneWidget);
      expect(
        find.text(_loc.nextPeriodOngoingNext(_dateLabel(DateTime(2026, 7, 12)))),
        findsNothing,
      );
    });

    testWidgets('an ongoing period left open long ago is not capped', (
      tester,
    ) async {
      // The uncapped count IS the signal that the period was never closed.
      // Capping it would quietly turn a data-entry mistake into a plausible
      // number.
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(periods: [_period(DateTime(2026, 6, 14))]),
        clock: DateTime(2026, 7, 28),
      );

      expect(find.text(_loc.nextPeriodOngoing(45)), findsOneWidget);
    });

    testWidgets('an ongoing period whose prediction is today also drops the '
        'secondary line', (tester) async {
      // A period open for exactly one average cycle predicts today. "Next
      // expected 28 Jul" shown on the 28th contradicts itself, so the line
      // goes at the boundary, not one day past it.
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 30))],
          predictedNextStart: DateTime(2026, 7, 28),
        ),
        clock: DateTime(2026, 7, 28),
      );

      expect(find.text(_loc.nextPeriodOngoing(29)), findsOneWidget);
      expect(
        find.text(_loc.nextPeriodOngoingNext(_dateLabel(DateTime(2026, 7, 28)))),
        findsNothing,
      );
    });

    testWidgets('no records at all says so', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(),
      );

      expect(find.text(_loc.nextPeriodNoRecords), findsOneWidget);
      expect(find.text(_loc.nextPeriodNeedsOneMore), findsNothing);
    });

    testWidgets('a single recorded period asks for one more', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        ),
      );

      expect(find.text(_loc.nextPeriodNeedsOneMore), findsOneWidget);
    });
  });

  group('NextPeriodCard tapping', () {
    testWidgets('tapping the card opens the tracker', (tester) async {
      var opened = 0;
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
        onOpen: () => opened++,
      );

      await tester.tap(find.byKey(const Key('next-period-card')));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('the card still opens the tracker with nothing recorded — the '
        'state where the shortcut matters most', (tester) async {
      var opened = 0;
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(),
        onOpen: () => opened++,
      );

      await tester.tap(find.byKey(const Key('next-period-card')));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });
  });

  group('NextPeriodCard loading and error', () {
    testWidgets('the first load shows a spinner inside the card', (
      tester,
    ) async {
      await _pumpCard(tester, status: MenstrualStatus.loading);

      expect(find.byKey(const Key('next-period-loading')), findsOneWidget);
    });

    testWidgets('a reload keeps the content it already has instead of blanking '
        'the card', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loading,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
      );

      expect(find.byKey(const Key('next-period-loading')), findsNothing);
      expect(
        find.text(_loc.nextPeriodUpcomingDays(5)),
        findsOneWidget,
      );
      // A refresh in flight is not a failure, so nothing is marked. Asserted
      // on the marking's row, not on [StaleNotice] itself: the card keeps the
      // widget mounted through a reload so it can remember a retry the user
      // pressed, and it renders nothing until it has something to say.
      expect(find.byKey(const Key('stale-notice-row')), findsNothing);
    });

    testWidgets('a load failure with nothing loaded before shows the shared '
        'menstrual error copy inside the card', (tester) async {
      await _pumpCard(tester, status: MenstrualStatus.error);

      expect(find.text(_loc.errorMenstrualLoadFailed), findsOneWidget);
      // Nothing has loaded, so there is nothing to mark as unrefreshed.
      expect(find.byType(StaleNotice), findsNothing);
    });

    testWidgets('the failure offers a retry that actually retries', (
      tester,
    ) async {
      // Every other overview card puts a retry here. Saying "please try again"
      // while offering nothing to try again with is a dead end.
      final controller = await _pumpCard(tester, status: MenstrualStatus.error);

      await tester.tap(find.byKey(const Key('next-period-retry')));
      await tester.pump();

      expect(controller.loadCount, 1);
      // The token the card was given, not a stale or empty one.
      expect(controller.lastLoadToken, 'token-1');
    });

    testWidgets(
      'a failed reload after content keeps the content and marks it as not '
      'refreshed',
      (tester) async {
        await _pumpCard(
          tester,
          status: MenstrualStatus.error,
          overview: _overview(
            periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
            predictedNextStart: DateTime(2026, 8, 2),
          ),
        );

        expect(find.text(_loc.errorMenstrualLoadFailed), findsNothing);
        expect(
          find.text(_loc.nextPeriodUpcomingDays(5)),
          findsOneWidget,
        );
        expect(find.byType(StaleNotice), findsOneWidget);
        expect(find.text(_loc.cardRefreshFailed), findsOneWidget);
      },
    );

    testWidgets(
      'a reload that 401s is not the card\'s to report — no marking, no error '
      'copy, the overview\'s re-authenticate exit takes over',
      (tester) async {
        await _pumpCard(
          tester,
          status: MenstrualStatus.needsReauth,
          overview: _overview(
            periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
            predictedNextStart: DateTime(2026, 8, 2),
          ),
        );

        expect(
          find.text(_loc.nextPeriodUpcomingDays(5)),
          findsOneWidget,
        );
        // "Couldn't refresh, retry" would send the user round a loop that
        // cannot succeed until they sign in again.
        expect(find.byType(StaleNotice), findsNothing);
        expect(find.text(_loc.errorMenstrualLoadFailed), findsNothing);
      },
    );

    testWidgets('the marking\'s retry reloads this card, and a successful one '
        'clears the marking', (tester) async {
      final overview = _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 8, 2),
      );
      final controller = await _pumpCard(
        tester,
        status: MenstrualStatus.error,
        overview: overview,
      );
      controller.loadSucceedsWith = overview;

      await tester.tap(find.byKey(const Key('stale-notice-retry')));
      await tester.pumpAndSettle();

      expect(controller.loadCount, 1);
      expect(controller.lastLoadToken, 'token-1');
      expect(find.byType(StaleNotice), findsNothing);
      expect(find.byKey(const Key('next-period-card')), findsOneWidget);
    });
  });

  group('NextPeriodCard badge', () {
    // Fixtures posed against a fixed 2026-07-28 clock, one per state.
    final badged = <String, MenstrualOverview>{
      'ongoing': _overview(
        periods: [
          _period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
          _period(DateTime(2026, 7, 25)),
        ],
        predictedNextStart: DateTime(2026, 8, 20),
      ),
      'upcoming': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 8, 3),
      ),
      'today': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 7, 28),
      ),
      'overdue': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 7, 25),
      ),
    };

    final unbadged = <String, MenstrualOverview>{
      'needsOneMore': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
      ),
      'noRecords': _overview(),
    };

    testWidgets('every badged state leads with one', (tester) async {
      for (final entry in badged.entries) {
        await _pumpCard(
          tester,
          status: MenstrualStatus.loaded,
          overview: entry.value,
          clock: DateTime(2026, 7, 28),
        );

        expect(
          find.byKey(const Key('next-period-badge')),
          findsOneWidget,
          reason: '${entry.key} lost its badge',
        );
      }
    });

    testWidgets('a state with nothing to predict carries none', (tester) async {
      // An empty circle would read as a count of zero.
      for (final entry in unbadged.entries) {
        await _pumpCard(
          tester,
          status: MenstrualStatus.loaded,
          overview: entry.value,
          clock: DateTime(2026, 7, 28),
        );

        expect(
          find.byKey(const Key('next-period-badge')),
          findsNothing,
          reason: '${entry.key} drew a badge',
        );
      }
    });

    testWidgets('the badge sits 16dp left of the text column', (tester) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: badged['upcoming'],
        clock: DateTime(2026, 7, 28),
      );

      final badge = tester.getRect(find.byKey(const Key('next-period-badge')));
      final title = tester.getRect(find.text(_loc.nextPeriodTitle));
      expect(title.left - badge.right, 16);
    });
  });

  group('NextPeriodCard overdue explanation', () {
    testWidgets('states the overage in words, not only in colour', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 25),
        ),
        clock: DateTime(2026, 7, 28),
      );

      expect(find.text(_loc.nextPeriodOverduePassed(3)), findsOneWidget);
      expect(
        find.byKey(const Key('next-period-overdue-explanation')),
        findsOneWidget,
      );
    });

    testWidgets('is absent in every other state', (tester) async {
      final others = <String, MenstrualOverview>{
        'upcoming': _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 3),
        ),
        'today': _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 28),
        ),
        'ongoing': _overview(periods: [_period(DateTime(2026, 7, 25))]),
        'needsOneMore': _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        ),
        'noRecords': _overview(),
      };

      for (final entry in others.entries) {
        await _pumpCard(
          tester,
          status: MenstrualStatus.loaded,
          overview: entry.value,
          clock: DateTime(2026, 7, 28),
        );

        expect(
          find.byKey(const Key('next-period-overdue-explanation')),
          findsNothing,
          reason: '${entry.key} explained an overage it does not have',
        );
      }
    });
  });

  group('NextPeriodCard semantics', () {
    testWidgets('announces one whole sentence per badged state, never a bare '
        'number', (tester) async {
      final handle = tester.ensureSemantics();

      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 25),
        ),
        clock: DateTime(2026, 7, 28),
      );

      expect(
        find.bySemanticsLabel(
          _loc.cycleStatusOverdueA11y(3, _dateLabel(DateTime(2026, 7, 25))),
        ),
        findsOneWidget,
      );
      // The badge's own text is excluded, so "3d late" is never a node of its
      // own beside the sentence that explains it.
      expect(find.bySemanticsLabel(_loc.cycleBadgeOverdue(3)), findsNothing);

      handle.dispose();
    });

    testWidgets('the ongoing sentence names the derived start date', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: _overview(periods: [_period(DateTime(2026, 7, 25))]),
        clock: DateTime(2026, 7, 28),
      );

      expect(
        find.bySemanticsLabel(
          _loc.cycleStatusOngoingA11y(4, _dateLabel(DateTime(2026, 7, 25))),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  testWidgets('no state but "nothing recorded" ever renders the '
      '"nothing recorded" copy', (tester) async {
    // The copy switch ends in a catch-all that falls back to this string, so a
    // state arriving without the data its copy needs would silently tell
    // someone with years of history that they have recorded nothing — the most
    // misleading sentence available. Unreachable today; this is what says so,
    // and says it by name when it stops being true.
    final cases = <String, MenstrualOverview>{
      'upcoming': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 8, 2),
      ),
      'today': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 7, 28),
      ),
      'overdue': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
        predictedNextStart: DateTime(2026, 7, 20),
      ),
      'ongoing': _overview(periods: [_period(DateTime(2026, 7, 26))]),
      'needsOneMore': _overview(
        periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
      ),
    };

    for (final entry in cases.entries) {
      await _pumpCard(
        tester,
        status: MenstrualStatus.loaded,
        overview: entry.value,
        clock: DateTime(2026, 7, 28),
      );

      expect(
        find.text(_loc.nextPeriodNoRecords),
        findsNothing,
        reason: '${entry.key} rendered the "nothing recorded" copy',
      );
    }
  });

  testWidgets('the card never loads by itself — the scaffold owns that', (
    tester,
  ) async {
    final controller = await _pumpCard(
      tester,
      status: MenstrualStatus.loaded,
      overview: _overview(),
    );

    expect(controller.loadCount, 0);
  });
}
