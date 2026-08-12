import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../domain/auth_exceptions.dart';
import '../domain/auth_repository.dart';
import 'firebase_auth_error_messages.dart';

/// [AuthRepository] driven adapter backed by `firebase_auth`.
///
/// Firebase error codes are translated to typed [AuthFailureCode]s via
/// [authFailureCodeFor] — internal detail is never surfaced.
class FirebaseAuthRepository implements AuthRepository, CurrentUidProvider {
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
      throw AuthFailure(authFailureCodeFor(e.code));
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthFailure(authFailureCodeFor(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthFailure(authFailureCodeFor(e.code));
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

  @override
  String? get currentUid => _auth.currentUser?.uid;
}
