/// Thrown by an [AuthRepository] driven adapter when sign-in fails for a
/// known reason (invalid credentials, disabled account, ...). [message] is
/// already a user-facing, friendly message — safe to show as-is.
class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}
