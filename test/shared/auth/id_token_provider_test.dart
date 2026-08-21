import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/shared/auth/id_token_provider.dart';
import 'package:life_os/shared/config.dart';

/// An [AuthRepository] whose `idToken()` behaves however one test needs it to.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._idToken);

  final Future<String?> Function() _idToken;

  @override
  Future<String?> idToken() => _idToken();

  @override
  Stream<bool> get authStateChanges => const Stream<bool>.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}
}

/// Records how a future finished without awaiting it — inside `fakeAsync` an
/// `await` in the test body would deadlock, since only the body advances time.
class _Outcome {
  bool done = false;
  String? value;

  void watch(Future<String> future) {
    future.then((v) {
      value = v;
      done = true;
    });
  }
}

void main() {
  test('resolves the token when the repository answers', () async {
    final token = await guardedIdToken(
      _FakeAuthRepository(() async => 'token-123'),
    );

    expect(token, 'token-123');
  });

  test('resolves to empty when the repository throws', () async {
    final token = await guardedIdToken(
      _FakeAuthRepository(() async => throw StateError('renewal failed')),
    );

    expect(token, '');
  });

  test('a renewal that never answers ends, rather than hanging forever', () {
    // A hung renewal is not a throw — it is silence, and every screen awaits
    // this before entering any controller. Unbounded, that is a screen frozen
    // on its first spinner with no controller state to show an error from
    // (issue #193).
    fakeAsync((async) {
      final outcome = _Outcome()
        ..watch(
          guardedIdToken(
            _FakeAuthRepository(() => Completer<String?>().future),
          ),
        );

      // Just inside the bound it is still waiting — the half that goes red if
      // the bound is shortened to near zero and a slow renewal starts being
      // called a failure.
      async.elapse(httpRequestTimeout - const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(outcome.done, isFalse);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(outcome.done, isTrue);
      // Empty, like every other failure here: the request goes out
      // unauthenticated and the existing 401 exit takes over.
      expect(outcome.value, '');
    });
  });
}
