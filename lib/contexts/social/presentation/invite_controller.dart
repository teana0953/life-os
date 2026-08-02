import 'package:flutter/foundation.dart';

import '../application/invite_use_cases.dart';
import '../domain/social_exceptions.dart';

enum InviteStatus {
  /// The initial preview request is in flight.
  previewing,

  /// Preview succeeded; the inviter's name is shown with an accept action
  /// (design D2 — preview never consumes the invite).
  ready,

  /// Preview or accept reported `already_friends` (design D3).
  alreadyFriends,

  /// Accept succeeded and created the friendship.
  accepted,

  needsReauth,
  invalidLink,
  expired,
  alreadyUsed,
  revoked,

  /// Accept answered `cannot_friend_self` — only detectable on accept, never
  /// on preview (design D10).
  ownInvite,

  error,
}

/// Drives [InviteScreen]: previews the invite on load (never auto-accepting,
/// design D2), then accepts only on the user's explicit action.
///
/// Owned by the screen's `State` (design D9) — created in `initState`,
/// disposed in `dispose`, and rebuilt (via `key: ValueKey(token)` on the
/// route) whenever the token changes, so a second invite link opened
/// without leaving the app always previews and consumes the *new* token
/// (design D13), never a stale one held by a reused controller.
class InviteController extends ChangeNotifier {
  final PreviewInvite _previewInvite;
  final AcceptInvite _acceptInvite;

  InviteController(this._previewInvite, this._acceptInvite);

  InviteStatus status = InviteStatus.previewing;
  String? inviterDisplayName;
  bool accepting = false;

  String? _token;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The page can now be left from *any* state, including while the initial
  /// preview is still in flight — at which point this controller is already
  /// disposed by the time the request lands, and a plain `notifyListeners`
  /// would throw "used after being disposed".
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Previews [token]. A blank/missing [token] goes straight to
  /// [InviteStatus.invalidLink] without sending a request (spec: "Missing or
  /// blank token").
  Future<void> preview(String idToken, String? token) async {
    if (token == null || token.trim().isEmpty) {
      status = InviteStatus.invalidLink;
      _notify();
      return;
    }
    _token = token;
    status = InviteStatus.previewing;
    _notify();
    try {
      final result = await _previewInvite(idToken, token);
      inviterDisplayName = result.inviterDisplayName;
      status = result.alreadyFriends ? InviteStatus.alreadyFriends : InviteStatus.ready;
    } catch (e) {
      status = _mapError(e);
    }
    _notify();
  }

  /// Accepts the previewed invite. No-ops if there is no token to accept
  /// (preview never ran or failed before setting one) or an accept is
  /// already in flight.
  Future<void> accept(String idToken) async {
    final token = _token;
    if (token == null || accepting) return;
    accepting = true;
    _notify();
    try {
      final result = await _acceptInvite(idToken, token);
      status = result.alreadyFriends ? InviteStatus.alreadyFriends : InviteStatus.accepted;
    } on CannotFriendSelf {
      // Only detectable here — preview cannot self-check (design D10).
      status = InviteStatus.ownInvite;
    } catch (e) {
      status = _mapError(e);
    }
    accepting = false;
    _notify();
  }

  InviteStatus _mapError(Object e) {
    if (e is SocialReauthenticationRequired) return InviteStatus.needsReauth;
    if (e is InviteNotFound) return InviteStatus.invalidLink;
    if (e is InviteExpired) return InviteStatus.expired;
    if (e is InviteAlreadyUsed) return InviteStatus.alreadyUsed;
    if (e is InviteRevoked) return InviteStatus.revoked;
    return InviteStatus.error;
  }
}
