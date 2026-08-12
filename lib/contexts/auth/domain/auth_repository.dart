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

/// Optional companion port for auth adapters that can name the signed-in
/// user, read through [currentUidOf].
///
/// Separate from [AuthRepository] rather than a member on it — including a
/// member *with a default body* — because Dart requires every `implements`
/// clause to supply all interface members, defaults included: adding it to
/// [AuthRepository] does not compile until all 42 test fakes that implement
/// the port each grow a mechanical override. Kept out so the change stays
/// the size of the behaviour it adds.
///
/// The cost is that an adapter which forgets to implement this reads as
/// "signed out" instead of failing. That is absorbed by the one consumer:
/// [PrivacyMaskController] with no uid holds nothing and — the part that
/// matters — writes nothing, so a missing uid can never mix two accounts'
/// settings together.
abstract class CurrentUidProvider {
  /// The signed-in user's Firebase uid, or `null` when signed out.
  String? get currentUid;
}

/// [repository]'s signed-in uid, or `null` when it cannot supply one.
String? currentUidOf(AuthRepository repository) =>
    repository is CurrentUidProvider
    ? (repository as CurrentUidProvider).currentUid
    : null;
