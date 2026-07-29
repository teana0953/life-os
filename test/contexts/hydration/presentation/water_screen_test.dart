import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_exceptions.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';
import 'package:life_os/contexts/hydration/presentation/water_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/widgets/last_loaded_label.dart';

import '../../../support/l10n_test_app.dart';

/// A backend-like fake: keeps a running total (clamped ≥0, as the backend
/// does) and target, so quick-add/correct/set-target flows read back real
/// state via [getDay].
class FakeWaterRepository implements WaterRepository {
  int total;
  int target;
  Object? getError;

  /// The day passed to the most recent [getDay] — lets a refresh test assert
  /// the reload targeted the viewed day.
  String? lastGetDay;
  int getDayCallCount = 0;

  FakeWaterRepository({this.total = 0, this.target = 2000});

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    getDayCallCount++;
    lastGetDay = day;
    if (getError != null) throw getError!;
    return WaterDay(
      day: day,
      totalMl: total,
      targetMl: target,
      remainingMl: target - total,
    );
  }

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async {
    total = (total + addMl).clamp(0, 1 << 30);
    return total;
  }

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async {
    target = targetMl;
    return target;
  }
}

/// A repository whose day-fetch can be held open via [getGate], so a test can
/// pin the controller in a mid-reload `loading` state (day still present) and
/// inspect what the screen renders during a mutation reload.
class GatedWaterRepository extends FakeWaterRepository {
  Completer<void>? getGate;

  GatedWaterRepository({super.total, super.target});

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    if (getGate != null) await getGate!.future;
    return super.getDay(idToken, day);
  }
}

WaterController _controller(FakeWaterRepository repository) => WaterController(
  GetWaterDay(repository),
  AddWater(repository),
  SetWaterTarget(repository),
);

Future<WaterController> _pumpScreen(
  WidgetTester tester, {
  required FakeWaterRepository repository,
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
      home: WaterScreen(
        controller: controller,
        idToken: 'token',
        day: day,
        clock: clock,
      ),
    ),
  );
  // A loading screen shows an animating spinner that never settles.
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

  group('WaterScreen', () {
    testWidgets('for today shows the today title and today\'s date', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 500, target: 2000),
        day: '2026-07-18',
        clock: () => DateTime(2026, 7, 18, 9),
      );

      final expectedDate = DateFormat(
        'EEE, MMM d',
        'en',
      ).format(DateTime(2026, 7, 18));

      expect(find.text(loc.waterTitle), findsOneWidget);
      expect(find.text(loc.waterHistoryTitle), findsNothing);
      expect(find.textContaining(expectedDate), findsOneWidget);
    });

    testWidgets(
      'for a past day shows that day\'s date and the history title, not the '
      'today title',
      (tester) async {
        await _pumpScreen(
          tester,
          repository: FakeWaterRepository(total: 500, target: 2000),
          day: '2026-07-17',
          clock: () => DateTime(2026, 7, 18, 9),
        );

        final expectedDate = DateFormat(
          'EEE, MMM d',
          'en',
        ).format(DateTime(2026, 7, 17));

        expect(find.text(loc.waterHistoryTitle), findsOneWidget);
        expect(find.text(loc.waterTitle), findsNothing);
        expect(find.textContaining(expectedDate), findsOneWidget);
      },
    );

    testWidgets('shows the total-over-target readout', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 500, target: 2000),
      );

      expect(find.text(loc.waterTotalOfTarget(500, 2000)), findsOneWidget);
    });

    testWidgets('quick-adding ＋250 twice raises the total to 500', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 0, target: 2000),
      );

      await tester.tap(find.byKey(const Key('water-add-250')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('water-add-250')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterTotalOfTarget(500, 2000)), findsOneWidget);
    });

    testWidgets('the ＋500 control adds 500', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 0, target: 2000),
      );

      await tester.tap(find.byKey(const Key('water-add-500')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterTotalOfTarget(500, 2000)), findsOneWidget);
    });

    testWidgets('a custom amount of 320 is added to the total', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 0, target: 2000),
      );

      await tester.tap(find.byKey(const Key('water-add-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('water-amount-field')), '320');
      await tester.tap(find.byKey(const Key('water-amount-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterTotalOfTarget(320, 2000)), findsOneWidget);
    });

    testWidgets('correcting an over-count never goes below zero', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 200, target: 2000),
      );

      await tester.tap(find.byKey(const Key('water-correct-250')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterTotalOfTarget(0, 2000)), findsOneWidget);
    });

    testWidgets('setting the target updates the progress basis', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 500, target: 0),
      );

      await tester.tap(find.byKey(const Key('water-set-target')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('water-amount-field')), '2000');
      await tester.tap(find.byKey(const Key('water-amount-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterTotalOfTarget(500, 2000)), findsOneWidget);
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.25, 0.0001));
    });

    testWidgets('over-target the progress bar fill clamps at 100%', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 2500, target: 2000),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 1.0);
    });

    testWidgets('shows a loading indicator before the first load completes', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(),
        load: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders an error state without crashing', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository()..getError = const WaterFetchFailure('boom'),
      );

      expect(find.text(loc.errorWaterLoadFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'during a mutation reload keeps the content visible and shows only a '
      'subtle busy indicator (no full-screen spinner)',
      (tester) async {
        final repository = GatedWaterRepository(total: 500, target: 2000);
        final controller = _controller(repository);
        await controller.load('token', '2026-07-18');
        await tester.pumpWidget(
          l10nTestApp(
            home: WaterScreen(
              controller: controller,
              idToken: 'token',
              day: '2026-07-18',
              clock: _defaultClock,
            ),
          ),
        );
        await tester.pump();

        // Hold the reload open so the controller stays in `loading` with the
        // previously-loaded day still present.
        repository.getGate = Completer<void>();
        await tester.tap(find.byKey(const Key('water-add-250')));
        await tester.pump();
        await tester.pump();

        // Content stays visible — no blanking to a bare full-screen spinner.
        expect(find.text(loc.waterTotalOfTarget(500, 2000)), findsOneWidget);
        expect(find.byKey(const Key('water-add-250')), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // A subtle busy indicator is shown instead.
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        repository.getGate!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a failed quick-add shows a save-failed snackbar and keeps the '
        'previous total', (tester) async {
      final repository = FakeWaterRepository(total: 500, target: 2000);
      await _pumpScreen(tester, repository: repository);

      // The mutation writes, but the reload fails: controller ends in `error`
      // with the previous day still shown.
      repository.getError = const WaterFetchFailure('boom');
      await tester.tap(find.byKey(const Key('water-add-250')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterSaveFailed), findsOneWidget);
      expect(find.text(loc.waterTotalOfTarget(500, 2000)), findsOneWidget);
    });

    testWidgets('a successful quick-add shows no save-failed snackbar', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 0, target: 2000),
      );

      await tester.tap(find.byKey(const Key('water-add-250')));
      await tester.pumpAndSettle();

      expect(find.text(loc.waterSaveFailed), findsNothing);
      expect(find.text(loc.waterTotalOfTarget(250, 2000)), findsOneWidget);
    });

    testWidgets('at or over target shows the goal-met badge and success fill', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 2000, target: 2000),
      );

      expect(find.text(loc.waterGoalMet), findsOneWidget);

      final scheme = Theme.of(
        tester.element(find.byType(FractionallySizedBox)),
      ).colorScheme;
      final fill = tester.widget<Container>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(Container),
        ),
      );
      expect((fill.decoration as BoxDecoration).color, scheme.tertiary);
    });

    testWidgets('below target shows no goal-met badge', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 500, target: 2000),
      );

      expect(find.text(loc.waterGoalMet), findsNothing);
    });

    testWidgets('renders a reauth state without crashing', (tester) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository()
          ..getError = const WaterReauthenticationRequired(),
      );

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list is always scrollable so a short day still pulls', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        repository: FakeWaterRepository(total: 500, target: 2000),
      );

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
      final repository = FakeWaterRepository(total: 500, target: 2000);
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

    testWidgets('shows the controller\'s last-loaded time', (tester) async {
      final controller = WaterController(
        GetWaterDay(FakeWaterRepository(total: 500, target: 2000)),
        AddWater(FakeWaterRepository()),
        SetWaterTarget(FakeWaterRepository()),
        clock: () => DateTime(2026, 7, 18, 9, 41),
      );
      await controller.load('token', '2026-07-18');
      await tester.pumpWidget(
        l10nTestApp(
          home: WaterScreen(
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
  });
}
