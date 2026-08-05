import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_exceptions.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

/// A stateful in-memory fake mirroring the controller-test fake, so mutations
/// followed by a re-read reflect the change.
class FakeMenstrualRepository implements MenstrualRepository {
  final List<MenstrualPeriod> periods = [];
  MenstrualStats stats;
  int _nextId = 1;
  Object? failGetOverview;

  /// Every start date [addPeriod] was called with, in order — lets a test
  /// assert a submission wrote exactly once.
  final List<DateTime> addCalls = [];

  /// Every period id [deletePeriod] was called with, in order — lets a test
  /// assert that a dropped submission issued no delete at all.
  final List<String> deleteCalls = [];

  FakeMenstrualRepository({this.stats = const MenstrualStats()});

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    if (failGetOverview != null) throw failGetOverview!;
    return MenstrualOverview(
      periods: List.of(periods),
      stats: stats,
      lastPeriod: periods.isEmpty ? null : periods.last,
    );
  }

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    addCalls.add(startDate);
    final period = MenstrualPeriod(
      id: 'p${_nextId++}',
      startDate: startDate,
      endDate: endDate,
    );
    periods.add(period);
    return period;
  }

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    final index = periods.indexWhere((p) => p.id == id);
    final existing = periods[index];
    final updated = MenstrualPeriod(
      id: id,
      startDate: startDate ?? existing.startDate,
      endDate: clearEndDate ? null : (endDate ?? existing.endDate),
    );
    periods[index] = updated;
    return updated;
  }

  @override
  Future<bool> deletePeriod(String idToken, String id) async {
    deleteCalls.add(id);
    periods.removeWhere((p) => p.id == id);
    return true;
  }
}

MenstrualController _controllerFor(FakeMenstrualRepository repo) =>
    MenstrualController(
      GetMenstrualOverview(repo),
      AddPeriod(repo),
      UpdatePeriod(repo),
      DeletePeriod(repo),
    );

Future<MenstrualController> _pumpScreen(
  WidgetTester tester,
  FakeMenstrualRepository repo, {
  bool load = true,
  Locale locale = const Locale('en'),
}) async {
  final controller = _controllerFor(repo);
  if (load) await controller.load('tok');
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: MenstrualScreen(
        controller: controller,
        idToken: () async => 'tok',
        clock: () => DateTime(2026, 7, 22),
        onSignInAgain: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('MenstrualScreen', () {
    testWidgets('shows an app bar with a back affordance and the calendar', (
      tester,
    ) async {
      await _pumpScreen(tester, FakeMenstrualRepository());

      expect(find.text(loc.menstrualTitle), findsWidgets);
      expect(find.byKey(const Key('menstrual-month-label')), findsOneWidget);
    });

    testWidgets(
      'formats dates in the active locale and shows the full last period range',
      (tester) async {
        final repo = FakeMenstrualRepository();
        repo.periods.add(
          MenstrualPeriod(
            id: '1',
            startDate: DateTime(2026, 7, 13),
            endDate: DateTime(2026, 7, 22),
          ),
        );
        await _pumpScreen(
          tester,
          repo,
          locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );

        // Month header follows the locale (Chinese "年", not the English "Jul").
        final monthLabel = tester.widget<Text>(
          find.byKey(const Key('menstrual-month-label')),
        );
        expect(monthLabel.data, contains('年'));
        expect(monthLabel.data, isNot(contains('Jul')));

        // The last period shows BOTH endpoints in full (not ellipsis-truncated).
        final lastValue = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const Key('menstrual-last-period')),
                matching: find.byType(Text),
              ),
            )
            .last
            .data!;
        expect(lastValue, contains('13'));
        expect(lastValue, contains('22'));
        expect(lastValue, contains('–'));
      },
    );

    testWidgets('shows statistics values when available', (tester) async {
      final repo = FakeMenstrualRepository(
        stats: MenstrualStats(
          averageCycleDays: 28,
          averagePeriodDays: 5,
          predictedNextStart: DateTime(2026, 7, 24),
        ),
      );
      await _pumpScreen(tester, repo);

      expect(
        find.descendant(
          of: find.byKey(const Key('menstrual-avg-cycle')),
          matching: find.text(loc.menstrualDaysValue(28)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a placeholder for null statistics', (tester) async {
      await _pumpScreen(tester, FakeMenstrualRepository());

      expect(
        find.descendant(
          of: find.byKey(const Key('menstrual-avg-cycle')),
          matching: find.text(loc.menstrualStatPlaceholder),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a load failure shows an error state, not a crash', (
      tester,
    ) async {
      final repo = FakeMenstrualRepository()
        ..failGetOverview = const MenstrualFetchFailure();
      await _pumpScreen(tester, repo);

      expect(find.byKey(const Key('menstrual-error')), findsOneWidget);
    });

    testWidgets('a 401 shows the reauth message', (tester) async {
      final repo = FakeMenstrualRepository()
        ..failGetOverview = const MenstrualReauthenticationRequired();
      await _pumpScreen(tester, repo);

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
    });

    testWidgets('shows first-run guidance when there are no periods', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpScreen(tester, FakeMenstrualRepository());

      expect(find.byKey(const Key('menstrual-empty-hint')), findsOneWidget);
      expect(find.text(loc.menstrualEmptyHint), findsOneWidget);
    });

    testWidgets('hides the first-run guidance once a period exists', (
      tester,
    ) async {
      final repo = FakeMenstrualRepository()
        ..periods.add(
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 3),
            endDate: DateTime(2026, 7, 7),
          ),
        );
      await _pumpScreen(tester, repo);

      expect(find.byKey(const Key('menstrual-empty-hint')), findsNothing);
    });

    testWidgets(
      'tapping the month title jumps the calendar to a month a year back',
      (tester) async {
        await _pumpScreen(tester, FakeMenstrualRepository());

        await tester.tap(find.byKey(const Key('menstrual-month-label')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-year-previous')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('month-picker-month-3')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(const Key('menstrual-month-label')))
              .data,
          DateFormat.yMMM('en').format(DateTime(2025, 3)),
        );
      },
    );

    testWidgets('dismissing the month picker leaves the month alone', (
      tester,
    ) async {
      await _pumpScreen(tester, FakeMenstrualRepository());

      await tester.tap(find.byKey(const Key('menstrual-month-label')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('menstrual-month-label'))).data,
        DateFormat.yMMM('en').format(DateTime(2026, 7)),
      );
    });

    testWidgets('the previous/next month arrows still step one month', (
      tester,
    ) async {
      await _pumpScreen(tester, FakeMenstrualRepository());

      await tester.tap(find.byKey(const Key('menstrual-prev-month')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('menstrual-month-label'))).data,
        DateFormat.yMMM('en').format(DateTime(2026, 6)),
      );

      await tester.tap(find.byKey(const Key('menstrual-next-month')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('menstrual-month-label'))).data,
        DateFormat.yMMM('en').format(DateTime(2026, 7)),
      );
    });
  });

  group('MenstrualScreen add/edit/delete', () {
    testWidgets('the add button opens the add dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpScreen(tester, FakeMenstrualRepository());

      await tester.tap(find.byKey(const Key('menstrual-add-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menstrual-start-date')), findsOneWidget);
      expect(find.byKey(const Key('menstrual-save-period')), findsOneWidget);
    });

    testWidgets('tapping a calendar day opens a dialog prefilled with that day',
        (tester) async {
      final repo = FakeMenstrualRepository();
      await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-10')));
      await tester.pumpAndSettle();

      // The dialog opens and the save control is enabled (start prefilled).
      expect(find.text(loc.menstrualAddDialogTitle), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('menstrual-save-period')),
      );
      expect(save.onPressed, isNotNull);
    });

    testWidgets('adding a period (via a tapped day) re-reads and marks it', (
      tester,
    ) async {
      final repo = FakeMenstrualRepository();
      final controller = await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menstrual-save-period')));
      await tester.pumpAndSettle();

      expect(controller.overview!.periods, hasLength(1));
      final marker = tester.widget<Container>(
        find.byKey(const Key('menstrual-day-marker-2026-07-10')),
      );
      expect((marker.decoration as BoxDecoration).color, isNotNull);
    });

    testWidgets('tapping a day within a period opens the edit dialog', (
      tester,
    ) async {
      final repo = FakeMenstrualRepository()
        ..periods.add(
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 3),
            endDate: DateTime(2026, 7, 7),
          ),
        );
      await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-05')));
      await tester.pumpAndSettle();

      expect(find.text(loc.menstrualEditDialogTitle), findsOneWidget);
      expect(find.byKey(const Key('menstrual-delete-period')), findsOneWidget);
    });

    testWidgets('clearing the end date reopens the period', (tester) async {
      final repo = FakeMenstrualRepository()
        ..periods.add(
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 3),
            endDate: DateTime(2026, 7, 7),
          ),
        );
      final controller = await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-05')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menstrual-clear-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menstrual-save-period')));
      await tester.pumpAndSettle();

      expect(controller.overview!.periods.single.endDate, isNull);
    });

    testWidgets('deleting a period removes it after the re-read', (
      tester,
    ) async {
      final repo = FakeMenstrualRepository()
        ..periods.add(
          MenstrualPeriod(
            id: 'p1',
            startDate: DateTime(2026, 7, 3),
            endDate: DateTime(2026, 7, 7),
          ),
        );
      final controller = await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-05')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menstrual-delete-period')));
      await tester.pumpAndSettle();

      expect(controller.overview!.periods, isEmpty);
    });

    testWidgets(
      'opening the start picker for a future-dated day does not assert',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpScreen(tester, FakeMenstrualRepository());

        // Navigate the calendar to the next (future) month and tap a day that
        // is after "today" (2026-07-22), prefilling the add dialog with a
        // future start date.
        await tester.tap(find.byKey(const Key('menstrual-next-month')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('menstrual-day-2026-08-15')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('menstrual-start-date')), findsOneWidget);

        // Opening the start date picker must not trip the framework's
        // initialDate <= lastDate assert (initialDate is clamped to today).
        await tester.tap(find.byKey(const Key('menstrual-start-date')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );

    testWidgets('an end date before the start disables save', (tester) async {
      final repo = FakeMenstrualRepository()
        ..periods.add(
          MenstrualPeriod(id: 'p1', startDate: DateTime(2026, 7, 10)),
        );
      await _pumpScreen(tester, repo);

      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-10')));
      await tester.pumpAndSettle();

      // Pick an end date (the 5th) earlier than the start (the 10th). Scope
      // the day tap to the date picker — the screen's own calendar behind the
      // dialog also renders a "5".
      await tester.tap(find.byKey(const Key('menstrual-end-date')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('5'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('menstrual-end-before-start-error')),
        findsOneWidget,
      );
      final save = tester.widget<FilledButton>(
        find.byKey(const Key('menstrual-save-period')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('the month label shows a caret and a tooltip', (tester) async {
      await _pumpScreen(tester, FakeMenstrualRepository());

      final entry = find.ancestor(
        of: find.byKey(const Key('menstrual-month-label')),
        matching: find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == loc.monthPickerOpenTooltip,
        ),
      );
      expect(entry, findsOneWidget);
      expect(
        find.descendant(
          of: entry,
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
      );
    });

    // Regression: the month label's `▾` affordance added an icon to a centred,
    // non-shrinkable Row. Widget tests default to an 800x600 surface, so
    // nothing else in this mobile-first PWA's suite caught it.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the month header does not overflow at ${width.toInt()}dp, '
          'locale=$locale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 1400));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await _pumpScreen(
              tester,
              FakeMenstrualRepository(),
              locale: locale,
            );

            expect(tester.takeException(), isNull);
            expectMonthLabelFullyVisible(
              tester,
              const Key('menstrual-month-label'),
            );
            expectMonthLabelReadable(
              tester,
              const Key('menstrual-month-label'),
            );
            final entry = tester.getRect(
              find.ancestor(
                of: find.byKey(const Key('menstrual-month-label')),
                matching: find.byType(Tooltip),
              ),
            );
            final label = tester.getRect(
              find.byKey(const Key('menstrual-month-label')),
            );
            final caret = tester.getRect(find.byIcon(Icons.arrow_drop_down));
            expect(label.left, greaterThanOrEqualTo(entry.left));
            expect(caret.right, lessThanOrEqualTo(entry.right));
          },
        );
      }
    }

    // Regression: this change moved the other three month-label entries to
    // `ShrinkToFitText` (scale instead of truncate) and left this one on a
    // plain `Text` + `TextOverflow.ellipsis`. The width tests above ran at the
    // default text scale of 1.0, where the label fits either way, so they
    // passed while a user on a large system font size silently lost the month
    // digits (`2026年7月` → `202…`, painted 32px and ellipsized). Only the
    // painted-size assertion, taken under a real `textScaler`, sees it.
    for (final width in [320.0, 360.0]) {
      for (final textScale in [1.0, 2.0]) {
        for (final locale in testSupportedLocales) {
          testWidgets(
            'the month label stays whole at ${width.toInt()}dp/'
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 1400));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await _pumpScreen(
                tester,
                FakeMenstrualRepository(),
                locale: locale,
              );

              expect(tester.takeException(), isNull);
              expectMonthLabelFullyVisible(
                tester,
                const Key('menstrual-month-label'),
              );
              expectMonthLabelPaintedReadable(
                tester,
                const Key('menstrual-month-label'),
              );
            },
          );
        }
      }
    }
  });

  // The ID token is resolved at request time, so between the dialog's save and
  // the controller's `saving` status there is a whole token round trip during
  // which nothing in the controller has changed yet. That window has to be
  // closed by the screen itself, or a second submission starts a second write.
  group('MenstrualScreen while the ID token is still resolving', () {
    /// Pumps a loaded screen whose token provider is held open by [gate].
    Future<void> pumpGatedToken(
      WidgetTester tester,
      FakeMenstrualRepository repo,
      Completer<void> gate,
    ) async {
      // Tall enough that the add button below the calendar is on screen.
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controllerFor(repo);
      await controller.load('tok');
      await tester.pumpWidget(
        l10nTestApp(
          home: MenstrualScreen(
            controller: controller,
            idToken: () async {
              await gate.future;
              return 'tok';
            },
            clock: () => DateTime(2026, 7, 22),
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Taps [dayKey] and saves the resulting add-period dialog, without
    /// `pumpAndSettle` — the busy bar's progress indicator animates forever
    /// while a mutation is in flight, so a settle would time out.
    Future<void> addPeriodVia(WidgetTester tester, String dayKey) async {
      await tester.tap(find.byKey(Key(dayKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('menstrual-save-period')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Taps [a] and [b] in the SAME frame — both handlers run before the
    /// screen rebuilds, so `busy` is still false for the second one. A plain
    /// `tap → pump → tap` cannot reach that: by the second tap the first
    /// handler has run and the controls have already disabled themselves.
    ///
    /// Only usable when [a]'s handler does not push a route: pushing one runs
    /// `Navigator._cancelActivePointers`, which cancels every other in-flight
    /// pointer and absorbs the rest of the frame's, so [b] would never fire.
    Future<void> tapBothInOneFrame(
      WidgetTester tester,
      Finder a,
      Finder b,
    ) async {
      final first = TestPointer(1);
      final second = TestPointer(2);
      await tester.sendEventToBinding(first.down(tester.getCenter(a)));
      await tester.sendEventToBinding(first.up());
      await tester.sendEventToBinding(second.down(tester.getCenter(b)));
      await tester.sendEventToBinding(second.up());
    }

    // `_deletePeriod`'s `if (!ran) return;` IS reachable: the undo prompt is a
    // SnackBar, which no `busy` gating covers, so an undo tap and a day-cell
    // tap in the same frame start the undo's write first and then open a
    // dialog whose delete lands mid-flight. Without the guard the screen
    // announces a deletion that never happened, with an Undo that would re-add
    // a still-present period.
    testWidgets('a delete refused mid-flight claims no deletion', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeMenstrualRepository();
      await repo.addPeriod(
        'tok',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 3),
      );
      await repo.addPeriod(
        'tok',
        startDate: DateTime(2026, 7, 10),
        endDate: DateTime(2026, 7, 14),
      );
      repo.addCalls.clear();
      Completer<void>? gate;
      final controller = _controllerFor(repo);
      await controller.load('tok');
      await tester.pumpWidget(
        l10nTestApp(
          home: MenstrualScreen(
            controller: controller,
            idToken: () async {
              if (gate != null) await gate.future;
              return 'tok';
            },
            clock: () => DateTime(2026, 7, 22),
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Delete p1 normally; its undo prompt appears.
      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menstrual-delete-period')));
      await tester.pumpAndSettle();
      expect(repo.deleteCalls, ['p1']);
      expect(find.text(loc.menstrualUndo), findsOneWidget);

      // Same frame: the undo starts a write (held on the token) and p2's
      // dialog opens.
      gate = Completer<void>();
      await tapBothInOneFrame(
        tester,
        find.text(loc.menstrualUndo),
        find.byKey(const Key('menstrual-day-2026-07-10')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('menstrual-delete-period')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menstrual-delete-period')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // p2 was never deleted — and nothing on screen says it was.
      expect(repo.deleteCalls, ['p1']);
      expect(find.text(loc.menstrualPeriodDeleted), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.addCalls, [DateTime(2026, 7, 1)]);
    });

    // A period for a *different* day is a distinct action, not a double
    // submit — the re-entrancy guard must never swallow it in silence. The
    // day cells are disabled while a mutation is in flight, so the second
    // dialog cannot even be opened: the action is refused up front (with the
    // busy bar showing) instead of vanishing, and it stays available
    // afterwards.
    testWidgets(
      'a different day cannot be submitted mid-flight, and is not lost',
      (tester) async {
        final repo = FakeMenstrualRepository();
        final gate = Completer<void>();
        await pumpGatedToken(tester, repo, gate);

        await addPeriodVia(tester, 'menstrual-day-2026-07-10');

        // Visibly refused: the cell is non-interactive, and tapping it opens
        // no dialog (rather than opening one whose save is then dropped).
        expect(
          tester
              .widget<InkWell>(find.byKey(const Key('menstrual-day-2026-07-05')))
              .onTap,
          isNull,
        );
        expect(find.byKey(const Key('menstrual-busy')), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('menstrual-day-2026-07-05')),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('menstrual-save-period')), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();
        expect(repo.addCalls, [DateTime(2026, 7, 10)]);

        // Refused, not discarded: the same distinct action goes through once
        // the first write has settled.
        await addPeriodVia(tester, 'menstrual-day-2026-07-05');
        await tester.pumpAndSettle();
        expect(repo.addCalls, [DateTime(2026, 7, 10), DateTime(2026, 7, 5)]);
      },
    );

    // The undo action lives on a SnackBar, the one control that cannot be
    // disabled while another write is in flight — and `SnackBarAction` latches
    // and hides its bar on press, before the guard can refuse. So a refusal
    // must put the prompt back, action and all: telling the user to "try again
    // in a moment" while removing the only thing left to try again on would
    // leave the period deleted with no way back.
    testWidgets('a refused undo keeps the undo available to retry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeMenstrualRepository();
      await repo.addPeriod(
        'tok',
        startDate: DateTime(2026, 7, 10),
        endDate: DateTime(2026, 7, 14),
      );
      repo.addCalls.clear();
      // Ungated until the second write, so the delete (and its undo prompt)
      // complete normally first.
      Completer<void>? gate;
      final controller = _controllerFor(repo);
      await controller.load('tok');
      await tester.pumpWidget(
        l10nTestApp(
          home: MenstrualScreen(
            controller: controller,
            idToken: () async {
              if (gate != null) await gate.future;
              return 'tok';
            },
            clock: () => DateTime(2026, 7, 22),
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Delete the period; the undo prompt appears.
      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menstrual-delete-period')));
      await tester.pumpAndSettle();
      expect(repo.deleteCalls, ['p1']);
      expect(find.text(loc.menstrualUndo), findsOneWidget);

      // Start a second, distinct write and hold it open on the token.
      gate = Completer<void>();
      await tester.tap(find.byKey(const Key('menstrual-day-2026-07-05')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('menstrual-save-period')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The undo prompt is still on screen and still tappable.
      await tester.tap(find.text(loc.menstrualUndo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Refused out loud: no re-add was issued, the user is told why — and the
      // Undo is still on screen, which is what makes "try again" true.
      expect(repo.addCalls, isEmpty);
      expect(find.text(loc.trackerStillSaving), findsOneWidget);
      expect(find.text(loc.menstrualUndo), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.addCalls, [DateTime(2026, 7, 5)]);

      // And it really works the second time: the deleted period comes back.
      expect(find.text(loc.menstrualUndo), findsOneWidget);
      await tester.tap(find.text(loc.menstrualUndo));
      await tester.pumpAndSettle();
      expect(repo.addCalls, [DateTime(2026, 7, 5), DateTime(2026, 7, 10)]);
    });

    // The visible half: the add button disables and the busy bar appears
    // during token resolution, not only once the controller reaches `saving`.
    testWidgets('the add button is disabled and the busy bar shows', (
      tester,
    ) async {
      final repo = FakeMenstrualRepository();
      final gate = Completer<void>();
      await pumpGatedToken(tester, repo, gate);

      await addPeriodVia(tester, 'menstrual-day-2026-07-10');

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('menstrual-add-button')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('menstrual-busy')), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  // The screen's own overflow guard: the legend Row was centred and
  // non-shrinkable, so its two items ran 60px past a 320dp/en surface.
  // Asserts *no layout error of any kind* rather than draining with
  // `takeException()` — see `test/support/layout_guard.dart`.
  group('narrow-width layout guard', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'the screen lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, 2400));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              await expectNoLayoutErrors(
                () => _pumpScreen(
                  tester,
                  FakeMenstrualRepository(),
                  locale: locale,
                ),
              );

              // A blank screen also reports no layout error, so pin that the
              // calendar this guard is about actually rendered.
              expect(
                find.byKey(const Key('menstrual-month-label')),
                findsOneWidget,
              );
            },
          );
        }
      }
    }
  });
}
