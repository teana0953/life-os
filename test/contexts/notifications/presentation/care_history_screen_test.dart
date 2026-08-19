import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history_filter.dart';
import 'package:life_os/contexts/notifications/domain/care_history_period.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/data_revision.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  /// When set, [idToken] awaits this instead of resolving immediately —
  /// lets a test hold the token resolution in flight (task 4.7).
  Completer<String?>? idTokenCompleter;

  /// What [idToken] resolves to once it is not held. Mutable so a test can
  /// simulate Firebase renewing the token while the screen stays open.
  String token;

  _FakeAuthRepository({this.token = 'token-123'});

  @override
  Future<String?> idToken() async {
    final completer = idTokenCompleter;
    if (completer != null) return completer.future;
    return token;
  }

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

  /// Every id token [getRange] / [editSlot] were called with, in order — the
  /// *value that was sent*, which is what the token-freshness test asserts on.
  final List<String> getRangeTokens = [];
  final List<String> editTokens = [];

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
    getRangeTokens.add(idToken);
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
  }) async {
    editTokens.add(idToken);
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
  String careItemId = 'care-1',
  String careScheduleId = 'sch-1',
  String title = 'Metformin',
  CareCategory category = CareCategory.medication,
  CareTodayStatus status = CareTodayStatus.done,
  String timeOfDay = '08:00',
  String localDate = '2026-07-22',
}) => CareTodaySlot(
  careItemId: careItemId,
  careScheduleId: careScheduleId,
  category: category,
  title: title,
  timeOfDay: timeOfDay,
  localDate: localDate,
  status: status,
  doseQuantity: 1,
);

/// A two-item, two-category range: Metformin (medication) done on both days,
/// Walk (rehab) missed on the 21st and done on the 22nd. Deliberately not
/// symmetric — every headline number differs between the unfiltered range
/// and the rehab-only slice, so a summary that ignored the filter would show
/// up in all three of them rather than in none.
List<CareHistoryDay> _twoItemRange() => _sevenDayRange(
  onJul21: [
    _slot(localDate: '2026-07-21'),
    _slot(
      careItemId: 'care-2',
      careScheduleId: 'sch-2',
      title: 'Walk',
      category: CareCategory.rehab,
      status: CareTodayStatus.missed,
      timeOfDay: '18:00',
      localDate: '2026-07-21',
    ),
  ],
  onJul22: [
    _slot(),
    _slot(
      careItemId: 'care-2',
      careScheduleId: 'sch-2',
      title: 'Walk',
      category: CareCategory.rehab,
      timeOfDay: '18:00',
    ),
  ],
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

// Pinned to the same date as `_pumpScreen`'s `clock: () => DateTime(2026, 7,
// 22)` — the screen's own clock now only drives the "today" header (design
// §A), while the controller's clock drives the loaded range, so the two
// must be pinned together or the range and the "today" header would
// disagree about which day is today.
CareHistoryController _controller({
  CareHistoryRepository? repository,
  int spanDays = 7,
}) {
  final repo = repository ?? _FakeCareHistoryRepository(days: const []);
  return CareHistoryController(
    GetCareHistory(repo),
    EditCareSlot(repo),
    DataRevision(),
    period: CareHistoryPeriod.span(spanDays),
    clock: () => DateTime(2026, 7, 22),
  );
}

// A router-backed app (not the plain l10nTestApp) so the AppBar overflow
// menu's context.push('/care-today')/context.push('/care-items') resolve —
// mirrors care_items_screen_test.dart's / care_today_screen_test.dart's
// pattern of asserting on the pushed route via the matched-location text.
/// Like [_pumpScreen] but at a real narrow phone viewport instead of the
/// 800×1600 test surface, for the narrow-screen guards below.
Future<void> _pumpNarrow(
  WidgetTester tester,
  CareHistoryController controller,
  Locale locale,
) async {
  useTextScaleFactor(tester, 2.0);
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nRouterTestApp(
      locale: locale,
      home: CareHistoryScreen(
        controller: controller,
        authRepository: _FakeAuthRepository(),
        clock: () => DateTime(2026, 7, 22),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  CareHistoryController controller, {
  _FakeAuthRepository? authRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    l10nRouterTestApp(
      home: CareHistoryScreen(
        controller: controller,
        authRepository: authRepository ?? _FakeAuthRepository(),
        clock: () => DateTime(2026, 7, 22),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Settles the tree, or — when a request is deliberately held in flight —
/// advances it by fixed durations instead. `pumpAndSettle` never returns
/// while the reload's thin progress bar is animating, so a test that holds a
/// GET open has to pump by hand; 400ms clears the sheet's own 250ms
/// open/close animation either way.
Future<void> _settleOrPump(WidgetTester tester, bool settle) async {
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Switches to the [days]-day rolling span the way a user does: open the
/// period control, tap that option in the sheet. The 7/30/90 spans are no
/// longer buttons on the screen itself, so no test can tap them directly.
Future<void> selectSpan(
  WidgetTester tester,
  int days, {
  bool settle = true,
}) async {
  await tester.tap(find.byKey(const Key('care-history-period-button')));
  await _settleOrPump(tester, settle);
  await tester.tap(find.byKey(Key('care-history-period-option-$days')));
  await _settleOrPump(tester, settle);
}

/// Opens the date-range picker the way a user does: period control → the
/// sheet's custom row.
Future<void> openCustomPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('care-history-period-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('care-history-period-option-custom')));
  await tester.pumpAndSettle();
}

void main() {
  group('CareHistoryScreen', () {
    // This screen used to fetch one token in `_load` and cache it in a field,
    // reusing it for every period switch and every edit. Asserts on the token
    // the repository RECEIVED, not on the provider having been called.
    testWidgets(
      'a period switch after a token renewal carries the new token',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [_slot(title: 'Today dose', status: CareTodayStatus.done)],
          ),
        );
        final auth = _FakeAuthRepository(token: 'token-1');
        await _pumpScreen(
          tester,
          _controller(repository: repository),
          authRepository: auth,
        );

        expect(repository.getRangeTokens, ['token-1']);

        // Firebase renewed the token while the history stayed open.
        auth.token = 'token-2';

        await selectSpan(tester, 90);

        expect(repository.getRangeTokens, ['token-1', 'token-2']);
      },
    );

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
      "today's slot has an edit icon and opens the edit sheet, but a slot "
      'from an earlier day has no edit icon and tapping it does nothing '
      '(design §D — corrections for earlier days belong on the Today care '
      'checklist instead)',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul21: [
              _slot(
                careScheduleId: 'sch-yesterday',
                title: 'Yesterday dose',
                status: CareTodayStatus.missed,
                localDate: '2026-07-21',
              ),
            ],
            onJul22: [
              _slot(
                careScheduleId: 'sch-today',
                title: 'Today dose',
                status: CareTodayStatus.missed,
                localDate: '2026-07-22',
              ),
            ],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final todayTileKey = const Key(
          'care-history-slot-sch-today-2026-07-22-08:00',
        );
        final yesterdayTileKey = const Key(
          'care-history-slot-sch-yesterday-2026-07-21-08:00',
        );
        expect(find.byKey(todayTileKey), findsOneWidget);
        expect(find.byKey(yesterdayTileKey), findsOneWidget);

        // Only today's tile shows the edit icon.
        expect(
          find.descendant(
            of: find.byKey(todayTileKey),
            matching: find.byIcon(Icons.edit_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(yesterdayTileKey),
            matching: find.byIcon(Icons.edit_outlined),
          ),
          findsNothing,
        );

        // The earlier day's card says *why* its rows are inert. Without it a
        // returning user taps a past row and gets nothing at all — no icon,
        // no sheet, no explanation — and there is no other screen left that
        // can correct an earlier day.
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(
          find.byKey(const Key('care-history-read-only-hint-2026-07-21')),
          findsOneWidget,
        );
        expect(find.text(loc.careHistoryPastReadOnlyHint), findsOneWidget);
        // Today's card is editable, so it must not carry the note.
        expect(
          find.byKey(const Key('care-history-read-only-hint-2026-07-22')),
          findsNothing,
        );

        // Tapping the earlier day's tile does not open the edit sheet.
        await tester.tap(find.byKey(yesterdayTileKey));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('care-history-edit-done')), findsNothing);

        // Today's tile still opens it.
        await tester.tap(find.byKey(todayTileKey));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('care-history-edit-done')), findsOneWidget);
      },
    );

    testWidgets(
      'has no list/chart mode toggle and no heatmap/legend/headline — the '
      'chart moved to the health module\'s trends tab (CareAdherenceCard)',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [_slot(status: CareTodayStatus.done)],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('care-history-mode-toggle')),
          findsNothing,
        );
        expect(find.byKey(const Key('care-history-heatmap')), findsNothing);
        expect(find.byKey(const Key('care-history-legend')), findsNothing);
        expect(
          find.byKey(const Key('care-history-adherence-rate')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('care-history-days-with-dose')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('care-history-missed-count')),
          findsNothing,
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

        await selectSpan(tester, 30, settle: false);

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

    // The tile's edit icon otherwise reads to a screen reader as a bare,
    // unlabelled "button" — a verb label ("Edit"), not the sheet's own
    // noun-phrase title (careHistoryEditSheetTitle, "Update this record").
    testWidgets(
      "an editable slot's edit icon carries an assistive-technology label",
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [_slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed)],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(
              const Key('care-history-slot-sch-1-2026-07-22-08:00'),
            ),
            matching: find.byIcon(Icons.edit_outlined),
          ),
        );
        expect(icon.semanticLabel, loc.careEditActionLabel);
      },
    );

    // The default sheet bottom-sheet has only the scrim / system back
    // gesture to dismiss it — neither is discoverable by a screen-reader or
    // keyboard user scanning the sheet's own content.
    testWidgets(
      'the edit sheet exposes a reachable drag handle to dismiss it',
      (tester) async {
        final repository = _FakeCareHistoryRepository(
          days: _sevenDayRange(
            onJul22: [_slot(careScheduleId: 'sch-1', status: CareTodayStatus.missed)],
          ),
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
          isTrue,
        );
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

    // A concurrent load — the user tapping the period selector while the
    // failed edit's repair fetch is still running — clears the controller's
    // `editError` by design. If the screen picked its SnackBar by reading
    // that field after the await, this is exactly where a PUT that FAILED
    // gets reported as saved. It must report from the returned outcome.
    testWidgets(
      'a period switch during the failed edit\'s repair cannot turn the '
      'failure into a success message',
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
        final loc = lookupAppLocalizations(const Locale('en'));

        // A period switch left in flight, so the failed edit below has a
        // superseded load to repair.
        final switching = Completer<void>();
        repository.getRangeCompleter = switching;
        await selectSpan(tester, 30, settle: false);

        repository.editError = const CareRequestFailed();
        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Hold the repair fetch itself, so the tap below lands mid-repair.
        final repair = Completer<void>();
        repository.getRangeCompleter = repair;
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The concurrent load: it clears editError on the controller.
        await selectSpan(tester, 90, settle: false);
        expect(controller.editError, isNull, reason: 'load clears it by design');

        repair.complete();
        switching.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(loc.careHistoryEditSuccessMessage), findsNothing);
        expect(find.text(loc.careErrorGeneric), findsOneWidget);
      },
    );

    // The failed-PUT branch repairs a superseded period switch by re-fetching
    // the current span. That repair must not make the screen report a lost
    // edit as saved — the whole point of `editError` surviving the re-fetch.
    testWidgets(
      'a failed edit during an in-flight period switch still reports the '
      'failure (never the success message) after the repair re-fetch',
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

        // A period switch whose GET is held in flight — the screen doesn't
        // blank during one, so its tiles stay tappable.
        final switching = Completer<void>();
        repository.getRangeCompleter = switching;
        await selectSpan(tester, 30, settle: false);

        repository.editError = const CareRequestFailed();
        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-2026-07-22-08:00')),
        );
        // Fixed-duration pumps rather than pumpAndSettle: the in-flight
        // period switch keeps the thin progress bar animating, so the tree
        // never settles until it lands.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('care-history-edit-done')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        switching.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryEditSuccessMessage), findsNothing);
        expect(find.text(loc.careErrorGeneric), findsOneWidget);
        // The repair ran, so the list matches the selected period.
        expect(controller.spanDays, 30);
      },
    );

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

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('care-history-empty-state')),
          matching: find.byType(EmptyStateGuide),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byIcon(Icons.event_note_outlined),
        ),
        findsOneWidget,
      );
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
      // The AppBar (title + overflow menu) stays on screen in the error
      // state too — it isn't replaced by the error content, only the body
      // is.
      final loc = lookupAppLocalizations(const Locale('en'));
      expect(find.text(loc.careHistoryTitle), findsOneWidget);
      expect(find.byKey(const Key('care-history-menu')), findsOneWidget);

      repository.getError = null;
      repository.days = _sevenDayRange();
      await tester.tap(find.byKey(const Key('care-history-retry-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-history-empty-state')), findsOneWidget);
    });

    // task 4.3/4.4: the error text names the failed period (matching
    // CareAdherenceCard) and is styled as an error — not the plain-text
    // careErrorGeneric this screen used before, which gave no visual
    // signal that the retained period selector was a way *out* of a
    // failure rather than an unrelated control.
    testWidgets(
      'a load failure names the period that failed and is styled as an '
      'error, matching the care adherence card',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const [])
          ..getError = const CareRequestFailed();
        final controller = _controller(repository: repository, spanDays: 7);
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careErrorForPeriod(7)), findsOneWidget);
        expect(find.text(loc.careErrorGeneric), findsNothing);

        final errorText = tester.widget<Text>(
          find.byKey(const Key('care-history-load-error')),
        );
        final theme = Theme.of(tester.element(find.byType(CareHistoryScreen)));
        expect(errorText.style?.color, theme.colorScheme.error);
      },
    );

    testWidgets(
      'the error state keeps the period selector, so a period that fails '
      '(typically the slowest, 90 days) is not a dead end — switching back '
      'down reloads at the shorter period. Retry alone is not enough: the '
      'controller (and with it spanDays) is now a main.dart singleton that '
      'outlives the screen, so a failing period survives leaving and '
      're-entering, and retry can only re-issue the same failing request. '
      "Mirrors CareAdherenceCard's escape hatch.",
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const [])
          ..getError = const CareRequestFailed();
        final controller = _controller(repository: repository, spanDays: 90);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('care-history-load-error')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-history-period-button')),
          findsOneWidget,
        );

        repository.getError = null;
        repository.days = _sevenDayRange(
          onJul22: [_slot(title: 'Today dose', status: CareTodayStatus.done)],
        );
        await selectSpan(tester, 7);

        expect(controller.spanDays, 7);
        expect(
          repository.getRangeCalls.last,
          (from: '2026-07-16', to: '2026-07-22'),
        );
        expect(find.byKey(const Key('care-history-load-error')), findsNothing);
        expect(find.text('Today dose'), findsOneWidget);
      },
    );

    testWidgets(
      'a reload after a failed first load keeps the period selector on the '
      'frame it is in flight — the AsyncStateScaffold full-page spinner has '
      'no selector, so falling back to it would strand the user on the '
      'failing period. `days.isEmpty` cannot express "never loaded": a '
      'failed first load leaves days empty too.',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const [])
          ..getError = const CareRequestFailed();
        final controller = _controller(repository: repository, spanDays: 90);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('care-history-load-error')),
          findsOneWidget,
        );

        // Hold the retry's GET in flight and assert on *that* frame — a
        // pumpAndSettle here would skip straight past it.
        final completer = Completer<void>();
        repository.getRangeCompleter = completer;
        repository.getError = null;
        repository.days = _sevenDayRange(
          onJul22: [_slot(title: 'Today dose', status: CareTodayStatus.done)],
        );
        await tester.tap(find.byKey(const Key('care-history-retry-button')));
        await tester.pump();

        expect(
          find.byKey(const Key('care-history-period-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('care-history-reloading')),
          findsOneWidget,
        );

        completer.complete();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('care-history-period-button')),
          findsOneWidget,
        );
        expect(find.text('Today dose'), findsOneWidget);
      },
    );

    testWidgets('renders the day list via ListView.builder, not an eager '
        'ListView(children:)', (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(
          days: _sevenDayRange(onJul22: [_slot(status: CareTodayStatus.done)]),
        ),
      );
      await _pumpScreen(tester, controller);

      final listView = tester.widget<ListView>(
        find.byKey(const Key('care-history-list')),
      );
      expect(listView.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    testWidgets(
      "the AppBar overflow menu's Today care entry pushes /care-today",
      (tester) async {
        final controller = _controller();
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-history-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-history-menu-today')));
        await tester.pumpAndSettle();

        expect(find.text('/care-today'), findsOneWidget);
      },
    );

    testWidgets(
      "the AppBar overflow menu's care management entry pushes /care-items",
      (tester) async {
        final controller = _controller();
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-history-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('care-history-menu-items')));
        await tester.pumpAndSettle();

        expect(find.text('/care-items'), findsOneWidget);
      },
    );

    testWidgets(
      "the AppBar overflow menu offers only the two navigation entries — no "
      'non-interactive note (a disabled PopupMenuItem is announced by '
      'screen readers as "menu item, button, disabled" and skipped by '
      'keyboard navigation)',
      (tester) async {
        final controller = _controller();
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-history-menu')));
        await tester.pumpAndSettle();

        // Counted, not "the old key is gone" — asserting a key that no
        // longer exists anywhere is vacuously true and would pass again the
        // moment a third, disabled entry were added back under a new key.
        expect(
          find.byWidgetPredicate((w) => w is PopupMenuEntry),
          findsNWidgets(2),
        );
        expect(
          find.byWidgetPredicate((w) => w is PopupMenuItem && !w.enabled),
          findsNothing,
        );
        expect(find.byKey(const Key('care-history-menu-today')), findsOneWidget);
        expect(find.byKey(const Key('care-history-menu-items')), findsOneWidget);
      },
    );

    testWidgets(
      'the empty state at the 7-day period offers widening, which upgrades '
      'to 30 days and reloads',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository, spanDays: 7);
        await _pumpScreen(tester, controller);

        expect(
          find.byKey(const Key('care-history-widen-button')),
          findsOneWidget,
        );
        // task 4.1: a shorter period's empty state now offers BOTH actions
        // at once — widening (primary) and going to care management
        // (secondary) — rather than making the user widen all the way to
        // 90 days before care management becomes reachable.
        expect(
          find.byKey(const Key('care-history-empty-manage-button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('care-history-widen-button')));
        await tester.pumpAndSettle();

        expect(controller.spanDays, 30);
        expect(
          repository.getRangeCalls.last,
          dayRangeEndingOn(30, DateTime(2026, 7, 22)),
        );
      },
    );

    testWidgets(
      'the empty state at the 30-day period offers widening, which upgrades '
      'to 90 days and reloads',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository, spanDays: 30);
        await _pumpScreen(tester, controller);

        await tester.tap(find.byKey(const Key('care-history-widen-button')));
        await tester.pumpAndSettle();

        expect(controller.spanDays, 90);
        expect(
          repository.getRangeCalls.last,
          dayRangeEndingOn(90, DateTime(2026, 7, 22)),
        );
      },
    );

    testWidgets(
      'the empty state at the 90-day (longest) period offers no widen '
      'action, but still offers a next step — care management — instead of '
      'being a dead end (the likeliest cause there is having no care items '
      'set up at all)',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: const []),
          spanDays: 90,
        );
        await _pumpScreen(tester, controller);

        expect(find.byKey(const Key('care-history-empty-state')), findsOneWidget);
        expect(
          find.byKey(const Key('care-history-widen-button')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('care-history-empty-manage-button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('/care-items'), findsOneWidget);
      },
    );

    // task 4.1: at the 90-day (longest) period the wording changes — the
    // likeliest cause of an empty *longest* window is having no care items
    // configured at all, not too narrow a date range.
    testWidgets(
      'the 90-day empty state uses "no care items" wording, not the '
      '"nothing scheduled in this period" wording used at shorter periods',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: const []),
          spanDays: 90,
        );
        await _pumpScreen(tester, controller);

        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryNoCareItemsTitle), findsOneWidget);
        expect(find.text(loc.careHistoryNoCareItemsBody), findsOneWidget);
        expect(find.text(loc.careHistoryEmptyTitle), findsNothing);
        expect(find.text(loc.careHistoryEmptyBody), findsNothing);
      },
    );

    // task 4.1: the widen button must disable itself for the duration of the
    // reload it triggered — otherwise a fast double-tap could fire two
    // widens back to back and skip a period (7 -> 90 instead of 7 -> 30).
    testWidgets(
      "the widen button disables itself while its own reload is in flight, "
      'so a fast double-tap cannot skip a period',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository, spanDays: 7);
        await _pumpScreen(tester, controller);

        final completer = Completer<void>();
        repository.getRangeCompleter = completer;

        final widenButton = find.byKey(const Key('care-history-widen-button'));
        await tester.tap(widenButton);
        await tester.pump();

        expect(tester.widget<FilledButton>(widenButton).onPressed, isNull);

        // A second tap while the first widen is in flight fires nothing: the
        // callback is dispatched directly (a real `tap()` can't reach a
        // disabled button) and no further range request goes out.
        final callsBeforeSecondTap = repository.getRangeCalls.length;
        tester.widget<FilledButton>(widenButton).onPressed?.call();
        await tester.pump();
        expect(repository.getRangeCalls, hasLength(callsBeforeSecondTap));

        completer.complete();
        await tester.pumpAndSettle();

        // Only the one widen went through: 7 -> 30, not 7 -> 90.
        expect(controller.spanDays, 30);
        expect(
          tester.widget<FilledButton>(widenButton).onPressed,
          isNotNull,
        );
      },
    );

    // task 4.1: `setSpan` writes `spanDays` *before* awaiting the reload, so
    // reading `controller.spanDays` mid-flight would already report the new
    // (unconfirmed) period — flipping the empty state's wording/buttons to
    // the 90-day story before the 90-day response has actually come back.
    // The screen must key its copy off the period the *displayed* (settled)
    // content describes instead.
    testWidgets(
      "mid-reload, the empty state still reflects the settled period's "
      'wording and buttons, not the just-selected (unconfirmed) one',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository, spanDays: 30);
        await _pumpScreen(tester, controller);

        final completer = Completer<void>();
        repository.getRangeCompleter = completer;

        await tester.tap(find.byKey(const Key('care-history-widen-button')));
        await tester.pump();

        // The GET for 90 days is in flight; `controller.spanDays` is
        // already 90, but the settled/displayed period is still 30.
        expect(controller.spanDays, 90);
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.careHistoryEmptyTitle), findsOneWidget);
        expect(find.text(loc.careHistoryNoCareItemsTitle), findsNothing);
        expect(
          find.byKey(const Key('care-history-widen-button')),
          findsOneWidget,
        );

        completer.complete();
        await tester.pumpAndSettle();

        // Once settled, the wording catches up to the (still-empty) 90-day
        // period.
        expect(find.text(loc.careHistoryNoCareItemsTitle), findsOneWidget);
        expect(
          find.byKey(const Key('care-history-widen-button')),
          findsNothing,
        );
      },
    );

    // task 4.7/4.8: `controller` is a main.dart singleton that outlives the
    // screen — so re-entering the screen can start with
    // `firstLoadSettled == true` from an *earlier* instance's load, which
    // makes AsyncStateScaffold skip the full-page spinner and render the
    // real content (period selector, widen button) on the very first frame
    // — before *this* instance's own `_load()` has resolved `_idToken`
    // (still `''`). Tapping either control at that point would send an
    // unauthenticated GET and drop the user into a spurious 401 reauth exit.
    testWidgets(
      'the period selector and widen action stay disabled until the '
      "sign-in token resolves, even though the controller's already-loaded "
      'content renders immediately',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository, spanDays: 7);
        // Simulate an earlier screen instance already having loaded once —
        // `firstLoadSettled` is now true on this (singleton) controller.
        await controller.load('token-123');
        expect(repository.getRangeCalls, hasLength(1));

        final authRepository = _FakeAuthRepository();
        final tokenCompleter = Completer<String?>();
        authRepository.idTokenCompleter = tokenCompleter;

        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: CareHistoryScreen(
              controller: controller,
              authRepository: authRepository,
              clock: () => DateTime(2026, 7, 22),
            ),
          ),
        );
        await tester.pump();

        // The stale content renders immediately (no spinner) — but the
        // controls it would drive must not be interactive yet.
        expect(
          find.byKey(const Key('care-history-empty-state')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('care-history-period-button')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('care-history-widen-button')),
              )
              .onPressed,
          isNull,
        );
        // No second (unauthenticated) request has gone out.
        expect(repository.getRangeCalls, hasLength(1));

        tokenCompleter.complete('token-123');
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('care-history-period-button')),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('care-history-widen-button')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    // task 4.7, second half: `idToken()` resolving to `null` (signed out
    // between mounting and the token round-trip) leaves `_idToken` as the
    // empty string — indistinguishable, as far as the backend is concerned,
    // from never having resolved. Flipping a separate "the await finished"
    // flag would re-enable the controls and let the next tap send exactly
    // the unauthenticated GET this gate exists to prevent, producing a
    // spurious 401 reauth exit.
    testWidgets(
      'the period selector and widen action stay disabled when the sign-in '
      'token resolves to null',
      (tester) async {
        final repository = _FakeCareHistoryRepository(days: const []);
        final controller = _controller(repository: repository, spanDays: 7);
        final authRepository = _FakeAuthRepository();
        final tokenCompleter = Completer<String?>();
        authRepository.idTokenCompleter = tokenCompleter;

        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          l10nRouterTestApp(
            home: CareHistoryScreen(
              controller: controller,
              authRepository: authRepository,
              clock: () => DateTime(2026, 7, 22),
            ),
          ),
        );
        await tester.pump();

        tokenCompleter.complete(null);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('care-history-empty-state')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('care-history-period-button')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('care-history-widen-button')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    // design D4 / task 4.9: a listed slot's own `localDate` can differ from
    // its containing day's `date` (they're independent fields fed by the
    // same backend record) — a malformed one must not crash opening the
    // slot's edit sheet; the sheet's date label falls back rather than
    // throwing. (This screen never sends `doneTime` at all, so there's no
    // submission path to guard here — only display.)
    testWidgets(
      "opening the edit sheet for a slot whose localDate can't be parsed "
      "doesn't crash — the sheet's date label falls back to \"—\"",
      (tester) async {
        const malformedSlot = CareTodaySlot(
          careItemId: 'care-1',
          careScheduleId: 'sch-1',
          category: CareCategory.medication,
          title: 'Metformin',
          timeOfDay: '08:00',
          localDate: 'not-a-date',
          status: CareTodayStatus.missed,
          doseQuantity: 1,
        );
        // The day itself is today (so the slot is editable) — only the
        // slot's own `localDate` is malformed.
        final repository = _FakeCareHistoryRepository(
          days: const [
            CareHistoryDay(date: '2026-07-22', slots: [malformedSlot]),
          ],
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const Key('care-history-slot-sch-1-not-a-date-08:00')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('care-history-edit-sheet-subtitle')),
              )
              .data,
          '— 08:00 · ${lookupAppLocalizations(const Locale('en')).careTodayStatusMissed}',
        );
      },
    );

    // design D4 / task 4.9: `_DayCard`'s header reads the same
    // backend-sourced `CareHistoryDay.date` — the fifth of the six D4 call
    // sites.
    testWidgets(
      "a day card whose date can't be parsed falls back to \"—\" in its "
      "header rather than crashing",
      (tester) async {
        const malformedSlot = CareTodaySlot(
          careItemId: 'care-1',
          careScheduleId: 'sch-1',
          category: CareCategory.medication,
          title: 'Metformin',
          timeOfDay: '08:00',
          localDate: 'not-a-date',
          status: CareTodayStatus.done,
          doseQuantity: 1,
        );
        final repository = _FakeCareHistoryRepository(
          days: const [
            CareHistoryDay(date: 'not-a-date', slots: [malformedSlot]),
          ],
        );
        final controller = _controller(repository: repository);
        await _pumpScreen(tester, controller);

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('care-history-day-header-not-a-date')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('care-history-day-header-not-a-date')),
              )
              .data,
          '—',
        );
      },
    );
  });

  // Narrow screen (task 4). **Re-derived after the change, not before it**:
  // this guide used to sit directly in `Expanded > Center > ConstrainedBox`,
  // a *bounded* box, so an overflow threw and `expectNoLayoutErrors` guarded
  // it. It now sits inside a `SingleChildScrollView`, so nothing throws here
  // any more and that guard would pass no matter how badly the guide fitted.
  // What is left to check has to be measured.
  group('the empty guide at 320dp, textScale 2.0', () {
    for (final locale in testSupportedLocales) {
      testWidgets(
        'shows its title, body and both actions in full and reachable, '
        'locale=$locale',
        (tester) async {
          await _pumpNarrow(
            tester,
            _controller(
              repository: _FakeCareHistoryRepository(days: _sevenDayRange()),
            ),
            locale,
          );

          final loc = lookupAppLocalizations(locale);
          expect(find.byKey(const Key('care-history-empty-state')), findsOneWidget);

          // Not clipped: every glyph of both lines was painted. Measured, not
          // read off `didExceedMaxLines` — that flag is only ever true when
          // `maxLines` is set, and the guide's texts set neither `maxLines`
          // nor `overflow`, so reading it here was an assertion that could
          // not fail.
          for (final text in [loc.careHistoryEmptyTitle, loc.careHistoryEmptyBody]) {
            final finder = find.text(text);
            expect(finder, findsOneWidget, reason: '"$text" is missing');
            expectPaintedInFull(
              tester,
              finder,
              reason: '"$text" was cut off at 320dp × 2.0',
            );
          }

          // Reachable: below 90 days the guide offers *two* actions — the
          // case that made the shared guide take a list — and at this text
          // scale the second one starts below the fold.
          for (final key in [
            'care-history-widen-button',
            'care-history-empty-manage-button',
          ]) {
            await tester.scrollUntilVisible(
              find.byKey(Key(key)),
              100,
              // The screen has two scrollables at this width (the period
              // selector scrolls horizontally), so the guide's own has to be
              // named or `scrollUntilVisible` cannot pick one.
              scrollable: find.descendant(
                of: find.byKey(const Key('care-history-empty-scroll')),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.ensureVisible(find.byKey(Key(key)));
            await tester.pumpAndSettle();
            expect(
              find.byKey(Key(key)).hitTestable(),
              findsOneWidget,
              reason: '$key could not be hit-tested at 320dp × 2.0',
            );
            // ...and its label is whole. The test's name says "in full", and
            // until this was added that half was true only of the title and
            // body — a button reachable but with its label clipped would have
            // passed.
            expectPaintedInFull(
              tester,
              find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
              reason: "$key's label was cut off at 320dp × 2.0",
            );
          }
        },
      );
    }
  });

  group('filtering', () {
    Future<void> openFilterSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('care-history-filter-button')));
      await tester.pumpAndSettle();
    }

    Future<void> closeSheet(WidgetTester tester) async {
      // The scrim above the sheet — dismisses it without depending on the
      // drag handle's gesture.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
    }

    // `.first`, not `.last`: the metric now reads value-then-label, so the
    // number is the leading Text.
    String summaryValue(WidgetTester tester, String key) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(Key('care-history-summary-$key')),
            matching: find.byType(Text),
          ),
        )
        .first
        .data!;

    // LINCHPIN. The list, the headline numbers and the empty state all read
    // one filtered value; a summary computed from the unfiltered days would
    // keep reporting the whole period under a list showing a slice of it.
    testWidgets('the list and the summary describe the same filtered records',
        (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _twoItemRange()),
      );
      await _pumpScreen(tester, controller);

      expect(find.text('Metformin'), findsNWidgets(2));
      expect(find.text('Walk'), findsNWidgets(2));
      expect(summaryValue(tester, 'rate'), '75%');
      expect(summaryValue(tester, 'days-with-dose'), '2');
      expect(summaryValue(tester, 'missed-count'), '1');

      await openFilterSheet(tester);
      await tester.tap(
        find.byKey(const Key('care-history-filter-category-rehab')),
      );
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(find.text('Metformin'), findsNothing);
      expect(find.text('Walk'), findsNWidgets(2));
      expect(summaryValue(tester, 'rate'), '50%');
      expect(summaryValue(tester, 'days-with-dose'), '1');
      expect(summaryValue(tester, 'missed-count'), '1');
    });

    testWidgets('filtering by care item keeps only that item, and the applied '
        'chip removes the filter again', (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _twoItemRange()),
      );
      await _pumpScreen(tester, controller);
      expect(find.byKey(const Key('care-history-applied-filters')), findsNothing);

      await openFilterSheet(tester);
      await tester.tap(find.byKey(const Key('care-history-filter-item-care-2')));
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(find.text('Metformin'), findsNothing);
      expect(find.byKey(const Key('care-history-applied-item')), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('care-history-applied-item')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Metformin'), findsNWidgets(2));
      expect(find.byKey(const Key('care-history-applied-filters')), findsNothing);
    });

    testWidgets('a filter that matches nothing shows the filtered-empty state '
        '(never the widen-the-period one), and clearing it restores the list',
        (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _twoItemRange()),
      );
      await _pumpScreen(tester, controller);

      await openFilterSheet(tester);
      await tester.tap(
        find.byKey(const Key('care-history-filter-status-skipped')),
      );
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(
        find.byKey(const Key('care-history-filtered-empty-state')),
        findsOneWidget,
      );
      // The records are filtered out, not out of range: offering to widen
      // the period here would send the user after records already in it.
      expect(find.byKey(const Key('care-history-empty-state')), findsNothing);
      expect(find.byKey(const Key('care-history-widen-button')), findsNothing);

      await tester.tap(
        find.byKey(const Key('care-history-clear-filter-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('care-history-filtered-empty-state')),
        findsNothing,
      );
      expect(find.text('Metformin'), findsNWidgets(2));
    });

    // A period with no records at all keeps its own empty state — the two
    // are different situations with different ways out.
    testWidgets('an empty period still shows the widen-the-period empty state',
        (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _sevenDayRange()),
      );
      await _pumpScreen(tester, controller);

      expect(find.byKey(const Key('care-history-empty-state')), findsOneWidget);
      expect(
        find.byKey(const Key('care-history-filtered-empty-state')),
        findsNothing,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('care-history-filter-button')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('changing the filter issues no request', (tester) async {
      final repository = _FakeCareHistoryRepository(days: _twoItemRange());
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);
      expect(repository.getRangeCalls, hasLength(1));

      await openFilterSheet(tester);
      await tester.tap(
        find.byKey(const Key('care-history-filter-category-rehab')),
      );
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(repository.getRangeCalls, hasLength(1));
    });
  });

  group('the custom date range', () {
    testWidgets('picking one loads exactly the picked dates', (tester) async {
      final repository = _FakeCareHistoryRepository(days: _twoItemRange());
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      await openCustomPicker(tester);

      // July 2026 is the last month the picker shows (lastDate is the pinned
      // "today", 2026-07-22), so its day cells are the ones on screen.
      await tester.tap(find.text('10').last);
      await tester.pump();
      await tester.tap(find.text('15').last);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        repository.getRangeCalls.last,
        (from: '2026-07-10', to: '2026-07-15'),
      );
    });

    testWidgets('the selector shows the picked dates instead of the word '
        '"Custom"', (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _twoItemRange()),
      );
      await _pumpScreen(tester, controller);
      await controller.setPeriod(
        'token-123',
        const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
      );
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      // The control names the period in effect, so the generic word
      // "Custom" (which says nothing about which dates are on screen) is
      // only ever seen inside the picker sheet, not on the screen.
      expect(find.text(loc.careHistoryPeriodCustom), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('care-history-period-button')),
                matching: find.byType(Text),
              ),
            )
            .data,
        'Mar 1 – May 20',
      );
    });

    testWidgets('a failed custom-range load names the dates, not a day count',
        (tester) async {
      final repository = _FakeCareHistoryRepository(days: _twoItemRange());
      final controller = _controller(repository: repository);
      await _pumpScreen(tester, controller);

      repository.getError = Exception('boom');
      await controller.setPeriod(
        'token-123',
        const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
      );
      await tester.pumpAndSettle();

      final loc = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(
          loc.careHistoryErrorForCustomRange('Mar 1, 2026', 'May 20, 2026'),
        ),
        findsOneWidget,
      );
    });

    // The reason the picker is a sheet of rows and not a `SegmentedButton`:
    // that control only calls `onSelectionChanged` on a selection *change*,
    // so the already-selected segment cannot be re-pressed — and the custom
    // row is the only way to adjust an already-picked range. Tapping it
    // while custom is already active must still reopen the date picker.
    testWidgets(
      'tapping the custom row again while custom is already active '
      'reopens the picker',
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: _twoItemRange()),
        );
        await _pumpScreen(tester, controller);
        await controller.setPeriod(
          'token-123',
          const CareHistoryPeriod.custom('2026-07-10', '2026-07-15'),
        );
        await tester.pumpAndSettle();

        await openCustomPicker(tester);

        expect(find.text('Save'), findsOneWidget);
      },
    );

    // The period on screen can be a *persisted* custom range from a
    // previous day (`CareHistoryFilterStore` only validates its length, not
    // its age against "today") — by the time it's reopened it can start
    // before the picker's `firstDate` (`today - 365 days`). An unclamped
    // `initialDateRange` trips `showDateRangePicker`'s own assert; this
    // reopens without throwing.
    testWidgets(
      'reopening the picker on a persisted custom range that now starts '
      "before the picker's firstDate does not throw",
      (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: _twoItemRange()),
        );
        await _pumpScreen(tester, controller);
        // clock is pinned to 2026-07-22, so firstDate is 2025-07-22 —
        // this range starts well before that.
        await controller.setPeriod(
          'token-123',
          const CareHistoryPeriod.custom('2025-01-01', '2025-01-10'),
        );
        await tester.pumpAndSettle();

        await openCustomPicker(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Save'), findsOneWidget);
      },
    );
  });

  // The filter row and the summary sit above the record list, which is the
  // screen. Both have to survive the narrowest supported width at double text
  // scale *without* pushing the list out of the viewport — a guard that only
  // checked for overflow errors would pass on a layout that left the list two
  // rows tall.
  group('the filter row and summary at 320dp, textScale 2.0', () {
    for (final locale in testSupportedLocales) {
      testWidgets('stay laid out with the list still visible, locale=$locale',
          (tester) async {
        final controller = _controller(
          repository: _FakeCareHistoryRepository(days: _twoItemRange()),
        );
        controller.setFilter(
          const CareHistoryFilter(
            categories: {CareCategory.medication, CareCategory.rehab},
            statuses: {CareTodayStatus.done, CareTodayStatus.missed},
            careItemId: 'care-2',
          ),
        );

        final errors = await collectLayoutErrors(
          () => _pumpNarrow(tester, controller, locale),
        );
        expect(
          errors.map((e) => e.exception.toString().split('\n').first).toList(),
          isEmpty,
        );

        expect(
          find.byKey(const Key('care-history-applied-filters')),
          findsOneWidget,
        );
        // Pins the chip row's own height (`CareHistoryAppliedFilters`
        // scales it with the text scaler). `expectPaintedInFull` is the
        // wrong tool here — its own doc says it "does not catch text ...
        // clipped by an ancestor `ClipRect`", which is exactly how a
        // too-short `SizedBox` cross-axis extent hides a chip inside the
        // row's horizontal `ListView` (confirmed: it stayed green when
        // this height was reverted to a bare `48`). A rect containment
        // check does fail on that, because `getRect` reports each chip's
        // true painted position regardless of what clips it.
        final rowRect = tester.getRect(
          find.byKey(const Key('care-history-applied-filters')),
        );
        for (final key in [
          'care-history-applied-item',
          'care-history-applied-category-medication',
        ]) {
          // The chip *container*'s own rect isn't enough — it reports a
          // rect clamped to fit, while its label `Text` — the thing that
          // actually gets clipped by the row's `ListView` — can still
          // extend a pixel past the bottom (confirmed by measurement:
          // container bottom 164.0, its Text's bottom 165.0, at a fixed
          // `height: 48`).
          final finder = find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          );
          expect(finder, findsOneWidget, reason: '$key is missing');
          final textRect = tester.getRect(finder);
          expect(
            textRect.top >= rowRect.top - 0.5 &&
                textRect.bottom <= rowRect.bottom + 0.5,
            isTrue,
            reason: '$key\'s label ($textRect) was clipped by the '
                'applied-filters row ($rowRect) at 320dp × 2.0',
          );
        }
        for (final key in [
          'care-history-summary-rate',
          'care-history-summary-days-with-dose',
          'care-history-summary-missed-count',
        ]) {
          for (final text in find
              .descendant(
                of: find.byKey(Key(key)),
                matching: find.byType(Text),
              )
              .evaluate()) {
            expectPaintedInFull(
              tester,
              find.byWidget(text.widget),
              reason: '$key was cut off at 320dp × 2.0',
            );
          }
        }

        // The point of the screen: whatever the controls above it cost, the
        // record list still gets usable height.
        expect(
          tester.getSize(find.byKey(const Key('care-history-list'))).height,
          greaterThan(200),
          reason: 'the record list was squeezed out at 320dp × 2.0',
        );
      });
    }
  });

  // task R4/blocker: the period control carries the actual picked dates
  // (its longest label) once a custom range is active — the case most
  // likely to get squeezed off-screen at the narrowest supported width.
  group('the period selector at 320dp, textScale 2.0', () {
    for (final locale in testSupportedLocales) {
      testWidgets(
        'the period control stays reachable and its full label is at least '
        'available via its tooltip, locale=$locale',
        (tester) async {
          final controller = _controller(
            repository: _FakeCareHistoryRepository(days: _twoItemRange()),
          );
          await controller.setPeriod(
            'token-123',
            const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
          );

          final errors = await collectLayoutErrors(
            () => _pumpNarrow(tester, controller, locale),
          );
          expect(
            errors.map((e) => e.exception.toString().split('\n').first).toList(),
            isEmpty,
          );

          const key = Key('care-history-period-button');
          // Deliberately *not* scrolled into view first: the button sits
          // outside any scrollable (see `care_history_screen.dart`), so it
          // must already be hit-testable in the very first frame — a prior
          // version of this test called `scrollUntilVisible`/`ensureVisible`
          // here, which made it pass even when the button was scrolled
          // off-screen with no way for a real user to discover it.
          expect(
            find.byKey(key).hitTestable(),
            findsOneWidget,
            reason: 'the period control could not be hit-tested at 320dp × 2.0',
          );

          // The picked dates are the widest label this button ever shows,
          // and at this width they do not fit next to the filter button —
          // the button's own text ellipsizes, but its `Tooltip` still
          // carries the un-truncated range (never just the button's own
          // visible text, which mutation confirmed can silently ellipsize
          // without failing this check).
          final loc = lookupAppLocalizations(locale);
          final fullLabel = loc.careHistoryPeriodCustomLabel(
            monthDayLabel(tester.element(find.byKey(key)), DateTime(2026, 3, 1)),
            monthDayLabel(tester.element(find.byKey(key)), DateTime(2026, 5, 20)),
          );
          expect(
            tester.widget<Tooltip>(
              find.ancestor(
                of: find.byKey(key),
                matching: find.byType(Tooltip),
              ),
            ).message,
            fullLabel,
            reason: 'the full custom range must survive somewhere even when '
                "the button's own label is too narrow to show it in full",
          );
        },
      );
    }
  });

  // The period control replaced a custom button sitting beside a
  // horizontally scrolling `SegmentedButton`. These guard what that shape
  // cost and what the single control must keep doing at the narrowest
  // supported width.
  group('the period control at 320dp, textScale 2.0', () {
    Finder periodButton() => find.byKey(const Key('care-history-period-button'));
    Finder periodLabel() => find.descendant(
      of: periodButton(),
      matching: find.byType(Text),
    );

    for (final locale in testSupportedLocales) {
      for (final days in [7, 30, 90]) {
        testWidgets(
          'names the whole span it is showing, on one line and inside its '
          'own box, span=$days locale=$locale',
          (tester) async {
            final controller = _controller(
              repository: _FakeCareHistoryRepository(days: _twoItemRange()),
              spanDays: days,
            );
            final errors = await collectLayoutErrors(
              () => _pumpNarrow(tester, controller, locale),
            );
            expect(
              errors.map((e) => e.exception.toString().split('\n').first).toList(),
              isEmpty,
            );

            final loc = lookupAppLocalizations(locale);
            final expected = loc.careHistoryPeriodSpanLabel(days);
            // The control is the only thing on screen saying which period
            // is in effect, so a bare "7 days" (`trendRange7`, which reads
            // as a fragment away from a heading) is not enough.
            expect(tester.widget<Text>(periodLabel()).data, expected);
            expect(
              tester
                  .widget<Tooltip>(
                    find.ancestor(
                      of: periodButton(),
                      matching: find.byType(Tooltip),
                    ),
                  )
                  .message,
              expected,
            );

            // Not `expectPaintedInFull`: the widget tests run in a
            // placeholder font whose every glyph is one em wide, so an
            // English label here is about twice the width a real font gives
            // it and ellipsizes at 320dp × 2.0 even though it fits on a real
            // device (see `real_font_metrics_test.dart`). What holds in
            // either font is that the label stays on one line inside the
            // button — a wrap or a spill is a layout bug at any font width.
            expect(
              paintedTextLineCount(tester, periodLabel()),
              1,
              reason: 'the period label wrapped at 320dp × 2.0',
            );
            final labelRect = tester.getRect(periodLabel());
            final buttonRect = tester.getRect(periodButton());
            expect(
              labelRect.left >= buttonRect.left - 0.5 &&
                  labelRect.right <= buttonRect.right + 0.5,
              isTrue,
              reason: 'the period label ($labelRect) spilled out of its '
                  'button ($buttonRect)',
            );
          },
        );
      }

      testWidgets(
        'is hit-testable on the very first frame, locale=$locale',
        (tester) async {
          await _pumpNarrow(
            tester,
            _controller(
              repository: _FakeCareHistoryRepository(days: _twoItemRange()),
            ),
            locale,
          );

          // Deliberately *not* scrolled into view first: nothing on this
          // screen may put the only period control inside a scrollable the
          // user has no affordance to discover — the shape this control
          // replaced did exactly that to its 7/30/90 segments.
          expect(
            periodButton().hitTestable(),
            findsOneWidget,
            reason: 'the period control could not be hit-tested at 320dp × 2.0',
          );
        },
      );

      testWidgets(
        'the picker checks exactly one row, and it is the row for the period '
        'in effect, locale=$locale',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final controller = _controller(
            repository: _FakeCareHistoryRepository(days: _twoItemRange()),
            spanDays: 30,
          );
          await _pumpNarrow(tester, controller, locale);

          await tester.tap(periodButton());
          await tester.pumpAndSettle();

          final loc = lookupAppLocalizations(locale);
          expect(
            find.text(loc.careHistoryPeriodPickerTitle),
            findsOneWidget,
            reason: 'the sheet must be headed with its own title',
          );
          // Each row must actually say which span it is — a placeholder
          // string here would pass every other assertion in this test.
          for (final rowDays in [7, 30, 90]) {
            expect(
              find.descendant(
                of: find.byKey(Key('care-history-period-option-$rowDays')),
                matching: find.text(loc.careHistoryPeriodSpanLabel(rowDays)),
              ),
              findsOneWidget,
              reason: 'the $rowDays-day row does not show its span label',
            );
          }
          expect(
            find.descendant(
              of: find.byKey(const Key('care-history-period-option-custom')),
              matching: find.text(loc.careHistoryPeriodCustom),
            ),
            findsOneWidget,
            reason: 'the custom row does not show its label',
          );

          // One check mark on the whole sheet — the shape this replaced
          // could show a selected custom button *and* a selected segment at
          // the same time.
          expect(
            find.byKey(const Key('care-history-period-option-selected')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('care-history-period-option-30')),
              matching: find.byKey(
                const Key('care-history-period-option-selected'),
              ),
            ),
            findsOneWidget,
            reason: 'the 30-day row is the period in effect',
          );
          // The visual check mark alone doesn't put "selected" into the
          // semantics tree — that comes from `ListTile.selected`. Without
          // it a screen reader announces every row identically regardless
          // of which period is actually in effect.
          expect(
            tester.getSemantics(
              find.byKey(const Key('care-history-period-option-30')),
            ),
            containsSemantics(isSelected: true),
          );
          expect(
            tester.getSemantics(
              find.byKey(const Key('care-history-period-option-7')),
            ),
            containsSemantics(isSelected: false),
          );

          await tester.tap(find.byKey(const Key('care-history-period-option-30')));
          await tester.pumpAndSettle();
          // Set directly rather than through the custom row: at 320dp ×
          // 2.0 `showDateRangePicker`'s own dialog overflows, which would
          // fail this guard for a reason that has nothing to do with the
          // check mark it is about.
          await controller.setPeriod(
            'token-123',
            const CareHistoryPeriod.custom('2026-07-10', '2026-07-15'),
          );
          await tester.pumpAndSettle();

          await tester.tap(periodButton());
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('care-history-period-option-selected')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('care-history-period-option-custom')),
              matching: find.byKey(
                const Key('care-history-period-option-selected'),
              ),
            ),
            findsOneWidget,
            reason: 'a custom period checks the custom row, not a span row',
          );
          expect(
            tester.getSemantics(
              find.byKey(const Key('care-history-period-option-custom')),
            ),
            containsSemantics(isSelected: true),
          );
          // The custom row's subtitle is the only place in the sheet that
          // says which dates the active custom period actually covers.
          expect(
            find.descendant(
              of: find.byKey(const Key('care-history-period-option-custom')),
              matching: find.text(
                loc.careHistoryPeriodCustomLabel(
                  monthDayLabel(
                    tester.element(periodButton()),
                    DateTime(2026, 7, 10),
                  ),
                  monthDayLabel(
                    tester.element(periodButton()),
                    DateTime(2026, 7, 15),
                  ),
                ),
              ),
            ),
            findsOneWidget,
            reason: 'the custom row does not show the dates it is covering',
          );
          semantics.dispose();
        },
      );

      testWidgets(
        'the summary reads value-first, bigger and heavier than its label, '
        'locale=$locale',
        (tester) async {
          await _pumpNarrow(
            tester,
            _controller(
              repository: _FakeCareHistoryRepository(days: _twoItemRange()),
            ),
            locale,
          );

          for (final key in [
            'care-history-summary-rate',
            'care-history-summary-days-with-dose',
            'care-history-summary-missed-count',
          ]) {
            final texts = find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            );
            expect(texts, findsNWidgets(2), reason: '$key: value + label');
            // Resolved styles, not the raw `TextStyle`s: `titleMedium` and
            // `bodySmall` both leave `fontSize`/`fontWeight` to the theme on
            // some platforms, and a null size compares equal to a null size.
            final value = tester
                .renderObject<RenderParagraph>(texts.first)
                .text
                .style!;
            final label = tester
                .renderObject<RenderParagraph>(texts.last)
                .text
                .style!;
            expect(value.fontSize, isNotNull);
            expect(label.fontSize, isNotNull);
            expect(
              value.fontSize!,
              greaterThanOrEqualTo(label.fontSize! * 1.25),
              reason: '$key: the number must read as the headline, not as '
                  'another word in the sentence',
            );
            expect(
              (value.fontWeight ?? FontWeight.normal).index,
              greaterThan((label.fontWeight ?? FontWeight.normal).index),
              reason: '$key: the number must be the heavier of the two',
            );
            for (final text in texts.evaluate()) {
              expectPaintedInFull(
                tester,
                find.byWidget(text.widget),
                reason: '$key was cut off at 320dp × 2.0',
              );
            }
          }
        },
      );

      testWidgets(
        'costs the record list no height compared with the selector it '
        'replaced, locale=$locale',
        (tester) async {
          // Measured on this same fixture *before* the change (the custom
          // button + `SegmentedButton` row, label-then-value summary), in
          // the placeholder test font. The control row is 48dp tall either
          // way, so every dp the summary spends comes straight out of the
          // list: the stacked value-over-label summary that was drafted for
          // this change put these at 40 (en) / 136 (zh_Hant).
          const before = {'en': 208.0, 'zh_Hant': 256.0};
          final controller = _controller(
            repository: _FakeCareHistoryRepository(days: _twoItemRange()),
          );
          controller.setFilter(
            const CareHistoryFilter(
              categories: {CareCategory.medication, CareCategory.rehab},
              statuses: {CareTodayStatus.done, CareTodayStatus.missed},
              careItemId: 'care-2',
            ),
          );
          await _pumpNarrow(tester, controller, locale);

          expect(
            tester.getSize(find.byKey(const Key('care-history-list'))).height,
            greaterThanOrEqualTo(before[locale.toString()]!),
            reason: 'the header grew: the record list is now smaller than it '
                'was before the period control and summary were reworked',
          );
        },
      );
    }
  });

  // The dead end this whole control exists to avoid: `SegmentedButton` only
  // calls `onSelectionChanged` on a selection *change*, so the row for the
  // period already in effect has to keep working. Run at the default test
  // surface, not 320dp × 2.0 — `showDateRangePicker`'s own dialog does not
  // lay out at that size, which would fail these for a reason that has
  // nothing to do with the control under test.
  group('re-picking the period already in effect', () {
    testWidgets('the custom row reopens the date picker', (tester) async {
      final controller = _controller(
        repository: _FakeCareHistoryRepository(days: _twoItemRange()),
      );
      await _pumpScreen(tester, controller);
      await controller.setPeriod(
        'token-123',
        const CareHistoryPeriod.custom('2026-07-10', '2026-07-15'),
      );
      await tester.pumpAndSettle();

      await openCustomPicker(tester);

      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });

    testWidgets('the row for the current span closes the picker and keeps '
        'the span', (tester) async {
      final repository = _FakeCareHistoryRepository(days: _twoItemRange());
      final controller = _controller(repository: repository, spanDays: 7);
      await _pumpScreen(tester, controller);

      await selectSpan(tester, 7);

      expect(tester.takeException(), isNull);
      expect(controller.spanDays, 7);
      expect(
        find.byKey(const Key('care-history-period-option-7')),
        findsNothing,
        reason: 'the sheet closes on any row, including the current one',
      );
      expect(
        repository.getRangeCalls.last,
        (from: '2026-07-16', to: '2026-07-22'),
      );
    });
  });
}
