import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_exceptions.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/body_profile/presentation/goal_card.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class _FakeRepository implements BodyProfileRepository {
  WeightGoal goalToReturn = const WeightGoal(targetWeightKg: 51);
  BodyProfile profileToReturn = const BodyProfile();
  Object? getError;

  double? lastSetHeightCm;
  double? lastSetTargetWeightKg;
  bool setCalled = false;

  /// When set, `setBodyProfile` waits on this before completing — lets a test
  /// observe the in-flight saving state.
  Completer<void>? setGate;

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    if (getError != null) throw getError!;
    return goalToReturn;
  }

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async {
    if (getError != null) throw getError!;
    return profileToReturn;
  }

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async {
    setCalled = true;
    if (setGate != null) await setGate!.future;
    lastSetHeightCm = heightCm;
    lastSetTargetWeightKg = targetWeightKg;
    return BodyProfile(heightCm: heightCm, targetWeightKg: targetWeightKg);
  }
}

final _loc = lookupAppLocalizations(const Locale('en'));

Future<WeightGoalController> _loadedController(_FakeRepository repository) async {
  final controller = WeightGoalController(
    GetWeightGoal(repository),
    GetBodyProfile(repository),
    SetBodyProfile(repository),
  );
  await controller.load('token');
  return controller;
}

Future<void> _pumpCard(
  WidgetTester tester,
  WeightGoalController controller,
) async {
  await tester.pumpWidget(
    l10nTestApp(
      home: Scaffold(
        body: GoalCard(controller: controller, idToken: 'token'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('GoalCard set profile', () {
    testWidgets('shows target / current / remaining, a 75% ring, and BMI',
        (tester) async {
      final repository = _FakeRepository()
        ..goalToReturn = const WeightGoal(
          heightCm: 165,
          targetWeightKg: 51,
          currentWeightKg: 52,
          remainingKg: 1,
          achievementRate: 75,
          bmi: 19.1,
        );
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      expect(find.text('51'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(find.byKey(const Key('goal-ring')))
            .value,
        0.75,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('goal-bmi'))).data,
        '19.1',
      );
      // The ring carries a "達成率" label and an edit affordance hints the card
      // opens the edit sheet.
      expect(find.text(_loc.goalAchievementLabel), findsOneWidget);
      expect(find.byKey(const Key('goal-card-edit-icon')), findsOneWidget);
      // The ring exposes a single achievement Semantics node.
      expect(
        find.bySemanticsLabel('${_loc.goalAchievementLabel} 75%'),
        findsOneWidget,
      );
    });

    testWidgets('a null achievement and BMI show an empty ring and a placeholder',
        (tester) async {
      final repository = _FakeRepository()
        ..goalToReturn = const WeightGoal(targetWeightKg: 51);
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      expect(
        tester
            .widget<CircularProgressIndicator>(find.byKey(const Key('goal-ring')))
            .value,
        0.0,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('goal-bmi'))).data,
        _loc.goalPlaceholder,
      );
      // No false achievement number is rendered.
      expect(find.byKey(const Key('goal-achievement')), findsNothing);
    });
  });

  group('GoalCard unset profile', () {
    testWidgets('shows a "set your goal" prompt, not a row of placeholders',
        (tester) async {
      final repository = _FakeRepository()..goalToReturn = const WeightGoal();
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('goal-unset-prompt')), findsOneWidget);
      expect(find.byKey(const Key('goal-set-button')), findsOneWidget);
      expect(find.byKey(const Key('goal-bmi')), findsNothing);
    });
  });

  group('GoalCard error', () {
    testWidgets('a load failure shows an error state', (tester) async {
      final repository = _FakeRepository()
        ..getError = const BodyProfileFetchFailure();
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      expect(find.byKey(const Key('goal-card-error')), findsOneWidget);
    });

    testWidgets('a reload failure after a successful load surfaces the error',
        (tester) async {
      final repository = _FakeRepository()
        ..goalToReturn = const WeightGoal(
          heightCm: 165,
          targetWeightKg: 51,
          bmi: 19.1,
        );
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);
      // The loaded card is shown.
      expect(find.byKey(const Key('goal-bmi')), findsOneWidget);

      // A subsequent reload fails — the stale card must give way to the error.
      repository.getError = const BodyProfileFetchFailure();
      await controller.load('token');
      await tester.pump();

      expect(find.byKey(const Key('goal-card-error')), findsOneWidget);
      expect(find.byKey(const Key('goal-bmi')), findsNothing);
    });
  });

  group('GoalCard saving', () {
    testWidgets('saving an already-set goal shows a spinner', (tester) async {
      final repository = _FakeRepository()
        ..goalToReturn = const WeightGoal(heightCm: 165, targetWeightKg: 51);
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      // Start a save that stays pending mid-flight.
      final gate = Completer<void>();
      repository.setGate = gate;
      unawaited(controller.saveProfile('token', targetWeightKg: 50));
      await tester.pump();

      // The save gives feedback even though a goal is already set.
      expect(find.byKey(const Key('goal-card-loading')), findsOneWidget);

      // Completing the save returns to the loaded card.
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('goal-card-loading')), findsNothing);
    });
  });

  group('GoalCard edit flow', () {
    testWidgets('tapping the card opens a modal bottom sheet, not a dialog',
        (tester) async {
      final repository = _FakeRepository()
        ..goalToReturn = const WeightGoal(targetWeightKg: 51);
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('goal-card')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('goal-height-field')), findsOneWidget);
      expect(find.byKey(const Key('goal-target-field')), findsOneWidget);
    });

    testWidgets('entering height and target and saving calls saveProfile',
        (tester) async {
      final repository = _FakeRepository()..goalToReturn = const WeightGoal();
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('goal-set-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('goal-height-field')), '165');
      await tester.enterText(find.byKey(const Key('goal-target-field')), '50');
      await tester.pump();
      await tester.tap(find.byKey(const Key('goal-save-button')));
      await tester.pumpAndSettle();

      expect(repository.setCalled, isTrue);
      expect(repository.lastSetHeightCm, 165);
      expect(repository.lastSetTargetWeightKg, 50);
    });

    testWidgets('a non-positive value cannot be saved', (tester) async {
      final repository = _FakeRepository()..goalToReturn = const WeightGoal();
      final controller = await _loadedController(repository);
      await _pumpCard(tester, controller);

      await tester.tap(find.byKey(const Key('goal-set-button')));
      await tester.pumpAndSettle();

      // A zero target keeps save disabled.
      await tester.enterText(find.byKey(const Key('goal-target-field')), '0');
      await tester.pump();
      var save = tester.widget<FilledButton>(
        find.byKey(const Key('goal-save-button')),
      );
      expect(save.onPressed, isNull);

      // A positive value enables it.
      await tester.enterText(find.byKey(const Key('goal-target-field')), '50');
      await tester.pump();
      save = tester.widget<FilledButton>(
        find.byKey(const Key('goal-save-button')),
      );
      expect(save.onPressed, isNotNull);
    });
  });
}
