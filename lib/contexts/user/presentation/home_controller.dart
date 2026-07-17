import 'package:flutter/foundation.dart';

import '../../auth/application/sign_out.dart';
import '../application/get_profile.dart';
import '../domain/profile_exceptions.dart';
import '../domain/user_profile.dart';

enum HomeStatus { loading, loaded, error, needsReauth }

/// Drives [HomeScreen]: loads the profile via [GetProfile] and exposes
/// sign-out via [SignOut].
class HomeController extends ChangeNotifier {
  final GetProfile _getProfile;
  final SignOut _signOut;

  HomeController(this._getProfile, this._signOut);

  HomeStatus status = HomeStatus.loading;
  UserProfile? profile;
  String? errorMessage;

  Future<void> load(String idToken) async {
    status = HomeStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _getProfile(idToken);
      status = HomeStatus.loaded;
    } on ReauthenticationRequired {
      status = HomeStatus.needsReauth;
      errorMessage = 'Please sign in again.';
    } catch (e) {
      status = HomeStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> signOut() => _signOut();
}
