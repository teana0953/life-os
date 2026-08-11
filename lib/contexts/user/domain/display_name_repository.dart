import 'user_profile.dart';

/// Port for persisting the authenticated user's chosen display name.
abstract class DisplayNameRepository {
  Future<UserProfile> updateDisplayName(String idToken, String displayName);
}
