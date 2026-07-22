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
  int getWeightGoalCalls = 0;

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    getWeightGoalCalls++;
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
          onOpenLog: () async {},
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
          onOpenLog: () async { opened = true; },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-record-entry')));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('reloads the goal after returning from the record shell',
      (tester) async {
    final auth = _FakeAuthRepository();
    final repo = _FakeRepository();
    await tester.pumpWidget(
      l10nTestApp(
        home: DashboardScreen(
          weightGoalController: _controller(repository: repo),
          authRepository: auth,
          signOut: SignOut(auth),
          onOpenLog: () async {}, // shell opened then popped immediately
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.getWeightGoalCalls, 1); // initial load

    await tester.tap(find.byKey(const Key('dashboard-record-entry')));
    await tester.pumpAndSettle();

    // Returning from the shell reloads, so a weight just recorded shows without
    // a manual refresh.
    expect(repo.getWeightGoalCalls, 2);
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
          onOpenLog: () async {},
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

  testWidgets(
      'the re-auth exit pops the pushed dashboard so the login screen shows',
      (tester) async {
    final auth = _FakeAuthRepository();
    final repository = _FakeRepository()
      ..getError = const BodyProfileReauthenticationRequired();
    final dashboard = DashboardScreen(
      weightGoalController: _controller(repository: repository),
      authRepository: auth,
      signOut: SignOut(auth),
      onOpenLog: () async {},
    );

    // Push the dashboard on top of a root route, mirroring how home pushes it.
    await tester.pumpWidget(
      l10nTestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => dashboard),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-sign-in-again-button')));
    await tester.pumpAndSettle();

    // Signed out, and the pushed dashboard is gone (revealing the root route).
    expect(auth.signedOut, isTrue);
    expect(find.byType(DashboardScreen), findsNothing);
  });
}
