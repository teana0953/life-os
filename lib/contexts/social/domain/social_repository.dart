import 'friend.dart';
import 'friend_invite.dart';
import 'invite_preview.dart';

/// Port covering friends and invites (contract frozen in design.md, backend
/// PR #64). Every method takes [idToken] explicitly — the caller (a
/// screen's `State`) fetches it fresh per request rather than relying on a
/// cached snapshot (design.md: `app.dart`'s `_idToken` doesn't renew).
abstract class SocialRepository {
  Future<List<Friend>> listFriends(String idToken);

  Future<void> removeFriend(String idToken, String friendUserId);

  /// Mints an invite. The plaintext `token` is returned only here — it is
  /// not persisted or logged (design D5). The response has no `id`, so a
  /// freshly created invite cannot be revoked without re-listing invites.
  Future<({String token, String expiresAt})> createInvite(String idToken);

  Future<List<FriendInvite>> listInvites(String idToken);

  Future<void> revokeInvite(String idToken, String id);

  /// Reads an invite without consuming it (design D2).
  Future<InvitePreview> previewInvite(String idToken, String token);

  /// Consumes the invite and creates the friendship.
  Future<AcceptInviteResult> acceptInvite(String idToken, String token);
}
