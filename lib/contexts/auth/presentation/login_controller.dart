import 'package:flutter/foundation.dart';

import '../application/sign_in.dart';
import '../domain/auth_exceptions.dart';

/// Reasons a sign-in attempt can fail, as understood by [LoginScreen].
/// [LoginController] has no [BuildContext] and so cannot hold a localized
/// message directly — [LoginScreen] maps this to text at build time.
enum LoginError {
  invalidCredentials,
  invalidEmail,
  accountDisabled,
  tooManyRequests,
  unknown,
}

/// Drives [LoginScreen]: submits credentials via [SignIn] and tracks
/// loading/error state.
class LoginController extends ChangeNotifier {
  final SignIn _signIn;

  LoginController(this._signIn);

  bool isLoading = false;
  LoginError? error;

  Future<void> submit(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _signIn(email, password);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  LoginError _mapError(Object error) {
    if (error is AuthFailure) {
      return switch (error.code) {
        AuthFailureCode.invalidCredentials => LoginError.invalidCredentials,
        AuthFailureCode.invalidEmail => LoginError.invalidEmail,
        AuthFailureCode.accountDisabled => LoginError.accountDisabled,
        AuthFailureCode.tooManyRequests => LoginError.tooManyRequests,
        AuthFailureCode.unknown => LoginError.unknown,
      };
    }
    return LoginError.unknown;
  }
}
