import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../contexts/auth/domain/auth_repository.dart';

/// Drives go_router's auth redirect: subscribes to
/// [AuthRepository.authStateChanges] and exposes the tri-state
/// (loading / error / signed-in) as a [ChangeNotifier], so the router can
/// `refreshListenable` on it and redirect on each transition. Replaces the
/// `StreamBuilder` that used to gate `MaterialApp.home`.
class AuthRouterNotifier extends ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<bool>? _subscription;

  bool _loading = true;
  bool _error = false;
  bool _signedIn = false;

  /// Whether the first auth state is still pending (show a splash).
  bool get loading => _loading;

  /// Whether the auth stream errored (show a retry screen).
  bool get error => _error;

  /// Whether there is an authenticated user.
  bool get signedIn => _signedIn;

  AuthRouterNotifier(this._authRepository) {
    _subscribe();
  }

  void _subscribe() {
    _subscription = _authRepository.authStateChanges.listen(
      (signedIn) {
        _loading = false;
        _error = false;
        _signedIn = signedIn;
        notifyListeners();
      },
      onError: (_) {
        _loading = false;
        _error = true;
        notifyListeners();
      },
    );
  }

  /// Re-subscribes after an error (mirrors the old retry button).
  void retry() {
    _subscription?.cancel();
    _loading = true;
    _error = false;
    notifyListeners();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
