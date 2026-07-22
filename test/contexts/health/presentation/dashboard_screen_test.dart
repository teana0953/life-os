import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_exceptions.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/body_profile/presentation/goal_card.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';
import 'package:life_os/contexts/health/presentation/dashboard_screen.dart';

import '../../../support/l10n_test_app.dart';

class _FakeRepository implements BodyProfileRepository {
  Object? getError;

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    if (getError != null) throw getError!;
    return const WeightGoal(targetWeightKg: 51);
  }

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async {
    if (getError != null) throw getError!;
    return const BodyProfile(heightCm: 165);
  }

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async => BodyProfile(heightCm: heightCm, targetWeightKg: targetWeightKg);
}

class _FakeAuthRepository implements AuthRepository {
  bool signedOut = false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

WeightGoalController _controller({_FakeRepository? repository}) {
  final repo = repository ?? _FakeRepository();
  return WeightGoalController(
    GetWeightGoal(repo),
    GetBodyProfile(repo),
    SetBodyProfile(repo),
  );
}

void main() {
  testWidgets('the dashboard shows the goal card and a record entry',
      (tester) async {
    final auth = _FakeAuthRepository();
    await tester.pumpWidget(
      l10nTestApp(
        home: DashboardScreen(
          weightGoalController: _controller(),
          authRepository: auth,
          signOut: SignOut(auth),
          onOpenLog: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoalCard), findsOneWidget);
    expect(find.byKey(const Key('dashboard-record-entry')), findsOneWidget);
  });

  testWidgets('activating the record entry invokes onOpenLog (opens the shell)',
      (tester) async {
    var opened = false;
    final auth = _FakeAuthRepository();
    await tester.pumpWidget(
      l10nTestApp(
        home: DashboardScreen(
          weightGoalController: _controller(),
          authRepository: auth,
          signOut: SignOut(auth),
          onOpenLog: () => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-record-entry')));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets(
      'a 401 surfaces a re-auth exit whose button signs out',
      (tester) async {
    final auth = _FakeAuthRepository();
    final repository = _FakeRepository()
      ..getError = const BodyProfileReauthenticationRequired();
    await tester.pumpWidget(
      l10nTestApp(
        home: DashboardScreen(
          weightGoalController: _controller(repository: repository),
          authRepository: auth,
          signOut: SignOut(auth),
          onOpenLog: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('dashboard-sign-in-again-button'));
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    expect(auth.signedOut, isTrue);
  });
}
