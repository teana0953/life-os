import '../domain/friend.dart';
import '../domain/social_repository.dart';

class ListFriends {
  final SocialRepository _repository;

  ListFriends(this._repository);

  Future<List<Friend>> call(String idToken) => _repository.listFriends(idToken);
}

class RemoveFriend {
  final SocialRepository _repository;

  RemoveFriend(this._repository);

  Future<void> call(String idToken, String friendUserId) =>
      _repository.removeFriend(idToken, friendUserId);
}
