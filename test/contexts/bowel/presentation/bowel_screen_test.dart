import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_exceptions.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/last_loaded_label.dart';

import '../../../support/l10n_test_app.dart';

/// A backend-like fake: keeps the last-saved record so save→reload round-trips
/// read back real state.
class FakeBowelRepository implements BowelRepository {
  BowelDay stored;
  Object? getError;
  Object? saveError;

  int? savedCount;
  bool? savedIsNormal;
  String? savedNote;
  int getDayCallCount = 0;
  String? lastGetDay;

  FakeBowelRepository({BowelDay? stored})
    : stored =
          stored ??
          const BowelDay(
            day: '2026-07-18',
            count: 0,
            isNormal: null,
            note: '',
          );

  @override
  Future<BowelDay> getDay(String idToken, String day) async {
    getDayCallCount++;
    lastGetDay = day;
    if (getError != null) throw getError!;
    return stored;
  }

  @override
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) async {
    if (saveError != null) throw saveError!;
    savedCount = count;
    savedIsNormal = isNormal;
    savedNote = note;
    stored = BowelDay(day: day, count: count, isNormal: isNormal, note: note);
    return stored;
  }
}

BowelController _controller(FakeBowelRepository repository) =>
    BowelController(GetBowelDay(repository), SaveBowelDay(repository));

Future<BowelController> _pumpScreen(
  WidgetTester tester, {
  required FakeBowelRepository repository,
  bool load = true,
  Locale locale = const Locale('en'),
  String day = '2026-07-18',
  DateTime Function() clock = _defaultClock,
}) async {
  final controller = _controller(repository);
  if (load) await controller.load('token', day);
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      home: BowelScreen(
        controller: controller,
        idToken: 'token',
        day: day,
        clock: clock,
      ),
    ),
  );
  if (load) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return controller;
}

DateTime _defaultClock() => DateTime(2026, 7, 18, 9);

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('BowelScreen', () {
    testWidgets('for today shows the today title and today\'s date', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeBowelRepository(),
        day: '2026-07-18',
        clock: () => DateTime(2026, 7, 18, 9),
      );

      final expectedDate = DateFormat(
        'EEE, MMM d',
        'en',
      ).format(DateTime(2026, 7, 18));

      expect(find.text(loc.bowelTitle), findsOneWidget);
      expect(find.text(loc.bowelHistoryTitle), findsNothing);
      expect(find.textContaining(expectedDate), findsOneWidget);
    });

    testWidgets('for a past day shows the history title', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeBowelRepository(),
        day: '2026-07-17',
        clock: () => DateTime(2026, 7, 18, 9),
      );

      expect(find.text(loc.bowelHistoryTitle), findsOneWidget);
      expect(find.text(loc.bowelTitle), findsNothing);
    });

    testWidgets('the count stepper increments and decrements', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeBowelRepository(
          stored: const BowelDay(
            day: '2026-07-18',
            count: 1,
            isNormal: null,
            note: '',
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bowel-count-increment')));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bowel-count-decrement')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('the count does not go below zero', (tester) async {
      final controller = await _pumpScreen(
        tester,
        repository: FakeBowelRepository(),
      );

      // Decrement is disabled at 0.
      final decrement = tester.widget<IconButton>(
        find.byKey(const Key('bowel-count-decrement')),
      );
      expect(decrement.onPressed, isNull);
      expect(controller.count, 0);
    });

    testWidgets('normal/abnormal starts unselected for an unrecorded day', (
      tester,
    ) async {
      await _pumpScreen(tester, repository: FakeBowelRepository());

      final segmented = tester.widget<SegmentedButton<bool>>(
        find.byKey(const Key('bowel-normal-segment')),
      );
      expect(segmented.selected, isEmpty);
    });

    testWidgets('entering a record and saving persists count, flag, and note', (
      tester,
    ) async {
      final repository = FakeBowelRepository();
      await _pumpScreen(tester, repository: repository);

      await tester.tap(find.byKey(const Key('bowel-count-increment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bowel-count-increment')));
      await tester.pump();
      await tester.tap(find.text(loc.bowelNormalLabel));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('bowel-note-field')),
        'all good',
      );
      await tester.tap(find.byKey(const Key('bowel-save-button')));
      await tester.pumpAndSettle();

      expect(repository.savedCount, 2);
      expect(repository.savedIsNormal, true);
      expect(repository.savedNote, 'all good');
    });

    testWidgets('a save failure shows a snackbar and keeps the entered values', (
      tester,
    ) async {
      final repository = FakeBowelRepository();
      await _pumpScreen(tester, repository: repository);

      await tester.tap(find.byKey(const Key('bowel-count-increment')));
      await tester.pump();

      repository.saveError = const BowelFetchFailure('boom');
      await tester.tap(find.byKey(const Key('bowel-save-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.bowelSaveFailed), findsOneWidget);
      // The entered count survives the failed save.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('renders an error state without crashing', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeBowelRepository()
          ..getError = const BowelFetchFailure('boom'),
      );

      expect(find.text(loc.errorBowelLoadFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a reauth state without crashing', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeBowelRepository()
          ..getError = const BowelReauthenticationRequired(),
      );

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a loading indicator before the first load completes', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeBowelRepository(),
        load: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('captions the normal/abnormal segment', (tester) async {
      await _pumpScreen(tester, repository: FakeBowelRepository());

      expect(find.text(loc.bowelNormalityLabel), findsOneWidget);
    });

    testWidgets('the list is always scrollable so a short day still pulls', (
      tester,
    ) async {
      await _pumpScreen(tester, repository: FakeBowelRepository());

      expect(find.byType(RefreshIndicator), findsOneWidget);
      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(ListView),
        ),
      );
      expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('pulling to refresh reloads the viewed day', (tester) async {
      final repository = FakeBowelRepository();
      await _pumpScreen(tester, repository: repository, day: '2026-07-18');
      final before = repository.getDayCallCount;

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repository.getDayCallCount, before + 1);
      expect(repository.lastGetDay, '2026-07-18');
    });

    testWidgets('with no unsaved edits, pulling reloads without a prompt', (
      tester,
    ) async {
      final repository = FakeBowelRepository();
      await _pumpScreen(tester, repository: repository);
      final before = repository.getDayCallCount;

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.refreshDiscardTitle), findsNothing);
      expect(repository.getDayCallCount, before + 1);
    });

    testWidgets(
      'with unsaved edits, pulling asks first and cancelling keeps the draft '
      '(no reload)',
      (tester) async {
        final repository = FakeBowelRepository();
        final controller = await _pumpScreen(tester, repository: repository);

        controller.setCount(2);
        await tester.pump();
        expect(controller.hasUnsavedChanges, isTrue);
        final before = repository.getDayCallCount;

        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 300),
          1000,
        );
        // Not pumpAndSettle: the RefreshIndicator spinner animates until its
        // onRefresh future resolves, which is gated on this dialog — so settle
        // would time out. Pump enough frames to surface the dialog instead.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The confirm dialog is up; cancelling keeps the draft and reloads
        // nothing.
        expect(find.text(loc.refreshDiscardTitle), findsOneWidget);
        await tester.tap(find.text(loc.cancel));
        await tester.pumpAndSettle();

        expect(controller.count, 2);
        expect(controller.hasUnsavedChanges, isTrue);
        expect(repository.getDayCallCount, before);
      },
    );

    testWidgets(
      'with unsaved edits, confirming the discard reloads and drops the draft',
      (tester) async {
        final repository = FakeBowelRepository();
        final controller = await _pumpScreen(tester, repository: repository);

        controller.setCount(2);
        await tester.pump();
        final before = repository.getDayCallCount;

        await tester.fling(
          find.byType(RefreshIndicator),
          const Offset(0, 300),
          1000,
        );
        // See the cancel test: the spinner won't settle while the dialog is
        // open, so pump frames rather than settle.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text(loc.discard));
        await tester.pumpAndSettle();

        expect(repository.getDayCallCount, before + 1);
        // The reload reset the draft to the stored (empty) record.
        expect(controller.count, 0);
        expect(controller.hasUnsavedChanges, isFalse);
      },
    );

    testWidgets('shows the controller\'s last-loaded time', (tester) async {
      final controller = BowelController(
        GetBowelDay(FakeBowelRepository()),
        SaveBowelDay(FakeBowelRepository()),
        clock: () => DateTime(2026, 7, 18, 9, 41),
      );
      await controller.load('token', '2026-07-18');
      await tester.pumpWidget(
        l10nTestApp(
          home: BowelScreen(
            controller: controller,
            idToken: 'token',
            day: '2026-07-18',
            clock: _defaultClock,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = tester.widget<LastLoadedLabel>(
        find.byType(LastLoadedLabel),
      );
      expect(label.lastLoadedAt, DateTime(2026, 7, 18, 9, 41));
    });

    testWidgets(
      'shows an unsaved cue and enables Save only after an edit',
      (tester) async {
        await _pumpScreen(tester, repository: FakeBowelRepository());

        // A freshly loaded, unedited day has nothing to save.
        expect(find.byKey(const Key('bowel-unsaved-indicator')), findsNothing);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('bowel-save-button')))
              .onPressed,
          isNull,
        );

        // Editing the draft surfaces the cue and enables Save.
        await tester.tap(find.byKey(const Key('bowel-count-increment')));
        await tester.pump();
        expect(
          find.byKey(const Key('bowel-unsaved-indicator')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('bowel-save-button')))
              .onPressed,
          isNotNull,
        );
      },
    );
  });
}
