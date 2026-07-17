/// Maps a `firebase_auth` `FirebaseAuthException.code` to a user-facing
/// message, without leaking internal error detail.
String friendlyAuthErrorMessage(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Incorrect email or password.';
    case 'invalid-email':
      return 'That email address is invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    default:
      return 'Sign-in failed. Please try again.';
  }
}
