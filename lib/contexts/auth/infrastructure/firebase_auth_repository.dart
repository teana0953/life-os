import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../domain/auth_exceptions.dart';
import '../domain/auth_repository.dart';
import 'firebase_auth_error_messages.dart';

/// [AuthRepository] driven adapter backed by `firebase_auth`.
///
/// Firebase error codes are translated to user-facing messages via
/// [friendlyAuthErrorMessage] — internal detail is never surfaced.
class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _auth;

  FirebaseAuthRepository(this._auth);

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthErrorMessage(e.code));
    }
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }

  @override
  Future<String?> idToken() {
    return _auth.currentUser?.getIdToken() ?? Future.value(null);
  }

  @override
  Stream<bool> get authStateChanges {
    return _auth.authStateChanges().map((user) => user != null);
  }
}
