import 'package:flutter/foundation.dart';

import '../application/friend_use_cases.dart';
import '../application/invite_use_cases.dart';
import '../domain/friend.dart';
import '../domain/friend_invite.dart';
import '../domain/social_exceptions.dart';

enum FriendsStatus { loading, loaded, error, needsReauth }

/// The full-list load failure — the presentation layer maps this to
/// localized copy.
enum FriendsError { fetchFailed, unknown }

/// A mutation (remove/create invite/revoke invite) failure. Kept separate
/// from [FriendsError] (the whole-page load failure): a mutation failure
/// keeps the already-loaded lists on screen rather than blanking the page
/// (mirrors `CareItemsController`).
enum FriendsMutationError {
  /// `DELETE /api/friends/:id` answered 404 — the friendship is already
  /// gone. Its copy must read differently from the invite-invalid-link copy
  /// shown on the invite page (design.md).
  removeNotFound,
  removeFailed,
  createInviteFailed,

  /// The invite itself was minted, but the follow-up list re-fetch failed.
  /// Deliberately *not* [createInviteFailed]: the invite exists and its
  /// one-time plaintext link is on screen — telling the user creation failed
  /// would make them discard the only copy of it.
  createInviteRefreshFailed,

  /// `DELETE /api/friends/invites/:id` answered 404 — the invite is already
  /// gone, so the listed row was stale. Distinct copy from the generic
  /// failure (design.md's error table).
  revokeNotFound,
  revokeInviteFailed,
}

/// Drives [FriendsScreen]: loads friends + outstanding invites together,
/// removes a friend, creates/revokes an invite.
///
/// Owned by the screen's `State` (design D9) — created in `initState`,
/// disposed in `dispose`; never a `main.dart` singleton and never built in a
/// `GoRoute` builder. That lifetime is what keeps [newInviteToken] — the
/// plaintext invite token, held only in memory — from outliving the page
/// (design D5): leaving and returning to the friends page discards this
/// controller and starts a fresh one with no token.
class FriendsController extends ChangeNotifier {
  final ListFriends _listFriends;
  final RemoveFriend _removeFriend;
  final CreateInvite _createInvite;
  final ListInvites _listInvites;
  final RevokeInvite _revokeInvite;

  FriendsController(
    this._listFriends,
    this._removeFriend,
    this._createInvite,
    this._listInvites,
    this._revokeInvite,
  );

  FriendsStatus status = FriendsStatus.loading;
  FriendsError? error;
  List<Friend> friends = const [];
  List<FriendInvite> invites = const [];

  /// The plaintext token from the most recently created invite, and its
  /// expiry — `null` until [createInvite] succeeds in this controller's
  /// lifetime (design D5).
  String? newInviteToken;
  String? newInviteExpiresAt;

  /// The id of the invite [newInviteToken] belongs to, once the post-create
  /// refresh has revealed it (the create response carries no id, design.md).
  /// `null` when the refresh failed or was ambiguous — in which case the link
  /// card is never cleared automatically, which is the safe direction.
  String? newInviteId;

  FriendsMutationError? mutationError;

  /// Bumped on every non-null [mutationError] assignment, including a repeat
  /// of the same value. The screen dedupes its SnackBar on this rather than
  /// on the enum, so two overlapping mutations that fail the same way are
  /// reported twice — once each.
  int mutationErrorSeq = 0;

  void _setMutationError(FriendsMutationError error) {
    mutationError = error;
    mutationErrorSeq++;
  }

  bool creatingInvite = false;
  final Set<String> _busyFriendIds = {};
  final Set<String> _busyInviteIds = {};

  bool isFriendBusy(String friendUserId) => _busyFriendIds.contains(friendUserId);

  bool isInviteBusy(String id) => _busyInviteIds.contains(id);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The page can be left from any state, including while a request is still
  /// in flight — at which point this controller is already disposed by the
  /// time the response lands, and a plain `notifyListeners` would throw
  /// "used after being disposed". Same guard as `InviteController`.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> load(String idToken) async {
    status = FriendsStatus.loading;
    mutationError = null;
    _notify();
    await _fetchLists(idToken);
    _notify();
  }

  Future<void> _fetchLists(String idToken) async {
    try {
      final results = await Future.wait([
        _listFriends(idToken),
        _listInvites(idToken),
      ]);
      friends = results[0] as List<Friend>;
      invites = results[1] as List<FriendInvite>;
      status = FriendsStatus.loaded;
      error = null;
    } on SocialReauthenticationRequired {
      status = FriendsStatus.needsReauth;
    } on SocialFetchFailure {
      status = FriendsStatus.error;
      error = FriendsError.fetchFailed;
    } catch (_) {
      status = FriendsStatus.error;
      error = FriendsError.unknown;
    }
  }

  /// Ends the friendship with [friendUserId]. On success, or on a 404
  /// (the friendship was already gone), the lists are re-fetched so the
  /// screen reflects server truth either way.
  Future<void> removeFriend(String idToken, String friendUserId) async {
    if (_busyFriendIds.contains(friendUserId)) return;
    _busyFriendIds.add(friendUserId);
    mutationError = null;
    _notify();
    try {
      await _removeFriend(idToken, friendUserId);
      await _fetchLists(idToken);
    } on SocialReauthenticationRequired {
      status = FriendsStatus.needsReauth;
    } on SocialNotFound {
      _setMutationError(FriendsMutationError.removeNotFound);
      await _fetchLists(idToken);
    } catch (_) {
      _setMutationError(FriendsMutationError.removeFailed);
    }
    _busyFriendIds.remove(friendUserId);
    _notify();
  }

  /// Mints an invite, then re-fetches the invite list — the create response
  /// carries no `id` (design.md), so the freshly created invite only gets
  /// one, and becomes revokable, once the list is re-fetched.
  Future<void> createInvite(String idToken) async {
    if (creatingInvite) return;
    creatingInvite = true;
    mutationError = null;
    _notify();
    try {
      final knownInviteIds = invites.map((i) => i.id).toSet();
      final created = await _createInvite(idToken);
      newInviteToken = created.token;
      newInviteExpiresAt = created.expiresAt;
      newInviteId = null;
      await _fetchLists(idToken);
      if (status == FriendsStatus.error) {
        // The plaintext token exists exactly once, in the response we just
        // received (design D5). Letting a failed *refresh* flip the page to
        // the error state would replace the link card with an error page and
        // destroy the only copy the user will ever have. Keep the page loaded
        // (with whatever lists we already had) and report the refresh failure
        // as a mutation error instead.
        //
        // Deliberately not applied to `needsReauth`: a 401 is not a refresh
        // hiccup. Papering over it would leave a healthy-looking page on a
        // dead session whose every next action fails, and hide the only exit
        // (re-authenticate) the user has.
        status = FriendsStatus.loaded;
        error = null;
        _setMutationError(FriendsMutationError.createInviteRefreshFailed);
      } else if (status == FriendsStatus.loaded) {
        // The create response carries no id (design.md); the refresh is what
        // reveals it. Only an unambiguous single new row identifies the
        // invite this token belongs to.
        final added = invites.where((i) => !knownInviteIds.contains(i.id)).toList();
        newInviteId = added.length == 1 ? added.single.id : null;
      }
    } on SocialReauthenticationRequired {
      status = FriendsStatus.needsReauth;
    } catch (_) {
      _setMutationError(FriendsMutationError.createInviteFailed);
    }
    creatingInvite = false;
    _notify();
  }

  Future<void> revokeInvite(String idToken, String id) async {
    if (_busyInviteIds.contains(id)) return;
    _busyInviteIds.add(id);
    mutationError = null;
    _notify();
    try {
      await _revokeInvite(idToken, id);
      _clearLinkIfRevoked(id);
      await _fetchLists(idToken);
    } on SocialReauthenticationRequired {
      status = FriendsStatus.needsReauth;
    } on SocialNotFound {
      // The invite is already gone; the row the user tapped was stale, so
      // re-fetch to drop it rather than leaving a row that keeps failing.
      _setMutationError(FriendsMutationError.revokeNotFound);
      _clearLinkIfRevoked(id);
      await _fetchLists(idToken);
    } catch (_) {
      _setMutationError(FriendsMutationError.revokeInviteFailed);
    }
    _busyInviteIds.remove(id);
    _notify();
  }

  /// Revoking the invite the link card belongs to must take the card with it:
  /// the link is dead the moment the invite is, and leaving it on screen —
  /// still urging "copy it now" next to a live Copy button — invites the user
  /// to share a link that will only ever fail for the recipient.
  void _clearLinkIfRevoked(String id) {
    if (newInviteId != id) return;
    newInviteToken = null;
    newInviteExpiresAt = null;
    newInviteId = null;
  }
}
