/// Port for Firebase email/password authentication.
abstract class AuthRepository {
  Future<void> signIn(String email, String password);

  /// Creates a new account with [email] and [password]. On success the user
  /// is signed in, mirroring `createUserWithEmailAndPassword`'s auto-sign-in
  /// behavior.
  Future<void> signUp(String email, String password);

  /// Asks the auth service to email [email] a password-reset link.
  ///
  /// Throws [AuthFailure] the same way the other methods do — including for
  /// an address with no account, which is why the caller is a use case and
  /// not a screen: whether that failure is shown is a policy decision, and
  /// showing it turns this into an account-enumeration oracle.
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// The current user's ID token, or `null` if signed out.
  Future<String?> idToken();

  /// Emits `true` when a user is signed in, `false` when signed out.
  Stream<bool> get authStateChanges;
}
