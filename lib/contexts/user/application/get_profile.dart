import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// Use case: fetch the authenticated user's profile.
class GetProfile {
  final ProfileRepository _repository;

  GetProfile(this._repository);

  Future<UserProfile> call(String idToken) {
    return _repository.getProfile(idToken);
  }
}
