import 'package:flutter/foundation.dart';

import '../application/send_password_reset.dart';
import '../domain/auth_exceptions.dart';

/// Reasons a reset request can fail, as understood by
/// [PasswordResetScreen]. The controller has no [BuildContext] and so holds
/// the code, not the text.
///
/// There is deliberately **no** "no such account" value. That outcome is
/// indistinguishable from success by the time it reaches here
/// ([SendPasswordReset] swallows it), and an enum value for it would be an
/// invitation to render it.
enum PasswordResetError { invalidEmail, tooManyRequests, unknown }

/// Drives [PasswordResetScreen]: asks for a reset mail and tracks
/// loading/error/sent state.
class PasswordResetController extends ChangeNotifier {
  final SendPasswordReset _sendPasswordReset;

  PasswordResetController(this._sendPasswordReset);

  bool isLoading = false;
  PasswordResetError? error;

  /// True once a request has been accepted. The screen shows the same
  /// confirmation whether or not that address has an account — see
  /// [SendPasswordReset].
  bool sent = false;

  Future<void> submit(String email) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _sendPasswordReset(email.trim());
      sent = true;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  PasswordResetError _mapError(Object error) {
    if (error is AuthFailure) {
      return switch (error.code) {
        AuthFailureCode.invalidEmail => PasswordResetError.invalidEmail,
        AuthFailureCode.tooManyRequests => PasswordResetError.tooManyRequests,
        // Never reached: `SendPasswordReset` returns normally for this one,
        // precisely so that no screen can tell an unknown address apart from
        // a known one. Mapped to `unknown` rather than given a value of its
        // own — a value would be a place for somebody to write copy.
        AuthFailureCode.invalidCredentials => PasswordResetError.unknown,
        AuthFailureCode.emailAlreadyInUse => PasswordResetError.unknown,
        AuthFailureCode.weakPassword => PasswordResetError.unknown,
        AuthFailureCode.accountDisabled => PasswordResetError.unknown,
        AuthFailureCode.unknown => PasswordResetError.unknown,
      };
    }
    return PasswordResetError.unknown;
  }
}
