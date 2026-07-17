import 'package:flutter/foundation.dart';

import '../application/sign_in.dart';
import '../domain/auth_exceptions.dart';

/// Drives [LoginScreen]: submits credentials via [SignIn] and tracks
/// loading/error state.
class LoginController extends ChangeNotifier {
  final SignIn _signIn;

  LoginController(this._signIn);

  bool isLoading = false;
  String? errorMessage;

  Future<void> submit(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _signIn(email, password);
    } catch (e) {
      errorMessage = _friendlyMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyMessage(Object error) {
    if (error is AuthFailure) return error.message;
    return 'Sign-in failed. Please try again.';
  }
}
