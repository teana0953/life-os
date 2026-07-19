/// Known reasons an [AuthRepository] driven adapter can reject sign-in.
/// Presentation maps each code to a localized message — no UI copy lives
/// here or in infrastructure.
enum AuthFailureCode {
  invalidCredentials,
  invalidEmail,
  accountDisabled,
  tooManyRequests,
  emailAlreadyInUse,
  weakPassword,
  unknown,
}

/// Thrown by an [AuthRepository] driven adapter when sign-in fails for a
/// known reason (invalid credentials, disabled account, ...).
class AuthFailure implements Exception {
  final AuthFailureCode code;

  const AuthFailure(this.code);

  @override
  String toString() => 'AuthFailure($code)';
}
