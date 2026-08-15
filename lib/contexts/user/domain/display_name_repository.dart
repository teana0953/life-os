import 'user_profile.dart';

abstract class DisplayNameRepository {
  Future<UserProfile> updateDisplayName(String idToken, String displayName);
}
