import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
    DateTime? doneTime,
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

/// Every label in the semantics tree the framework actually hands to the
/// platform, walked from `rootSemanticsNode` down.
///
/// Deliberately **not** `tester.getSemantics` / `find.bySemanticsLabel`:
/// both read the render object's cached `debugSemantics`, which survives
/// even when the node is dropped from its parent's children on the way out
/// (`RenderObject`'s `children.removeWhere(shouldDrop)`, where
/// `shouldDrop == node.isInvisible == !isMergedIntoParent && rect.isEmpty`).
/// A `Semantics(label: …, child: SizedBox.shrink())` is exactly that case —
/// zero-sized, so never announced — and both of those finders report it as
/// present anyway. Only the real tree can tell the difference.
List<String> _platformSemanticsLabels(WidgetTester tester) {
  // The view's own PipelineOwner (a child of the root one) is what holds the
  // SemanticsOwner; `binding.pipelineOwner` is deprecated.
  SemanticsNode? rootNode;
  tester.binding.rootPipelineOwner.visitChildren((child) {
    rootNode ??= child.semanticsOwner?.rootSemanticsNode;
  });
  final root = rootNode!;
  final labels = <String>[];
  void visit(SemanticsNode node) {
    labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return labels;
}

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
  VoidCallback? onOpenCareItems,
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
          idToken: () async => 'token-123',
          onOpenHistory: onOpenHistory ?? () {},
          onOpenCareItems: onOpenCareItems ?? () {},
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
                idToken: () async => 'token-123',
                onOpenHistory: () {},
                onOpenCareItems: () {},
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

    // design D1: `Tooltip` sets its `message` as `SemanticsProperties.tooltip`
    // on the *same merged node* the cell's own `Semantics(label:)` produces
    // (Tooltip only introduces a second node when explicitly excluded), so a
    // screen reader announces the cell twice — once for the label, once for
    // the tooltip. `find.byTooltip`/`find.bySemanticsLabel` above stay green
    // either way (they inspect the widget tree / the label text, not whether
    // `tooltip` is also merged in), so they can't catch a regression here —
    // this test reads the merged SemanticsNode's `tooltip` field directly.
    testWidgets(
      'a heatmap cell is announced once: its tooltip message is not also '
      'merged onto the semantics node as a tooltip (excludeFromSemantics)',
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

        final cell = find.byKey(const Key('care-adherence-cell-2026-07-22'));
        final data = tester.getSemantics(cell);
        expect(data.label, expectedLabel);
        expect(data.tooltip, isEmpty);
        handle.dispose();
      },
    );

    // design D1. Two things this has to prove, neither of which
    // `tester.getSemantics`/`find.bySemanticsLabel` can (they read the render
    // object's cached `debugSemantics`, see [_platformSemanticsLabels]):
    //   1. the summary really reaches the *platform* semantics tree — the
    //      previous `Semantics(label: …, child: SizedBox.shrink())` did not,
    //      because a zero-rect node is `isInvisible` and gets dropped from
    //      its parent's children before the tree is sent out;
    //   2. it is announced *before* the grid — asserted on the semantics
    //      node's own rect, not the widget's (the old widget-geometry
    //      assertion only held because the shrink-wrapped summary had zero
    //      height and the weekday header happened to sit between).
    testWidgets(
      'the per-state summary is a real node in the platform semantics tree, '
      'positioned above the heatmap grid, and each cell still keeps its own '
      "label (D1's chosen option — not a single collapsed node)",
      (tester) async {
        final handle = tester.ensureSemantics();
        final repository = _FakeCareHistoryRepository(days: _allStatesRange());
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final counts = careDayStateCounts(_allStatesRange());
        final details = CareDayState.values
            .where((s) => counts[s]! > 0)
            .map(
              (s) => loc.careAdherenceLegendWithCount(_stateLabel(loc, s), counts[s]!),
            )
            .join(loc.careAdherenceHeatmapSummarySeparator);
        final expectedSummary = loc.careAdherenceHeatmapSummaryLabel(details);

        expect(
          _platformSemanticsLabels(tester),
          contains(expectedSummary),
          reason:
              'the summary must survive as its own node in the tree sent to '
              'the platform — a zero-sized one is dropped and never announced',
        );

        // Announced before the grid: the summary's own semantics rect sits
        // above the first cell's.
        final summaryRect = tester.getRect(
          find.byKey(const Key('care-adherence-heatmap-summary')),
        );
        final gridRect = tester.getRect(
          find.byKey(const Key('care-adherence-heatmap')),
        );
        expect(summaryRect.height, greaterThan(0));
        expect(summaryRect.bottom, lessThanOrEqualTo(gridRect.top));

        // Every cell still carries its own label — the summary supplements
        // rather than replaces per-cell semantics.
        final cellLabel = loc.careAdherenceHeatmapCellLabel(
          mediumDateLabel(
            tester.element(find.byType(CareAdherenceCard)),
            DateTime(2026, 7, 17),
          ),
          loc.careHistoryLegendFull,
        );
        expect(_platformSemanticsLabels(tester), contains(cellLabel));
        handle.dispose();
      },
    );

    // The summary and the legend carried word-for-word identical text, so a
    // screen reader read all five states twice — plus seven context-free
    // weekday letters from the header (every cell's own label already spells
    // out its full date). The summary is the one that stays.
    testWidgets(
      'the legend and the weekday header contribute nothing to the semantics '
      'tree, so no state is announced twice',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repository = _FakeCareHistoryRepository(days: _allStatesRange());
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final counts = careDayStateCounts(_allStatesRange());
        final labels = _platformSemanticsLabels(tester);

        for (final state in CareDayState.values) {
          final legendText = loc.careAdherenceLegendWithCount(
            _stateLabel(loc, state),
            counts[state]!,
          );
          expect(
            labels.where((l) => l == legendText),
            isEmpty,
            reason: 'the $state legend entry must not be its own semantics node',
          );
        }

        // The weekday header's seven one-letter abbreviations are gone too.
        final context = tester.element(find.byType(CareAdherenceCard));
        for (var i = 0; i < 7; i++) {
          final letter = narrowWeekdayLabel(context, DateTime(2026, 7, 16 + i));
          expect(labels.where((l) => l == letter), isEmpty);
        }
        handle.dispose();
      },
    );

    // Announcing "Partial (0), Missed (0), Upcoming (0)" is pure noise in a
    // linear read-out, and the separator must come from the ARB: Chinese
    // wraps its counts in full-width parentheses, which an ASCII ", " clashes
    // with mid-sentence.
    testWidgets(
      'the summary lists only the states that actually occurred, joined by '
      "the locale's own separator",
      (tester) async {
        final handle = tester.ensureSemantics();
        final repository = _FakeCareHistoryRepository(
          // full: 1, noSchedule: 6, everything else 0.
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        );
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final expected = loc.careAdherenceHeatmapSummaryLabel(
          loc.careAdherenceLegendWithCount(loc.careHistoryLegendFull, 1) +
              loc.careAdherenceHeatmapSummarySeparator +
              loc.careAdherenceLegendWithCount(
                loc.careHistoryLegendNoSchedule,
                6,
              ),
        );
        // Exact string equality against a summary naming only `full` and
        // `noSchedule`: re-adding the three zero-count states (or swapping
        // the separator back to a hard-coded ', ') breaks it.
        expect(_platformSemanticsLabels(tester), contains(expected));
        handle.dispose();
      },
    );

    testWidgets(
      'the summary separator is the ideographic comma in Chinese, not an '
      'ASCII ", " next to full-width parentheses',
      (tester) async {
        const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
        final handle = tester.ensureSemantics();
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        );
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          l10nTestApp(
            locale: zhHant,
            home: Scaffold(
              body: CareAdherenceCard(
                controller: controller,
                idToken: () async => 'token-123',
                onOpenHistory: () {},
                onOpenCareItems: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(zhHant);
        expect(loc.careAdherenceHeatmapSummarySeparator, '、');
        final expected = loc.careAdherenceHeatmapSummaryLabel(
          '${loc.careAdherenceLegendWithCount(loc.careHistoryLegendFull, 1)}'
          '、'
          '${loc.careAdherenceLegendWithCount(loc.careHistoryLegendNoSchedule, 6)}',
        );
        expect(_platformSemanticsLabels(tester), contains(expected));
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

    // task 4.3/4.4: the error text names the failed period, so the retained
    // period selector reads as a way out rather than an unrelated control —
    // and the substituted text must not be built by splicing the already-
    // localized trendRange7/30/90 button copy into another sentence (word
    // order and quantifiers differ between English and Chinese).
    testWidgets(
      'the error message names the period (in days) that failed',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const [])
          ..getError = const CareRequestFailed();
        final controller = _controller(repository: repository, spanDays: 30);
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careErrorForPeriod(30)), findsOneWidget);
        expect(find.text(loc.careErrorGeneric), findsNothing);
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

        // The copy has to match the only action on offer ("go to care
        // management"): a period-scoped "nothing was scheduled in this
        // period" next to a configure-your-items button is the mismatch the
        // care history screen's own empty state already fixed. This card has
        // its own period picker, so widening isn't the story here either.
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryNoCareItemsTitle), findsOneWidget);
        expect(find.text(loc.careHistoryNoCareItemsBody), findsOneWidget);
        expect(find.text(loc.careHistoryEmptyTitle), findsNothing);
        expect(find.text(loc.careHistoryEmptyBody), findsNothing);
      },
    );

    // task 4.3: the card has no callback pointed at care management (only
    // `onOpenHistory`, which opens the record list, not the item-management
    // screen) — the empty state needs its own, separate one. Wiring it to
    // `onOpenHistory` would open the wrong screen for a user who has no care
    // items at all.
    testWidgets(
      'the empty state offers going to care management, via its own '
      'callback distinct from onOpenHistory',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: _sevenDayRange()),
        );
        await controller.load('token-123');

        var historyOpened = 0;
        var careItemsOpened = 0;
        await _pumpCard(
          tester,
          controller,
          onOpenHistory: () => historyOpened++,
          onOpenCareItems: () => careItemsOpened++,
        );

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryEmptyManageButton), findsOneWidget);
        await tester.tap(find.text(loc.careHistoryEmptyManageButton));
        await tester.pumpAndSettle();

        expect(careItemsOpened, 1);
        expect(historyOpened, 0);
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

    // design D2/D3: 7 fixed columns (so the same column is always the same
    // weekday), each cell capped at 24dp and the grid left-aligned rather
    // than stretched to the card's full content width; a weekday header
    // above it and a start–end date caption below it (both sourced from
    // sortedDays.first/last — the card has no clock of its own); today's
    // cell visually distinguishable from the rest.
    testWidgets(
      'the heatmap lays out fixed 7-column rows capped at 24dp, left-aligned, '
      "with a weekday header above and a start–end caption below, and today's "
      'cell is visually distinguishable from the others',
      (tester) async {
        final today = DateTime(2026, 7, 22);
        final range = dayRangeEndingOn(9, today);
        final firstDate = parseDayString(range.from);
        final days = [
          for (var i = 0; i < 9; i++)
            CareHistoryDay(
              date: dayString(firstDate.add(Duration(days: i))),
              // One day has a done slot so the period isn't fully
              // unscheduled (an all-noSchedule period renders the empty
              // state instead of the heatmap — covered by its own test).
              slots: i == 8 ? [_slot(status: CareTodayStatus.done)] : const [],
            ),
        ];
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: days),
          spanDays: 9,
        );
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        // 格數仍 = 期間天數: 9 cells total.
        expect(
          tester
              .widgetList(
                find.descendant(
                  of: find.byKey(const Key('care-adherence-heatmap')),
                  matching: find.byType(AspectRatio),
                ),
              )
              .length,
          9,
        );

        // Every row has exactly 7 columns: the 7th cell (index 6, last of
        // row 0) sits on the same row as the 1st; the 8th (index 7, first
        // of row 1) sits on the next row down, at the same left edge.
        Rect cellRect(String date) =>
            tester.getRect(find.byKey(Key('care-adherence-cell-$date')));
        final firstCell = cellRect(days[0].date);
        final seventhCell = cellRect(days[6].date);
        final eighthCell = cellRect(days[7].date);
        expect(seventhCell.top, closeTo(firstCell.top, 0.5));
        expect(eighthCell.top, greaterThan(firstCell.top));
        expect(eighthCell.left, closeTo(firstCell.left, 0.5));

        // Each cell is exactly the 24dp cap (test surface: 800dp-wide card,
        // 756dp content width — 7 uncapped columns would be ~105dp each).
        // An exact assertion, not an upper bound: a degenerate 8dp cell
        // would satisfy `<= 24.5` while being unreadable.
        expect(firstCell.width, closeTo(24, 0.01));
        expect(firstCell.height, closeTo(24, 0.01));

        // The grid is left-aligned, not stretched to the card's full content
        // width (756dp) — and exactly 24×7 + 3×6 = 186dp wide, so neither a
        // 6- nor an 8-column layout can pass.
        final heatmapRect = tester.getRect(
          find.byKey(const Key('care-adherence-heatmap')),
        );
        expect(heatmapRect.width, closeTo(186, 0.01));

        // A weekday header sits above the grid, one abbreviation per
        // column, in order starting from the first day's weekday.
        final context = tester.element(find.byType(CareAdherenceCard));
        final headerFinder = find.byKey(
          const Key('care-adherence-heatmap-weekday-header'),
        );
        expect(headerFinder, findsOneWidget);
        expect(
          tester.getTopLeft(headerFinder).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('care-adherence-heatmap'))).dy),
        );
        final headerTexts = tester
            .widgetList<Text>(
              find.descendant(of: headerFinder, matching: find.byType(Text)),
            )
            .map((t) => t.data)
            .toList();
        // Literal expectations, not the same `narrowWeekdayLabel(firstDate
        // .add(Duration(days: i)))` expression the widget uses — an
        // expected value computed by the code under test proves nothing (and
        // is exactly how the DST-unsafe `Duration` arithmetic stayed green).
        // 2026-07-14 is a Tuesday, so the nine-day period's columns run
        // Tue Wed Thu Fri Sat Sun Mon.
        expect(firstDate, DateTime(2026, 7, 14));
        expect(headerTexts, ['T', 'W', 'T', 'F', 'S', 'S', 'M']);

        // A start–end date caption sits below the grid.
        final fromLabel = mediumDateLabel(context, firstDate);
        final toLabel = mediumDateLabel(
          context,
          parseDayString(days.last.date),
        );
        final captionFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains(fromLabel) &&
              widget.data!.contains(toLabel),
        );
        expect(captionFinder, findsOneWidget);
        expect(
          tester.getTopLeft(captionFinder).dy,
          greaterThanOrEqualTo(heatmapRect.bottom),
        );

        // Today's cell (the last day, 2026-07-22) has a border
        // distinguishable from an ordinary cell's — not color alone.
        BoxBorder borderOf(String date) {
          final box = tester.widget<DecoratedBox>(
            find.descendant(
              of: find.byKey(Key('care-adherence-cell-$date')),
              matching: find.byType(DecoratedBox),
            ),
          );
          return (box.decoration as BoxDecoration).border!;
        }

        final todayBorder = borderOf(days.last.date) as Border;
        final otherBorder = borderOf(days.first.date) as Border;
        expect(
          todayBorder.top.width != otherBorder.top.width ||
              todayBorder.top.color != otherBorder.top.color,
          isTrue,
        );
      },
    );

    // "Today, already complete" is the commonest state to look at in the
    // evening, and the dark theme is a shipping path (`app.dart` wires a
    // `darkTheme`). The generic "today's border differs from an ordinary
    // cell's" assertion above has no discriminating power there: the dark
    // theme's `full` fill *is* `scheme.primary`, so a primary today-outline
    // measured 1.000 against the very cell it was outlining. The border has
    // to be visible against today's own fill, whatever that fill is.
    Future<void> expectTodayOutlineVisibleAgainstItsOwnFill(
      WidgetTester tester, {
      required ThemeData theme,
      ThemeData? darkTheme,
      ThemeMode? themeMode,
      required Brightness expectedBrightness,
    }) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(
          // The last (and therefore "today") day is `full`.
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        ),
      );
      await controller.load('token-123');
      await _pumpCard(
        tester,
        controller,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
      );

      final scheme = Theme.of(
        tester.element(find.byType(CareAdherenceCard)),
      ).colorScheme;
      expect(scheme.brightness, expectedBrightness);

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(
                        const Key('care-adherence-cell-2026-07-22'),
                      ),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final border = decoration.border! as Border;
      final fill = Color.alphaBlend(decoration.color!, scheme.surface);
      final stroke = Color.alphaBlend(border.top.color, fill);

      expect(border.top.width, 2, reason: "this must be today's cell");
      expect(
        border.top.color,
        isNot(decoration.color),
        reason: "today's outline must not be its own fill color",
      );
      expect(
        _contrastRatio(stroke, fill),
        greaterThanOrEqualTo(_minFillContrast),
        reason:
            "today's outline is not distinguishable from the fill it "
            'outlines',
      );
    }

    testWidgets(
      "today's outline stays visible against its own fill when today is "
      'already complete — dark theme',
      (tester) async {
        await expectTodayOutlineVisibleAgainstItsOwnFill(
          tester,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.dark,
          expectedBrightness: Brightness.dark,
        );
      },
    );

    testWidgets(
      "today's outline stays visible against its own fill when today is "
      'already complete — light theme',
      (tester) async {
        await expectTodayOutlineVisibleAgainstItsOwnFill(
          tester,
          theme: lightTheme,
          expectedBrightness: Brightness.light,
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

    // design D4 / task 4.9: `day.date` is backend-sourced per day — the
    // sixth of the six D4 call sites, and the one where a malformed value
    // is most dangerous: unlike the other five, this one sits inside a
    // `GridView.builder` loop, so an uncaught parse failure here previously
    // took down the *entire* heatmap, not just one cell.
    testWidgets(
      "a malformed date on one day within the period doesn't crash the "
      'heatmap — that cell falls back to "—" for its date label while every '
      'other cell renders normally',
      (tester) async {
        final days = [
          for (var i = 0; i < 6; i++)
            CareHistoryDay(
              date: dayString(DateTime(2026, 7, 17 + i)),
              // One day has a done slot so the period isn't fully
              // unscheduled (an all-noSchedule period renders the empty
              // state instead of the heatmap — covered by its own test).
              slots: i == 5
                  ? [_slot(status: CareTodayStatus.done, localDate: '2026-07-22')]
                  : const [],
            ),
          // Sorts after every well-formed 'YYYY-MM-DD' string ('n' > '2'),
          // so this becomes the "today" cell.
          const CareHistoryDay(date: 'not-a-date', slots: []),
        ];
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: days),
          spanDays: 7,
        );
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('care-adherence-cell-not-a-date')),
          findsOneWidget,
        );
        // Every other (well-formed) cell still renders normally.
        for (final date in [
          '2026-07-17',
          '2026-07-18',
          '2026-07-19',
          '2026-07-20',
          '2026-07-21',
          '2026-07-22',
        ]) {
          expect(find.byKey(Key('care-adherence-cell-$date')), findsOneWidget);
        }
      },
    );

    // design D4 / task 4.9: the *first* day drives the weekday header and
    // the range caption's "from" label — a malformed value there must not
    // take down the header/caption either.
    testWidgets(
      "a malformed date on the earliest day in the period doesn't crash the "
      'heatmap — the weekday header and range caption fall back to "—" for '
      'that day',
      (tester) async {
        final days = [
          // Sorts before every well-formed 'YYYY-MM-DD' string ('!' < '2').
          const CareHistoryDay(date: '!bad-date', slots: []),
          for (var i = 0; i < 6; i++)
            CareHistoryDay(
              date: dayString(DateTime(2026, 7, 17 + i)),
              slots: i == 5
                  ? [_slot(status: CareTodayStatus.done, localDate: '2026-07-22')]
                  : const [],
            ),
        ];
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: days),
          spanDays: 7,
        );
        await controller.load('token-123');

        await _pumpCard(tester, controller);

        expect(tester.takeException(), isNull);

        final headerFinder = find.byKey(
          const Key('care-adherence-heatmap-weekday-header'),
        );
        final headerTexts = tester
            .widgetList<Text>(
              find.descendant(of: headerFinder, matching: find.byType(Text)),
            )
            .map((t) => t.data)
            .toList();
        expect(headerTexts.length, 7);
        expect(headerTexts.first, '—');

        final context = tester.element(find.byType(CareAdherenceCard));
        final loc = lookupAppLocalizations(const Locale('en'));
        final toLabel = mediumDateLabel(context, DateTime(2026, 7, 22));
        expect(
          find.text(loc.careAdherenceHeatmapRangeCaption('—', toLabel)),
          findsOneWidget,
        );
      },
    );
  });
}
