import '../domain/friend_invite.dart';
import '../domain/invite_preview.dart';
import '../domain/social_repository.dart';

/// Use case: mint an invite. The response has no `id` — callers that need
/// to revoke it must re-fetch [ListInvites] (design.md).
class CreateInvite {
  final SocialRepository _repository;

  CreateInvite(this._repository);

  Future<({String token, String expiresAt})> call(String idToken) =>
      _repository.createInvite(idToken);
}

/// Use case: list the caller's own still-usable invites.
class ListInvites {
  final SocialRepository _repository;

  ListInvites(this._repository);

  Future<List<FriendInvite>> call(String idToken) => _repository.listInvites(idToken);
}

/// Use case: revoke one of the caller's own invites.
class RevokeInvite {
  final SocialRepository _repository;

  RevokeInvite(this._repository);

  Future<void> call(String idToken, String id) => _repository.revokeInvite(idToken, id);
}

/// Use case: preview an invite without consuming it (design D2).
class PreviewInvite {
  final SocialRepository _repository;

  PreviewInvite(this._repository);

  Future<InvitePreview> call(String idToken, String token) =>
      _repository.previewInvite(idToken, token);
}

/// Use case: accept an invite, consuming it and creating the friendship.
class AcceptInvite {
  final SocialRepository _repository;

  AcceptInvite(this._repository);

  Future<AcceptInviteResult> call(String idToken, String token) =>
      _repository.acceptInvite(idToken, token);
}
