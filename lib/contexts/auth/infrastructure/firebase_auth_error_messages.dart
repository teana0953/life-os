import '../domain/auth_exceptions.dart';

/// Maps a `firebase_auth` `FirebaseAuthException.code` to a typed
/// [AuthFailureCode], without leaking internal error detail. Presentation
/// maps the code to a localized message.
AuthFailureCode authFailureCodeFor(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return AuthFailureCode.invalidCredentials;
    case 'invalid-email':
      return AuthFailureCode.invalidEmail;
    case 'user-disabled':
      return AuthFailureCode.accountDisabled;
    case 'too-many-requests':
      return AuthFailureCode.tooManyRequests;
    default:
      return AuthFailureCode.unknown;
  }
}
