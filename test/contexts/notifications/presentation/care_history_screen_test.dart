import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/theme/app_theme.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'token-123';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

CareTodaySlot _withStatus(CareTodaySlot slot, CareTodayStatus status) =>
    CareTodaySlot(
      careItemId: slot.careItemId,
      careScheduleId: slot.careScheduleId,
      category: slot.category,
      title: slot.title,
      note: slot.note,
      dose: slot.dose,
      timeOfDay: slot.timeOfDay,
      localDate: slot.localDate,
      status: status,
      doneTime: slot.doneTime,
      doseQuantity: slot.doseQuantity,
    );

class _FakeCareHistoryRepository implements CareHistoryRepository {
  List<CareHistoryDay> days;
  Object? getError;
  Object? editError;
  Completer<void>? editCompleter;

  /// When set, the next [getRange] call awaits this before returning — lets
  /// a test hold a reload in flight to assert on the mid-reload UI state.
  Completer<void>? getRangeCompleter;
  final List<({String from, String to})> getRangeCalls = [];
  CareLogStatus? lastEditStatus;
  String? lastEditCareScheduleId;
  int editCallCount = 0;

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
  }) async {
    editCallCount++;
    lastEditStatus = status;
    lastEditCareScheduleId = careScheduleId;
    if (editCompleter != null) await editCompleter!.future;
    if (editError != null) throw editError!;
    days = [
      for (final day in days)
        CareHistoryDay(
          date: day.date,
          slots: [
            for (final s in day.slots)
              if (s.careScheduleId == careScheduleId &&
                  s.localDate == localDate &&
                  s.timeOfDay == timeOfDay)
                _withStatus(
                  s,
                  status == CareLogStatus.done
                      ? CareTodayStatus.done
                      : CareTodayStatus.skipped,
                )
              else
                s,
          ],
        ),
    ];
  }
}

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  String title = 'Metformin',
  CareTodayStatus status = CareTodayStatus.done,
  String timeOfDay = '08:00',
  String localDate = '2026-07-22',
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: title,
  timeOfDay: timeOfDay,
  localDate: localDate,
  status: status,
  doseQuantity: 1,
);

/// A dense 7-day range ending 2026-07-22 (matching the fixed test clock),
/// mirroring the backend's dense-array contract: every date gets an entry,
/// `items: []` when nothing was scheduled.
List<CareHistoryDay> _sevenDayRange({
  List<CareTodaySlot> onJul21 = const [],
  List<CareTodaySlot> onJul22 = const [],
}) => [
  const CareHistoryDay(date: '2026-07-16', slots: []),
  const CareHistoryDay(date: '2026-07-17', slots: []),
  const CareHistoryDay(date: '2026-07-18', slots: []),
  const CareHistoryDay(date: '2026-07-19', slots: []),
  const CareHistoryDay(date: '2026-07-20', slots: []),
  CareHistoryDay(date: '2026-07-21', slots: onJul21),
  CareHistoryDay(date: '2026-07-22', slots: onJul22),
];

CareHistoryController _controller({CareHistoryRepository? repository}) {
  final repo = repository ?? _FakeCareHistoryRepository(days: const []);
  return CareHistoryController(GetCareHistory(repo), EditCareSlot(repo));
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CareHistoryController controller, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode? themeMode,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nTestApp(
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: CareHistoryScreen(
        controller: controller,
        authRepository: _FakeAuthRepository(),
        clock: () => DateTime(2026, 7, 22),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('careHistoryRangeFor', () {
    test('span 7 is today-6..today', () {
      final range = careHistoryRangeFor(7, DateTime(2026, 7, 22));
      expect(range.from, '2026-07-16');
      expect(range.to, '2026-07-22');
    });

    test('span 30 is today-29..today', () {
      final range = careHistoryRangeFor(30, DateTime(2026, 7, 22));
      expect(range.from, '2026-06-23');
      expect(range.to, '2026-07-22');
    });

    test('span 90 is today-89..today', () {
      final range = careHistoryRangeFor(90, DateTime(2026, 7, 22));
      expect(range.from, '2026-04-24');
      expect(range.to, '2026-07-22');
    });
  });

  group('CareHistoryScreen', () {
    testWidgets(
      'list mode groups slots by day, newest first, skipping days with no '
      'slots',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul21: [
              _slot(
                careScheduleId: 'sch-done',
                title: 'Yesterday dose',
                status: CareTodayStatus.done,
                localDate: '2026-07-21',
              ),
            ],
            onJul22: [
              _slot(
                careScheduleId: 'sch-pending',
                title: 'Today dose',
                status: CareTodayStatus.pending,
                localDate: '2026-07-22',
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.byKey(const Key('care-history-day-header-2026-07-22')),
          findsOneWidget,
        );
        expect(find.text(loc.dietDayToday), findsOneWidget);
        expect(
          find.byKey(const Key('care-history-day-header-2026-07-21')),
          findsOneWidget,
        );
        // Days with no slots never render a group.
        expect(
          find.byKey(const Key('care-history-day-header-2026-07-20')),
          findsNothing,
        );
        expect(find.text('Yesterday dose'), findsOneWidget);
        expect(find.text('Today dose'), findsOneWidget);
        expect(find.text('08:00 · ${loc.careHistoryStatusPending}'), findsOneWidget);

        // Newest day rendered above the older day.
        final todayHeaderY = tester
            .getTopLeft(find.byKey(const Key('care-history-day-header-2026-07-22')))
            .dy;
        final yesterdayHeaderY = tester
            .getTopLeft(find.byKey(const Key('care-history-day-header-2026-07-21')))
            .dy;
        expect(todayHeaderY, lessThan(yesterdayHeaderY));
      },
    );

    testWidgets(
      'chart mode shows a headline and one heatmap cell per day in the span, '
      'including no-schedule days',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [_slot(status: CareTodayStatus.done)],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(loc.careHistoryChartMode));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('care-history-heatmap')), findsOneWidget);
        for (final date in [
          '2026-07-16',
          '2026-07-17',
          '2026-07-18',
          '2026-07-19',
          '2026-07-20',
          '2026-07-21',
          '2026-07-22',
        ]) {
          expect(find.byKey(Key('care-history-cell-$date')), findsOneWidget);
        }
        expect(find.byKey(const Key('care-history-adherence-rate')), findsOneWidget);
        expect(find.byKey(const Key('care-history-days-with-dose')), findsOneWidget);
        expect(find.byKey(const Key('care-history-missed-count')), findsOneWidget);
        // The legend's "Missed" (day-state) and the headline's "Missed"
        // (slot-count) are distinct i18n keys that happen to share English
        // text — scope the lookup to the legend so the two don't collide.
        final legendFinder = find.byKey(const Key('care-history-legend'));
        expect(
          find.descendant(of: legendFinder, matching: find.text(loc.careHistoryLegendFull)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: legendFinder, matching: find.text(loc.careHistoryLegendPartial)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: legendFinder, matching: find.text(loc.careHistoryLegendMissed)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(loc.careHistoryLegendNoSchedule),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: legendFinder,
            matching: find.text(loc.careHistoryLegendUpcoming),
          ),
          findsOneWidget,
        );
      },
    );

    /// Shared body for the "upcoming heatmap cell has a real, distinct fill"
    /// guard, pumped under whatever theme [pumpScreen] configures. Reads the
    /// *actually active* `ColorScheme` off the rendered tree (via
    /// `Theme.of`), so the assertions reflect real theme colors rather than
    /// Flutter's default Material theme (which — unlike this app's
    /// hand-written `ColorScheme` — defines `surfaceContainerHigh` distinctly
    /// from `surface`, and so would let the fallback-to-`surface` bug pass
    /// unnoticed).
    Future<void> expectDistinctUpcomingFill(
      WidgetTester tester,
      Future<void> Function(WidgetTester, CareHistoryController) pumpScreen,
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
      await pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(loc.careHistoryChartMode));
      await tester.pumpAndSettle();

      final scheme = Theme.of(
        tester.element(find.byType(CareHistoryScreen)),
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

      final upcomingColor = cellColor('care-history-cell-2026-07-22');
      final noScheduleColor = cellColor('care-history-cell-2026-07-20');

      // Not the invisible fallback: this app's hand-written ColorScheme
      // never sets surfaceContainerHigh, so an unset role renders as
      // `surface` — exactly the enclosing LedgeCard's own fill.
      expect(upcomingColor, isNot(scheme.surface));
      // Distinct from the (unrelated) noSchedule cell.
      expect(upcomingColor, isNot(noScheduleColor));

      // The legend swatch for "upcoming" renders the exact same color as
      // the heatmap cell.
      final legendDotContainer = tester
          .widgetList<Container>(
            find.descendant(
              of: find.ancestor(
                of: find.text(loc.careHistoryLegendUpcoming),
                matching: find.byType(Row),
              ),
              matching: find.byType(Container),
            ),
          )
          .first;
      expect(
        (legendDotContainer.decoration as BoxDecoration).color,
        upcomingColor,
      );
    }

    testWidgets(
      'the upcoming heatmap cell has a real, distinct fill in the light '
      'theme (not the invisible surfaceContainerHigh fallback the theme '
      'never sets), and the legend swatch matches the cell exactly',
      (tester) async {
        await expectDistinctUpcomingFill(
          tester,
          (tester, controller) =>
              _pumpScreen(tester, controller, theme: lightTheme),
        );
      },
    );

    testWidgets(
      'the upcoming heatmap cell has a real, distinct fill in the dark '
      'theme too, and the legend swatch matches the cell exactly',
      (tester) async {
        await expectDistinctUpcomingFill(
          tester,
          (tester, controller) => _pumpScreen(
            tester,
            controller,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.dark,
          ),
        );
      },
    );

    testWidgets(
      'switching the period reloads the corresponding range, keeping the '
      'previous content visible with a progress indicator (no blanking)',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [_slot(title: 'Today dose', status: CareTodayStatus.done)],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(repository.getRangeCalls, [(from: '2026-07-16', to: '2026-07-22')]);

        // Hold the 30-day reload in flight to assert the mid-reload state.
        final completer = Completer<void>();
        repository.getRangeCompleter = completer;

        final loc = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(loc.trendRange30));
        await tester.pump();

        // Mid-reload: previous content ("Today dose") is still visible, and
        // a thin progress indicator is shown instead of a full-page spinner.
        expect(find.text('Today dose'), findsOneWidget);
        expect(
          find.byKey(const Key('care-history-reloading')),
          findsOneWidget,
        );

        completer.complete();
        await tester.pumpAndSettle();

        expect(repository.getRangeCalls.last, (from: '2026-06-23', to: '2026-07-22'));
        expect(
          find.byKey(const Key('care-history-reloading')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping a slot opens a bottom sheet; choosing Done edits it without '
      'a full-page loading state',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [
              _slot(
                careScheduleId: 'sch-1',
                title: 'Metformin',
                status: CareTodayStatus.missed,
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryEditSheetTitle), findsOneWidget);
        expect(find.byKey(const Key('care-history-edit-done')), findsOneWidget);
        expect(find.byKey(const Key('care-history-edit-skip')), findsOneWidget);
        // The sheet header identifies which record is being edited — item
        // name, date, time, and current status — so tapping the wrong row
        // in a long list is noticeable.
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('care-history-edit-sheet-title')),
              )
              .data,
          'Metformin',
        );
        final expectedDate = mediumDateLabel(
          tester.element(find.byType(CareHistoryScreen)),
          DateTime(2026, 7, 22),
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('care-history-edit-sheet-subtitle')),
              )
              .data,
          '$expectedDate 08:00 · ${loc.careTodayStatusMissed}',
        );

        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pumpAndSettle();

        expect(repository.lastEditStatus, CareLogStatus.done);
        expect(repository.lastEditCareScheduleId, 'sch-1');
        expect(find.text('08:00 · ${loc.careHistoryStatusDone}'), findsOneWidget);
      },
    );

    testWidgets(
      'an edit that saves but fails to refresh shows the refresh-error '
      'message, not the generic (edit-failed) error',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        // The edit PUT succeeds, but the follow-up refresh GET fails.
        repository.getError = const CareRequestFailed();

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(loc.careHistoryEditRefreshErrorMessage),
          findsOneWidget,
        );
        expect(find.text(loc.careErrorGeneric), findsNothing);
      },
    );

    testWidgets(
      'editing shows an in-flight affordance on the row (and disables it), '
      'then a success confirmation once the edit and refresh both complete',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final completer = Completer<void>();
        repository.editCompleter = completer;

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        // Don't pumpAndSettle here — the in-flight progress indicator
        // animates indefinitely, so settle would never return.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(
            const Key('care-history-slot-editing-sch-1-2026-07-22-08:00'),
          ),
          findsOneWidget,
        );
        // The row can't be tapped again while its own edit is in flight.
        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pump();
        expect(find.byKey(const Key('care-history-edit-done')), findsNothing);

        completer.complete();
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryEditSuccessMessage), findsOneWidget);
        expect(
          find.byKey(
            const Key('care-history-slot-editing-sch-1-2026-07-22-08:00'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'does not throw when the screen is disposed while the edit sheet is '
      'still open (e.g. sign-out swapping the app to the login screen)',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        final showScreen = ValueNotifier<bool>(true);
        addTearDown(showScreen.dispose);

        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          l10nTestApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: showScreen,
              builder: (context, show, _) => show
                  ? CareHistoryScreen(
                      controller: controller,
                      authRepository: _FakeAuthRepository(),
                      clock: () => DateTime(2026, 7, 22),
                    )
                  : const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('care-history-edit-done')), findsOneWidget);

        // Swap the screen out from under the still-open sheet — this
        // disposes CareHistoryScreen's State while its `showModalBottomSheet`
        // await is still pending.
        showScreen.value = false;
        await tester.pump();

        // Resolving the sheet's await now must not throw.
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a fast double-tap that stacks edit sheets for two different slots '
      'keeps the in-flight affordance on the slot actually being edited — '
      "the second sheet's choice is dropped by its own re-check, not "
      "silently swallowed mid-setState by the controller's guard "
      '(which would otherwise leave the affordance on the wrong tile)',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [
              _slot(
                careScheduleId: 'sch-1',
                timeOfDay: '08:00',
                status: CareTodayStatus.missed,
              ),
              _slot(
                careScheduleId: 'sch-2',
                timeOfDay: '09:00',
                status: CareTodayStatus.missed,
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        // Hold the (first-dispatched) edit in flight so the second sheet's
        // choice resolves while it's still pending.
        final completer = Completer<void>();
        repository.editCompleter = completer;

        final sch1Finder = find.byKey(
          const Key('care-history-slot-sch-1-2026-07-22-08:00'),
        );
        final sch2Finder = find.byKey(
          const Key('care-history-slot-sch-2-2026-07-22-09:00'),
        );
        // Simulate a fast double-tap across two rows by invoking each
        // tile's onTap callback back-to-back with nothing in between: both
        // `_openEditSheet` calls run synchronously up to their first
        // `await`, pushing two stacked modal sheet routes before either one
        // has actually rendered (this can't be reproduced via `tester.tap`
        // here, since by the time a second simulated tap is dispatched the
        // first sheet's barrier already covers the tiles).
        final onTap1 = tester.widget<ListTile>(sch1Finder).onTap!;
        final onTap2 = tester.widget<ListTile>(sch2Finder).onTap!;
        onTap1();
        onTap2();
        await tester.pumpAndSettle();

        // Both stacked sheets' content stay in the widget tree (the bottom
        // one just visually obscured), so two 'Done' tiles are found; only
        // the top one (`.last`, painted last — sch-2's, pushed second) is
        // actually hit-testable. Choose Done there first.
        expect(find.byKey(const Key('care-history-edit-done')), findsNWidgets(2));
        await tester.tap(find.byKey(const Key('care-history-edit-done')).last);
        // Don't settle — the edit is now held in flight by the completer.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.editing, isTrue);
        expect(repository.editCallCount, 1);
        expect(repository.lastEditCareScheduleId, 'sch-2');
        // The in-flight affordance is on sch-2's row — the slot actually
        // being edited.
        expect(
          find.byKey(
            const Key('care-history-slot-editing-sch-2-2026-07-22-09:00'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('care-history-slot-editing-sch-1-2026-07-22-08:00'),
          ),
          findsNothing,
        );

        // The sch-1 sheet is now revealed underneath; choose Done there
        // too. This must be dropped — sch-2's edit is still in flight —
        // without disturbing which row shows the in-flight affordance.
        expect(find.byKey(const Key('care-history-edit-done')), findsOneWidget);
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Still only the one edit dispatched, still for sch-2.
        expect(repository.editCallCount, 1);
        expect(repository.lastEditCareScheduleId, 'sch-2');
        // The affordance is still on sch-2's row, not sch-1's — had the
        // sch-1 sheet's choice not been re-checked after its own await, it
        // would have overwritten `_editingSlotKey` to sch-1 right before
        // the controller's own guard silently no-op'd its `edit()` call,
        // leaving the affordance stuck on the wrong (idle) row.
        expect(
          find.byKey(
            const Key('care-history-slot-editing-sch-2-2026-07-22-09:00'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('care-history-slot-editing-sch-1-2026-07-22-08:00'),
          ),
          findsNothing,
        );

        completer.complete();
        await tester.pumpAndSettle();
        expect(repository.editCallCount, 1);
      },
    );

    testWidgets('a failed edit shows a SnackBar and keeps the list', (
      tester,
    ) async {
      final repository = _FakeCareHistoryRepository(
        days: _sevenDayRange(
          onJul22: [_slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed)],
        ),
      )..editError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await tester.tap(
        find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-history-edit-done')));
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careErrorGeneric), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      // The (unedited) slot is still shown.
      expect(
        find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        findsOneWidget,
      );
    });

    testWidgets(
      'an edit PUT that requires reauth shows the reauth exit, not the '
      'success SnackBar',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [
              _slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed),
            ],
          ),
        )..editError = const CareReauthRequired();
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pumpAndSettle();

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
        expect(find.text(loc.careHistoryEditSuccessMessage), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('shows the empty-state guide when every day has no slots', (
      tester,
    ) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _sevenDayRange()),
      );
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-history-empty-state')), findsOneWidget);
    });

    testWidgets('a load reauth failure shows the full-screen reauth exit', (
      tester,
    ) async {
      final repository = _FakeCareHistoryRepository(days: const [])
        ..getError = const CareReauthRequired();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
    });

    testWidgets('a load failure shows a retry button that reloads', (
      tester,
    ) async {
      final repository = _FakeCareHistoryRepository(days: const [])
        ..getError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-history-load-error')), findsOneWidget);

      repository.getError = null;
      repository.days = _sevenDayRange();
      await tester.tap(find.byKey(const Key('care-history-retry-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-history-empty-state')), findsOneWidget);
    });
  });
}
