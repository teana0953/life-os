import '../domain/display_name_repository.dart';
import '../domain/user_profile.dart';

class UpdateDisplayName {
  final DisplayNameRepository _repository;

  UpdateDisplayName(this._repository);

  Future<UserProfile> call(String idToken, String displayName) =>
      _repository.updateDisplayName(idToken, displayName);
}
