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
        idToken: 'tok',
        clock: () => DateTime(2026, 7, 22),
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
            },
          );
        }
      }
    }
  });
}
