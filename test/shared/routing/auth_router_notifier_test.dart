import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/shared/routing/auth_router_notifier.dart';

/// A minimal fake exposing a controllable `authStateChanges` stream; the other
/// [AuthRepository] members are unused by the notifier.
class _FakeAuthRepository implements AuthRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  final bool errorStream;

  _FakeAuthRepository({this.errorStream = false});

  void emit(bool signedIn) => _controller.add(signedIn);

  @override
  Stream<bool> get authStateChanges =>
      errorStream ? Stream<bool>.error(Exception('boom')) : _controller.stream;

  @override
  Future<String?> idToken() async => null;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  group('AuthRouterNotifier', () {
    test('starts in the loading state before the first auth event', () {
      final notifier = AuthRouterNotifier(_FakeAuthRepository());
      addTearDown(notifier.dispose);

      expect(notifier.loading, isTrue);
      expect(notifier.error, isFalse);
      expect(notifier.signedIn, isFalse);
    });

    test('a signed-in event clears loading and sets signedIn, notifying', () async {
      final repo = _FakeAuthRepository();
      final notifier = AuthRouterNotifier(repo);
      addTearDown(notifier.dispose);
      var notified = 0;
      notifier.addListener(() => notified++);

      repo.emit(true);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.loading, isFalse);
      expect(notifier.signedIn, isTrue);
      expect(notifier.error, isFalse);
      expect(notified, greaterThan(0));
    });

    test('a signed-out event sets signedIn false', () async {
      final repo = _FakeAuthRepository();
      final notifier = AuthRouterNotifier(repo);
      addTearDown(notifier.dispose);

      repo.emit(true);
      await Future<void>.delayed(Duration.zero);
      repo.emit(false);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.signedIn, isFalse);
      expect(notifier.loading, isFalse);
    });

    test('a stream error sets the error state and clears loading', () async {
      final notifier = AuthRouterNotifier(_FakeAuthRepository(errorStream: true));
      addTearDown(notifier.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.error, isTrue);
      expect(notifier.loading, isFalse);
    });

    test('retry returns to loading and re-subscribes', () async {
      final notifier = AuthRouterNotifier(_FakeAuthRepository(errorStream: true));
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.error, isTrue);

      notifier.retry();

      expect(notifier.loading, isTrue);
      expect(notifier.error, isFalse);
    });
  });
}
