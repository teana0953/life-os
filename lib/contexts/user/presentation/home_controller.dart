import 'package:flutter/foundation.dart';

import '../../auth/application/sign_out.dart';
import '../application/get_profile.dart';
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

  HomeController(this._getProfile, this._signOut);

  HomeStatus status = HomeStatus.loading;
  UserProfile? profile;
  ProfileError? error;

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
}
