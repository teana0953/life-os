import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_adherence_card.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/data_revision.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';

class _FakeCareHistoryRepository implements CareHistoryRepository {
  List<CareHistoryDay> days;
  Object? getError;

  /// When set, the next [getRange] call awaits this before returning — lets
  /// a test hold a reload in flight to assert on the mid-reload UI state.
  Completer<void>? getRangeCompleter;
  final List<({String from, String to})> getRangeCalls = [];

  _FakeCareHistoryRepository({required this.days});

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async {
    getRangeCalls.add((from: from, to: to));
    final completer = getRangeCompleter;
    if (completer != null) {
      getRangeCompleter = null;
      await completer.future;
    }
    if (getError != null) throw getError!;
    return days;
  }

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {}
}

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  CareTodayStatus status = CareTodayStatus.done,
  String timeOfDay = '08:00',
  String localDate = '2026-07-22',
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: 'Metformin',
  timeOfDay: timeOfDay,
  localDate: localDate,
  status: status,
  doseQuantity: 1,
);

/// A dense 7-day range ending 2026-07-22 (matching the fixed test clock),
/// mirroring the backend's dense-array contract: every date gets an entry,
/// `items: []` when nothing was scheduled.
List<CareHistoryDay> _sevenDayRange({
  List<CareTodaySlot> onJul22 = const [],
}) => [
  const CareHistoryDay(date: '2026-07-16', slots: []),
  const CareHistoryDay(date: '2026-07-17', slots: []),
  const CareHistoryDay(date: '2026-07-18', slots: []),
  const CareHistoryDay(date: '2026-07-19', slots: []),
  const CareHistoryDay(date: '2026-07-20', slots: []),
  const CareHistoryDay(date: '2026-07-21', slots: []),
  CareHistoryDay(date: '2026-07-22', slots: onJul22),
];

/// A dense 7-day range ending 2026-07-22 in which every [CareDayState]
/// occurs at least once, so a test can compare each state's heatmap cell
/// against its legend swatch. See [_dateForState] for the mapping.
List<CareHistoryDay> _allStatesRange() => [
  const CareHistoryDay(date: '2026-07-16', slots: []),
  CareHistoryDay(
    date: '2026-07-17',
    slots: [_slot(status: CareTodayStatus.done, localDate: '2026-07-17')],
  ),
  CareHistoryDay(
    date: '2026-07-18',
    slots: [
      _slot(status: CareTodayStatus.done, localDate: '2026-07-18'),
      _slot(
        careScheduleId: 'sch-2',
        status: CareTodayStatus.missed,
        timeOfDay: '20:00',
        localDate: '2026-07-18',
      ),
    ],
  ),
  CareHistoryDay(
    date: '2026-07-19',
    slots: [_slot(status: CareTodayStatus.missed, localDate: '2026-07-19')],
  ),
  CareHistoryDay(
    date: '2026-07-20',
    slots: [_slot(status: CareTodayStatus.pending, localDate: '2026-07-20')],
  ),
  const CareHistoryDay(date: '2026-07-21', slots: []),
  const CareHistoryDay(date: '2026-07-22', slots: []),
];

/// The date in [_allStatesRange] whose cell renders each state.
const _dateForState = {
  CareDayState.noSchedule: '2026-07-16',
  CareDayState.full: '2026-07-17',
  CareDayState.partial: '2026-07-18',
  CareDayState.missed: '2026-07-19',
  CareDayState.upcoming: '2026-07-20',
};

String _stateLabel(AppLocalizations loc, CareDayState state) => switch (state) {
  CareDayState.full => loc.careHistoryLegendFull,
  CareDayState.partial => loc.careHistoryLegendPartial,
  CareDayState.missed => loc.careHistoryLegendMissed,
  CareDayState.upcoming => loc.careHistoryLegendUpcoming,
  CareDayState.noSchedule => loc.careHistoryLegendNoSchedule,
};

double _channelLuminance(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color color) =>
    0.2126 * _channelLuminance(color.r) +
    0.7152 * _channelLuminance(color.g) +
    0.0722 * _channelLuminance(color.b);

/// The WCAG contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The floor every day-state fill must clear — against the card's own
/// surface *and* against every other state's fill — composited the way it
/// actually paints. Not a WCAG threshold (these are decorative fills, not
/// text): it's the "you can see there is a cell here, and it isn't that
/// other cell" line. QA measured the pre-fix `noSchedule` fill at ~1.12:1
/// against the dark card surface, and the light theme's `full` vs
/// `noSchedule` pair at ~1.01:1 — in a 25px square those two are separated
/// by hue alone, which a greyscale or fully color-blind reader doesn't have.
const _minFillContrast = 1.3;

CareHistoryController _controller({
  CareHistoryRepository? repository,
  int spanDays = 7,
}) {
  final repo = repository ?? _FakeCareHistoryRepository(days: const []);
  return CareHistoryController(
    GetCareHistory(repo),
    EditCareSlot(repo),
    DataRevision(),
    spanDays: spanDays,
    clock: () => DateTime(2026, 7, 22),
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  CareHistoryController controller, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
  VoidCallback? onOpenHistory,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: CareAdherenceCard(
          controller: controller,
          idToken: 'token-123',
          onOpenHistory: onOpenHistory ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CareAdherenceCard', () {
    testWidgets(
      'never triggers a load itself (only addListener) — shows the loading '
      'spinner for a controller nobody has loaded yet',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository);

        // Not `_pumpCard`/`pumpAndSettle`: the loading spinner animates
        // indefinitely (nobody ever calls `controller.load`), so
        // `pumpAndSettle` would never return.
        await tester.pumpWidget(
          l10nTestApp(
            home: Scaffold(
              body: CareAdherenceCard(
                controller: controller,
                idToken: 'token-123',
                onOpenHistory: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('care-adherence-card-loading')),
          findsOneWidget,
        );
        expect(repository.getRangeCalls, isEmpty);
      },
    );

    testWidgets(
      'loaded: shows the headline, one heatmap cell per day in the span, '
      'and a five-item legend each carrying its state\'s day count',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        );
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        expect(
          find.byKey(const Key('care-adherence-card-loading')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('care-adherence-adherence-rate')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-adherence-days-with-dose')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-adherence-missed-count')),
          findsOneWidget,
        );

        for (final date in [
          '2026-07-16',
          '2026-07-17',
          '2026-07-18',
          '2026-07-19',
          '2026-07-20',
          '2026-07-21',
          '2026-07-22',
        ]) {
          expect(find.byKey(Key('care-adherence-cell-$date')), findsOneWidget);
        }

        // 2026-07-22 is `full` (its one due slot is done); the other six
        // days are `noSchedule` (nothing scheduled).
        final loc = lookupAppLocalizations(const Locale('en'));
        final legendFinder = find.byKey(const Key('care-adherence-legend'));
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(
              loc.careAdherenceLegendWithCount(loc.careHistoryLegendFull, 1),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(
              loc.careAdherenceLegendWithCount(
                loc.careHistoryLegendNoSchedule,
                6,
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(
              loc.careAdherenceLegendWithCount(loc.careHistoryLegendPartial, 0),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(
              loc.careAdherenceLegendWithCount(loc.careHistoryLegendMissed, 0),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(
              loc.careAdherenceLegendWithCount(
                loc.careHistoryLegendUpcoming,
                0,
              ),
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'each heatmap cell\'s Tooltip message and Semantics label carry both '
      'the date and the state text',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        );
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final dateLabel = mediumDateLabel(
          tester.element(find.byType(CareAdherenceCard)),
          DateTime(2026, 7, 22),
        );
        final expectedLabel = loc.careAdherenceHeatmapCellLabel(
          dateLabel,
          loc.careHistoryLegendFull,
        );

        expect(find.byTooltip(expectedLabel), findsOneWidget);
        expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'switching the period reloads the corresponding range, keeping the '
      'previous content visible with a progress indicator (no blanking)',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        );
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);
        expect(repository.getRangeCalls, [(from: '2026-07-16', to: '2026-07-22')]);

        final completer = Completer<void>();
        repository.getRangeCompleter = completer;

        final loc = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(loc.trendRange30));
        await tester.pump();

        // Mid-reload: previous heatmap/headline stay visible, plus a thin
        // progress indicator (no full-card blanking).
        expect(
          find.byKey(const Key('care-adherence-cell-2026-07-22')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-adherence-card-reloading')),
          findsOneWidget,
        );

        completer.complete();
        await tester.pumpAndSettle();

        expect(repository.getRangeCalls.last, (from: '2026-06-23', to: '2026-07-22'));
        expect(
          find.byKey(const Key('care-adherence-card-reloading')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an initial load error shows a retryable error, and retry reloads',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const [])
          ..getError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        expect(
          find.byKey(const Key('care-adherence-card-error')),
          findsOneWidget,
        );

        repository.getError = null;
        repository.days = _sevenDayRange();
        await tester.tap(find.byKey(const Key('care-adherence-card-retry')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('care-adherence-card-error')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('care-adherence-empty-state')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the error state keeps the title and the period selector, so a period '
      'that fails (typically the slowest, 90 days) is not a dead end — '
      'switching down reloads at the shorter period',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const [])
          ..getError = const CareRequestFailed();
        final controller = _controller(repository: repository, spanDays: 90);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.byKey(const Key('care-adherence-card-error')),
          findsOneWidget,
        );
        expect(find.text(loc.careAdherenceCardTitle), findsOneWidget);
        expect(
          find.byKey(const Key('care-adherence-range-selector')),
          findsOneWidget,
        );

        repository.getError = null;
        repository.days = _sevenDayRange(
          onJul22: [_slot(status: CareTodayStatus.done)],
        );
        await tester.tap(find.text(loc.trendRange7));
        await tester.pumpAndSettle();

        expect(controller.spanDays, 7);
        expect(
          repository.getRangeCalls.last,
          (from: '2026-07-16', to: '2026-07-22'),
        );
        expect(
          find.byKey(const Key('care-adherence-card-error')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows the empty state (no widen-period action — the card already has '
      'its own period picker) when every day in the period has nothing '
      'scheduled',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: _sevenDayRange()),
        );
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        expect(
          find.byKey(const Key('care-adherence-empty-state')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('care-adherence-heatmap')), findsNothing);
      },
    );

    testWidgets(
      'a controller wired with spanDays: 30 (the trend tab\'s wiring) shows '
      '30 selected and a 30-cell heatmap',
      (tester) async {
        final today = DateTime(2026, 7, 22);
        final range = dayRangeEndingOn(30, today);
        final days = [
          for (var i = 0; i < 30; i++)
            CareHistoryDay(
              date: dayString(
                parseDayString(range.from).add(Duration(days: i)),
              ),
              // One day has a done slot so the period isn't fully
              // unscheduled (an all-noSchedule period renders the empty
              // state instead of the heatmap — covered by its own test).
              slots: i == 29 ? [_slot(status: CareTodayStatus.done)] : const [],
            ),
        ];
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: days),
          spanDays: 30,
        );
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final selector = tester.widget<SegmentedButton<int>>(
          find.byKey(const Key('care-adherence-range-selector')),
        );
        expect(selector.selected, {30});
        expect(
          tester
              .widgetList(
                find.descendant(
                  of: find.byKey(const Key('care-adherence-heatmap')),
                  matching: find.byType(AspectRatio),
                ),
              )
              .length,
          30,
        );
      },
    );

    // Seeing "Missed 5" on the heatmap is exactly the moment a user wants to
    // go fix those records — but the record list lives on `/care-history`, a
    // top-level route with no link anywhere inside the health module. Without
    // an entry here the shortest path is More -> care management -> the
    // AppBar history icon -> and then widening that screen's period to match
    // the card's. The card is where the number is; the action belongs here.
    testWidgets(
      'the header offers a "view records" entry that opens the care history '
      'screen',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(
            days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
          ),
        );
        await controller.load('token-123');

        var opened = 0;
        await _pumpCard(tester, controller, onOpenHistory: () => opened++);

        await tester.tap(
          find.byKey(const Key('care-adherence-open-history')),
        );
        await tester.pumpAndSettle();

        expect(opened, 1);
      },
    );

    // The header is shared with the error state on purpose (see the period
    // selector's own test): a user whose load failed still has to be able to
    // reach the records.
    testWidgets(
      'the "view records" entry is available in the error state too',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: const [])
            ..getError = const CareRequestFailed(),
        );
        await controller.load('token-123');

        var opened = 0;
        await _pumpCard(tester, controller, onOpenHistory: () => opened++);

        expect(
          find.byKey(const Key('care-adherence-card-error')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('care-adherence-open-history')),
        );
        await tester.pumpAndSettle();

        expect(opened, 1);
      },
    );

    Future<void> expectDistinctUpcomingFill(
      WidgetTester tester,
      Future<void> Function(WidgetTester, CareHistoryController) pumpCard,
    ) async {
      final repository = _FakeCareHistoryRepository(
        days: _sevenDayRange(
          // 2026-07-22 (today): one pending slot, nothing done/skipped/
          // missed/overdue -> upcoming. 2026-07-20 has no slots ->
          // noSchedule.
          onJul22: [_slot(status: CareTodayStatus.pending)],
        ),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await pumpCard(tester, controller);

      final scheme = Theme.of(
        tester.element(find.byType(CareAdherenceCard)),
      ).colorScheme;

      Color cellColor(String key) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as BoxDecoration).color!;
      }

      final upcomingColor = cellColor('care-adherence-cell-2026-07-22');
      final noScheduleColor = cellColor('care-adherence-cell-2026-07-20');

      // Not the invisible fallback: this app's hand-written ColorScheme
      // never sets surfaceContainerHigh, so an unset role renders as
      // `surface` — exactly the enclosing LedgeCard's own fill.
      expect(upcomingColor, isNot(scheme.surface));
      // Distinct from the (unrelated) noSchedule cell.
      expect(upcomingColor, isNot(noScheduleColor));
    }

    // The legend is this card's non-color channel for a sighted touch user
    // (design §B accessibility): it only works if each swatch really is the
    // color of the cells it counts, if every state is actually visible
    // against the card it sits on, and if no two states collapse into each
    // other — in both themes.
    Future<void> expectLegendMatchesCellsAndStaysVisible(
      WidgetTester tester, {
      required ThemeData theme,
      ThemeData? darkTheme,
      ThemeMode? themeMode,
    }) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _allStatesRange()),
      );
      await controller.load('token-123');
      await _pumpCard(
        tester,
        controller,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
      );

      final loc = lookupAppLocalizations(const Locale('en'));
      final scheme = Theme.of(
        tester.element(find.byType(CareAdherenceCard)),
      ).colorScheme;
      final counts = careDayStateCounts(_allStatesRange());

      Color cellColor(String date) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(Key('care-adherence-cell-$date')),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as BoxDecoration).color!;
      }

      Color legendSwatchColor(CareDayState state) {
        final label = loc.careAdherenceLegendWithCount(
          _stateLabel(loc, state),
          counts[state]!,
        );
        final swatch = tester.widget<Container>(
          find.descendant(
            of: find.widgetWithText(Row, label),
            matching: find.byType(Container),
          ),
        );
        return (swatch.decoration! as BoxDecoration).color!;
      }

      for (final state in CareDayState.values) {
        expect(
          legendSwatchColor(state),
          cellColor(_dateForState[state]!),
          reason:
              'the $state legend swatch must be the same color as a $state '
              'heatmap cell',
        );
      }

      // *Every* state, not just the two translucent ones: checking a subset
      // is how the light theme's `partial` (1.28:1 against the card) slipped
      // through. As painted — a translucent fill composites onto the card.
      final fills = {
        for (final state in CareDayState.values)
          state: Color.alphaBlend(
            cellColor(_dateForState[state]!),
            scheme.surface,
          ),
      };

      for (final state in CareDayState.values) {
        expect(
          cellColor(_dateForState[state]!),
          isNot(scheme.surface),
          reason: '$state fill vs surface',
        );
        expect(
          _contrastRatio(fills[state]!, scheme.surface),
          greaterThanOrEqualTo(_minFillContrast),
          reason: '$state fill is not distinguishable from the card surface',
        );
      }

      // Pairwise: the heatmap is a ramp, not five hues. Five fills that each
      // clear the card but sit on top of each other still read as one blob
      // without color vision — light `full` vs `noSchedule` measured 1.01:1
      // before this guard existed.
      final states = CareDayState.values;
      for (var i = 0; i < states.length; i++) {
        for (var j = i + 1; j < states.length; j++) {
          expect(
            _contrastRatio(fills[states[i]]!, fills[states[j]]!),
            greaterThanOrEqualTo(_minFillContrast),
            reason:
                'the ${states[i]} and ${states[j]} fills are not '
                'distinguishable from each other',
          );
        }
      }
    }

    testWidgets(
      'every legend swatch matches its heatmap cell, and every state stays '
      'distinguishable from the card and from every other state — light '
      'theme',
      (tester) async {
        await expectLegendMatchesCellsAndStaysVisible(
          tester,
          theme: lightTheme,
        );
      },
    );

    testWidgets(
      'every legend swatch matches its heatmap cell, and every state stays '
      'distinguishable from the card and from every other state — dark '
      'theme',
      (tester) async {
        await expectLegendMatchesCellsAndStaysVisible(
          tester,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.dark,
        );
      },
    );

    testWidgets(
      'the upcoming heatmap cell has a real, distinct fill in the light '
      'theme (not the invisible surfaceContainerHigh fallback the theme '
      'never sets)',
      (tester) async {
        await expectDistinctUpcomingFill(
          tester,
          (tester, controller) => _pumpCard(tester, controller, theme: lightTheme),
        );
      },
    );

    testWidgets(
      'the upcoming heatmap cell has a real, distinct fill in the dark '
      'theme too',
      (tester) async {
        await expectDistinctUpcomingFill(
          tester,
          (tester, controller) => _pumpCard(
            tester,
            controller,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.dark,
          ),
        );
      },
    );
  });
}
