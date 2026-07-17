/// Port for Firebase email/password authentication.
abstract class AuthRepository {
  Future<void> signIn(String email, String password);
  Future<void> signOut();

  /// The current user's ID token, or `null` if signed out.
  Future<String?> idToken();

  /// Emits `true` when a user is signed in, `false` when signed out.
  Stream<bool> get authStateChanges;
}
