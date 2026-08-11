import 'package:flutter/foundation.dart';

import '../../auth/application/sign_out.dart';
import '../application/get_profile.dart';
import '../application/update_display_name.dart';
import '../domain/profile_exceptions.dart';
import '../domain/user_profile.dart';

enum HomeStatus { loading, loaded, error, needsReauth }

/// Reasons loading the profile can fail, as understood by [HomeScreen].
/// [HomeController] has no [BuildContext] and so cannot hold a localized
/// message directly — [HomeScreen] maps this to text at build time.
enum ProfileError { fetchFailed, unknown }

/// Drives [HomeScreen]: loads the profile via [GetProfile] and exposes
/// sign-out via [SignOut].
class HomeController extends ChangeNotifier {
  final GetProfile _getProfile;
  final SignOut _signOut;
  final UpdateDisplayName? _updateDisplayName;

  HomeController(
    this._getProfile,
    this._signOut, {
    UpdateDisplayName? updateDisplayName,
  }) : _updateDisplayName = updateDisplayName;

  HomeStatus status = HomeStatus.loading;
  UserProfile? profile;
  ProfileError? error;
  bool isSavingDisplayName = false;
  bool displayNameSaveFailed = false;

  Future<void>? _ensureLoadedInFlight;

  /// Loads the profile only if it isn't already loaded and no load is
  /// currently in flight. Unlike [load], a failed attempt (`profile ==
  /// null`) is retried on the next call — this is the only retry a
  /// deep-linked screen (one that never mounts `_AuthenticatedHome`) gets.
  Future<void> ensureLoaded(String idToken) {
    if (profile != null) return Future.value();
    return _ensureLoadedInFlight ??= load(idToken).whenComplete(() {
      _ensureLoadedInFlight = null;
    });
  }

  /// Clears the loaded profile on sign-out so a subsequently signed-in user
  /// doesn't inherit the previous user's admin status.
  void reset() {
    profile = null;
    status = HomeStatus.loading;
  }

  Future<void> load(String idToken) async {
    status = HomeStatus.loading;
    error = null;
    notifyListeners();

    try {
      profile = await _getProfile(idToken);
      status = HomeStatus.loaded;
    } on ReauthenticationRequired {
      status = HomeStatus.needsReauth;
    } on ProfileFetchFailure {
      status = HomeStatus.error;
      error = ProfileError.fetchFailed;
    } catch (_) {
      status = HomeStatus.error;
      error = ProfileError.unknown;
    }
    notifyListeners();
  }

  Future<void> signOut() => _signOut();

  Future<bool> saveDisplayName(String idToken, String displayName) async {
    final update = _updateDisplayName;
    if (update == null) return false;
    isSavingDisplayName = true;
    displayNameSaveFailed = false;
    notifyListeners();
    try {
      profile = await update(idToken, displayName);
      return true;
    } on ReauthenticationRequired {
      status = HomeStatus.needsReauth;
      return false;
    } catch (_) {
      displayNameSaveFailed = true;
      return false;
    } finally {
      isSavingDisplayName = false;
      notifyListeners();
    }
  }
}
