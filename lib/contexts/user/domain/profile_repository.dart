import 'user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile(String idToken);
}
