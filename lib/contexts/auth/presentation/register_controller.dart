import 'package:flutter/foundation.dart';

import '../application/sign_up.dart';
import '../domain/auth_exceptions.dart';

/// Reasons a sign-up attempt can fail, as understood by [RegisterScreen].
/// [RegisterController] has no [BuildContext] and so cannot hold a localized
/// message directly — [RegisterScreen] maps this to text at build time.
enum RegisterError {
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  passwordMismatch,
  unknown,
}

/// Drives [RegisterScreen]: submits a new account via [SignUp] and tracks
/// loading/error/success state.
class RegisterController extends ChangeNotifier {
  final SignUp _signUp;

  RegisterController(this._signUp);

  bool isLoading = false;
  RegisterError? error;

  /// Set to `true` once sign-up succeeds, so [RegisterScreen] knows to pop
  /// itself (auth-state routing only swaps the bottom route, it doesn't
  /// discard routes pushed on top of it).
  bool succeeded = false;

  Future<void> submit(
    String email,
    String password,
    String confirmPassword,
  ) async {
    if (password != confirmPassword) {
      error = RegisterError.passwordMismatch;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _signUp(email, password);
      succeeded = true;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  RegisterError _mapError(Object error) {
    if (error is AuthFailure) {
      return switch (error.code) {
        AuthFailureCode.emailAlreadyInUse => RegisterError.emailAlreadyInUse,
        AuthFailureCode.weakPassword => RegisterError.weakPassword,
        AuthFailureCode.invalidEmail => RegisterError.invalidEmail,
        AuthFailureCode.invalidCredentials => RegisterError.unknown,
        AuthFailureCode.accountDisabled => RegisterError.unknown,
        AuthFailureCode.tooManyRequests => RegisterError.unknown,
        AuthFailureCode.unknown => RegisterError.unknown,
      };
    }
    return RegisterError.unknown;
  }
}
