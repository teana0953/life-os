import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_exceptions.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_controller.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/last_loaded_label.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

import '../../../support/l10n_test_app.dart';

/// A stateful in-memory fake so mutate→reload round-trips read back real state.
class FakeExerciseRepository implements ExerciseRepository {
  final Map<String, List<ExerciseEntry>> _byDay = {};
  int _nextId = 1;
  Object? failGetDay;
  int getDayCallCount = 0;
  String? lastGetDay;

  /// Every entry id [deleteEntry] was called with, in order — deleting the
  /// same id twice leaves the same state, so only the call list can tell one
  /// delete from two.
  final List<String> deleteCalls = [];

  /// Every activity id [addEntry] was called with, in order — lets a test
  /// assert a refused undo issued no re-add at all.
  final List<String> addCalls = [];

  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async => const [
    ExerciseActivity(
      id: 'jogging',
      name: '慢跑',
      category: 'aerobic',
      intensity: '8km/hr',
    ),
    ExerciseActivity(
      id: 'squats',
      name: '深蹲',
      category: 'anaerobic',
      intensity: '',
    ),
  ];

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async {
    getDayCallCount++;
    lastGetDay = day;
    if (failGetDay != null) throw failGetDay!;
    final entries = _byDay[day] ?? const [];
    return ExerciseDay(
      day: day,
      entries: List.of(entries),
      totalMinutes: entries.fold(0, (s, e) => s + e.durationMinutes),
    );
  }

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) async {
    addCalls.add(activityId);
    final entry = ExerciseEntry(
      id: 'e${_nextId++}',
      activityId: activityId,
      activityName: activityId == 'jogging' ? '慢跑' : '深蹲',
      category: 'aerobic',
      durationMinutes: durationMinutes,
      note: note,
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );
    (_byDay[day] ??= []).add(entry);
    return entry;
  }

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async {
    deleteCalls.add(entryId);
    for (final entries in _byDay.values) {
      entries.removeWhere((e) => e.id == entryId);
    }
    return true;
  }
}

ExerciseController _controller(FakeExerciseRepository repo) => ExerciseController(
  ListExerciseActivities(repo),
  GetExerciseDay(repo),
  AddExerciseEntry(repo),
  DeleteExerciseEntry(repo),
);

DateTime _clock() => DateTime.utc(2026, 7, 18, 9);

Future<ExerciseController> _pumpScreen(
  WidgetTester tester, {
  required FakeExerciseRepository repository,
  bool load = true,
  String day = '2026-07-18',
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _controller(repository);
  if (load) await controller.load('token', day);
  await tester.pumpWidget(
    l10nTestApp(
      home: ExerciseScreen(
        controller: controller,
        idToken: () async => 'token',
        day: day,
        clock: _clock,
        onSignInAgain: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

final _loc = lookupAppLocalizations(const Locale('en'));

Future<void> _addEntry(
  WidgetTester tester, {
  required String activityKey,
  required String minutes,
}) async {
  await tester.tap(find.byKey(const Key('exercise-add-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(activityKey)));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('exercise-duration-field')), minutes);
  await tester.pump();
  await tester.tap(find.byKey(const Key('exercise-add-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unrecorded day shows no entries and a zero total', (tester) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

    expect(find.byKey(const Key('exercise-empty')), findsOneWidget);

    // Tier 2 (unify-empty-states): the shared one-line muted note — not a
    // page-sized guide dropped inside a card or a section.
    expect(
      find.ancestor(
        of: find.byKey(const Key('exercise-empty')),
        matching: find.byType(EmptyStateNote),
      ),
      findsOneWidget,
    );
    expect(find.byType(EmptyStateGuide), findsNothing);
    expect(find.text(_loc.exerciseTotalMinutes(0)), findsOneWidget);
    expect(find.byKey(const Key('exercise-remove-0')), findsNothing);
  });

  testWidgets('shows the day header and total', (tester) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

    expect(find.text(_loc.exerciseTitle), findsOneWidget);
  });

  testWidgets('appending an entry adds it to the list and grows the total', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

    await _addEntry(tester, activityKey: 'exercise-activity-jogging', minutes: '30');

    expect(find.text('慢跑'), findsOneWidget);
    expect(find.byKey(const Key('exercise-remove-0')), findsOneWidget);
    expect(find.text(_loc.exerciseTotalMinutes(30)), findsOneWidget);
  });

  testWidgets('appending a second entry accumulates the total', (tester) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

    await _addEntry(tester, activityKey: 'exercise-activity-jogging', minutes: '30');
    await _addEntry(tester, activityKey: 'exercise-activity-squats', minutes: '20');

    expect(find.byKey(const Key('exercise-remove-1')), findsOneWidget);
    expect(find.text(_loc.exerciseTotalMinutes(50)), findsOneWidget);
  });

  testWidgets('an empty or non-positive duration cannot be submitted', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

    await tester.tap(find.byKey(const Key('exercise-add-button')));
    await tester.pumpAndSettle();

    // Activity chosen but duration empty → confirm disabled.
    await tester.tap(find.byKey(const Key('exercise-activity-jogging')));
    await tester.pump();
    var confirm = tester.widget<FilledButton>(
      find.byKey(const Key('exercise-add-confirm')),
    );
    expect(confirm.onPressed, isNull);

    // A zero duration is still not submittable.
    await tester.enterText(find.byKey(const Key('exercise-duration-field')), '0');
    await tester.pump();
    confirm = tester.widget<FilledButton>(
      find.byKey(const Key('exercise-add-confirm')),
    );
    expect(confirm.onPressed, isNull);

    // A positive whole number enables it.
    await tester.enterText(find.byKey(const Key('exercise-duration-field')), '15');
    await tester.pump();
    confirm = tester.widget<FilledButton>(
      find.byKey(const Key('exercise-add-confirm')),
    );
    expect(confirm.onPressed, isNotNull);
  });

  testWidgets('removing an entry drops it and reduces the total', (tester) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

    await _addEntry(tester, activityKey: 'exercise-activity-jogging', minutes: '30');
    await _addEntry(tester, activityKey: 'exercise-activity-squats', minutes: '20');
    expect(find.text(_loc.exerciseTotalMinutes(50)), findsOneWidget);

    await tester.tap(find.byKey(const Key('exercise-remove-0')));
    await tester.pumpAndSettle();

    expect(find.text('慢跑'), findsNothing);
    expect(find.text('深蹲'), findsOneWidget);
    expect(find.text(_loc.exerciseTotalMinutes(20)), findsOneWidget);
  });

  testWidgets('a load failure shows an error state rather than crashing', (
    tester,
  ) async {
    final repo = FakeExerciseRepository()..failGetDay = const ExerciseFetchFailure();
    await _pumpScreen(tester, repository: repo);

    expect(find.text(_loc.errorExerciseLoadFailed), findsOneWidget);
  });

  testWidgets(
    'the loading state still shows an app bar (back affordance) plus a spinner',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Do NOT load: the controller stays in its initial loading state
      // (day == null), so AsyncStateScaffold renders its loading Scaffold.
      final controller = _controller(FakeExerciseRepository());
      await tester.pumpWidget(
        l10nTestApp(
          home: ExerciseScreen(
            controller: controller,
            idToken: () async => 'token',
            day: '2026-07-18',
            clock: _clock,
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pump();

      expect(controller.status, ExerciseStatus.loading);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'a reauth after entering the pushed tracker keeps a back button (not trapped)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeExerciseRepository()
        ..failGetDay = const ExerciseReauthenticationRequired();
      final controller = _controller(repo);
      await controller.load('token', '2026-07-18');

      await tester.pumpWidget(
        l10nTestApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open-exercise'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExerciseScreen(
                        controller: controller,
                        idToken: () async => 'token',
                        day: '2026-07-18',
                        clock: _clock,
                        onSignInAgain: () {},
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-exercise')));
      await tester.pumpAndSettle();

      expect(controller.status, ExerciseStatus.needsReauth);
      expect(find.text(_loc.pleaseSignInAgain), findsOneWidget);
      // The reauth state still exposes the pushed route's back button.
      expect(find.byType(BackButton), findsOneWidget);
    },
  );

  testWidgets(
    'removing an entry shows an Undo SnackBar that re-adds it',
    (tester) async {
      await _pumpScreen(tester, repository: FakeExerciseRepository());

      await _addEntry(
        tester,
        activityKey: 'exercise-activity-jogging',
        minutes: '30',
      );
      expect(find.text('慢跑'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exercise-remove-0')));
      await tester.pumpAndSettle();

      // Removed, and an Undo SnackBar is offered.
      expect(find.text('慢跑'), findsNothing);
      expect(find.text(_loc.exerciseEntryRemoved), findsOneWidget);
      expect(find.text(_loc.exerciseUndo), findsOneWidget);

      // Undo re-adds it via a fresh addEntry (the fake repo records the add,
      // so the entry and its minutes reappear).
      await tester.tap(find.text(_loc.exerciseUndo));
      await tester.pumpAndSettle();

      expect(find.text('慢跑'), findsOneWidget);
      expect(find.text(_loc.exerciseTotalMinutes(30)), findsOneWidget);
    },
  );

  testWidgets(
    'the duration field uses an integer (non-decimal) keyboard',
    (tester) async {
      await _pumpScreen(tester, repository: FakeExerciseRepository());

      await tester.tap(find.byKey(const Key('exercise-add-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('exercise-duration-field')),
      );
      expect(field.keyboardType.decimal, isFalse);
    },
  );

  testWidgets('the list is always scrollable so a short day still pulls', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: FakeExerciseRepository());

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
    final repository = FakeExerciseRepository();
    await _pumpScreen(tester, repository: repository, day: '2026-07-18');
    final before = repository.getDayCallCount;

    // Drag down far enough to clear the RefreshIndicator's arm threshold on
    // the tall (1600px) test surface, pumping the intermediate frames the
    // indicator needs to fire its onRefresh.
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 600),
      2000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repository.getDayCallCount, before + 1);
    expect(repository.lastGetDay, '2026-07-18');
  });

  testWidgets('shows the controller\'s last-loaded time', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeExerciseRepository();
    final controller = ExerciseController(
      ListExerciseActivities(repo),
      GetExerciseDay(repo),
      AddExerciseEntry(repo),
      DeleteExerciseEntry(repo),
      clock: () => DateTime(2026, 7, 18, 9, 41),
    );
    await controller.load('token', '2026-07-18');
    await tester.pumpWidget(
      l10nTestApp(
        home: ExerciseScreen(
          controller: controller,
          idToken: () async => 'token',
          day: '2026-07-18',
          clock: _clock,
          onSignInAgain: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = tester.widget<LastLoadedLabel>(find.byType(LastLoadedLabel));
    expect(label.lastLoadedAt, DateTime(2026, 7, 18, 9, 41));
  });

  // The ID token is resolved at request time, so between the tap and the
  // controller's `saving` status there is a whole token round trip during
  // which nothing in the controller has changed yet. That window has to be
  // closed by the screen itself, or a second tap starts a second write.
  group('while the ID token is still resolving', () {
    /// Pumps a loaded screen holding one entry, with a token provider held
    /// open by [gate].
    Future<void> pumpGatedToken(
      WidgetTester tester,
      FakeExerciseRepository repository,
      Completer<void> gate,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await repository.addEntry(
        'token',
        day: '2026-07-18',
        activityId: 'jogging',
        durationMinutes: 30,
        note: '',
      );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      await tester.pumpWidget(
        l10nTestApp(
          home: ExerciseScreen(
            controller: controller,
            idToken: () async {
              await gate.future;
              return 'token';
            },
            day: '2026-07-18',
            clock: _clock,
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Two taps inside one frame: the disable only takes effect on the next
    // rebuild, so the second tap still reaches the enabled control and only
    // the re-entrancy check in `_runMutation` can drop it.
    testWidgets('a same-frame second remove tap deletes only once', (
      tester,
    ) async {
      final repository = FakeExerciseRepository();
      final gate = Completer<void>();
      await pumpGatedToken(tester, repository, gate);

      await tester.tap(find.byKey(const Key('exercise-remove-0')));
      await tester.tap(find.byKey(const Key('exercise-remove-0')));

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, ['e1']);
    });

    // A dropped `_runMutation` leaves the controller on `loaded`, so a caller
    // that only checks the status would announce a removal that never
    // happened — and offer an Undo that, tapped, would re-add an entry that
    // was never deleted.
    testWidgets('a dropped remove shows no success message and no undo', (
      tester,
    ) async {
      final repository = FakeExerciseRepository();
      final gate = Completer<void>();
      await pumpGatedToken(tester, repository, gate);

      // Same-frame double tap: the second call is dropped by the guard while
      // the first is still blocked on the token.
      await tester.tap(find.byKey(const Key('exercise-remove-0')));
      await tester.tap(find.byKey(const Key('exercise-remove-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Nothing has been deleted yet, so nothing may claim it has.
      expect(repository.deleteCalls, isEmpty);
      expect(find.text(_loc.exerciseEntryRemoved), findsNothing);
      expect(find.text(_loc.exerciseUndo), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, ['e1']);
    });

    // The undo action lives on a SnackBar, the one control that cannot be
    // disabled while another write is in flight — and `SnackBarAction` latches
    // and hides its bar on press, before the guard can refuse. So a refusal
    // must put the prompt back, action and all: telling the user to "try again
    // in a moment" while removing the only thing left to try again on would
    // leave the entry deleted with no way back.
    testWidgets('a refused undo keeps the undo available to retry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeExerciseRepository();
      await repository.addEntry(
        'token',
        day: '2026-07-18',
        activityId: 'jogging',
        durationMinutes: 30,
        note: '',
      );
      // Ungated until the second write, so the remove (and its undo prompt)
      // complete normally first.
      Completer<void>? gate;
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      await tester.pumpWidget(
        l10nTestApp(
          home: ExerciseScreen(
            controller: controller,
            idToken: () async {
              if (gate != null) await gate.future;
              return 'token';
            },
            day: '2026-07-18',
            clock: _clock,
            onSignInAgain: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.addCalls.clear();

      await tester.tap(find.byKey(const Key('exercise-remove-0')));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, ['e1']);
      expect(find.text(_loc.exerciseUndo), findsOneWidget);

      // Start a second, distinct write and hold it open on the token.
      gate = Completer<void>();
      await tester.tap(find.byKey(const Key('exercise-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-activity-squats')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('exercise-duration-field')),
        '15',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('exercise-add-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text(_loc.exerciseUndo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Refused out loud: no re-add was issued, the user is told why — and the
      // Undo is still on screen, which is what makes "try again" true.
      expect(repository.addCalls, isEmpty);
      expect(find.text(_loc.trackerStillSaving), findsOneWidget);
      expect(find.text(_loc.exerciseUndo), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(repository.addCalls, ['squats']);

      // And it really works the second time: the removed entry comes back.
      expect(find.text(_loc.exerciseUndo), findsOneWidget);
      await tester.tap(find.text(_loc.exerciseUndo));
      await tester.pumpAndSettle();
      expect(repository.addCalls, ['squats', 'jogging']);
    });

    // The visible half: the control disables and the busy bar appears during
    // token resolution, not only once the controller reaches `saving` — so a
    // later tap can't land either.
    testWidgets(
      'the remove control is disabled, the busy bar shows, and a later tap '
      'deletes nothing more',
      (tester) async {
        final repository = FakeExerciseRepository();
        final gate = Completer<void>();
        await pumpGatedToken(tester, repository, gate);

        await tester.tap(find.byKey(const Key('exercise-remove-0')));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('exercise-remove-0')))
              .onPressed,
          isNull,
        );
        expect(find.byKey(const Key('exercise-busy')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('exercise-remove-0')),
          warnIfMissed: false,
        );
        await tester.pump();

        gate.complete();
        await tester.pumpAndSettle();

        expect(repository.deleteCalls, ['e1']);
      },
    );
  });
}
