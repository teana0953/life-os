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

import '../../../support/l10n_test_app.dart';

/// A stateful in-memory fake so mutate→reload round-trips read back real state.
class FakeExerciseRepository implements ExerciseRepository {
  final Map<String, List<ExerciseEntry>> _byDay = {};
  int _nextId = 1;
  Object? failGetDay;
  int getDayCallCount = 0;
  String? lastGetDay;

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
        idToken: 'token',
        day: day,
        clock: _clock,
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
            idToken: 'token',
            day: '2026-07-18',
            clock: _clock,
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
                        idToken: 'token',
                        day: '2026-07-18',
                        clock: _clock,
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
          idToken: 'token',
          day: '2026-07-18',
          clock: _clock,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = tester.widget<LastLoadedLabel>(find.byType(LastLoadedLabel));
    expect(label.lastLoadedAt, DateTime(2026, 7, 18, 9, 41));
  });
}
