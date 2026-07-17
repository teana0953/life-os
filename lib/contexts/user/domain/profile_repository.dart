import 'user_profile.dart';

/// Port for fetching the authenticated user's profile.
abstract class ProfileRepository {
  Future<UserProfile> getProfile(String idToken);
}
