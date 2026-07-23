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
  String? _idToken;

  /// Whether the first auth state is still pending (show a splash).
  bool get loading => _loading;

  /// Whether the auth stream errored (show a retry screen).
  bool get error => _error;

  /// Whether there is an authenticated user.
  bool get signedIn => _signedIn;

  /// The current auth id-token, resolved when signed in (null otherwise). Held
  /// here so the router's screen builders can construct API-calling screens
  /// synchronously — the token is awaited before each `notifyListeners`, so by
  /// the time the router lets an authenticated route build, it is populated.
  String? get idToken => _idToken;

  AuthRouterNotifier(this._authRepository) {
    _subscribe();
  }

  void _subscribe() {
    _subscription = _authRepository.authStateChanges.listen(
      (signedIn) async {
        _loading = false;
        _error = false;
        _signedIn = signedIn;
        // A token-fetch throw (e.g. transient network) must NOT become an
        // unhandled async error that skips notifyListeners — that would strand
        // the router on the splash. Fall back to a null token (screens then hit
        // the API unauthenticated → their normal re-auth path) and still notify.
        try {
          _idToken = signedIn ? await _authRepository.idToken() : null;
        } catch (_) {
          _idToken = null;
        }
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
