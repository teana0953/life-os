import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../application/invite_use_cases.dart';
import 'invite_controller.dart';

/// The invite-accept landing page reached via `/invite?token=…`. Previews
/// the invite on entry (never auto-accepting, design D2) and only consumes
/// it once the user activates accept.
///
/// Takes stateless use cases plus [authRepository] (a fresh id token per
/// request) and [signOut] (the 401 exit). Its [InviteController] is built
/// by this widget's `State` in `initState` and released in `dispose`
/// (design D9) — the caller (the `/invite` `GoRoute`) must give this widget
/// `key: ValueKey(token)` so that opening a second invite link without
/// leaving the app rebuilds a fresh `State`/controller for the new token
/// rather than reusing one still holding the first (design D13).
class InviteScreen extends StatefulWidget {
  final PreviewInvite previewInvite;
  final AcceptInvite acceptInvite;
  final AuthRepository authRepository;
  final SignOut signOut;
  final String? token;

  const InviteScreen({
    super.key,
    required this.previewInvite,
    required this.acceptInvite,
    required this.authRepository,
    required this.signOut,
    required this.token,
  });

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final InviteController _controller;
  bool _navigatedHome = false;

  @override
  void initState() {
    super.initState();
    _controller = InviteController(widget.previewInvite, widget.acceptInvite);
    _controller.addListener(_onChanged);
    _preview();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    // Consumed on success: taken to the friends list, not left on the
    // now-spent landing page (design.md — `go`, not `push`, so it replaces
    // this page in the in-app stack rather than sitting under it).
    if (_controller.status == InviteStatus.accepted && !_navigatedHome) {
      _navigatedHome = true;
      context.go('/friends');
    }
  }

  Future<void> _preview() async {
    final idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await _controller.preview(idToken, widget.token);
  }

  Future<void> _accept() async {
    final idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await _controller.accept(idToken);
  }

  Future<void> _signOutAndGoHome() async {
    await widget.signOut();
    if (!mounted) return;
    context.go('/friends');
  }

  void _backToFriends() => context.go('/friends');

  /// `canPop()` ? pop : go home — mirrors `FriendsScreen._back`. On a cold
  /// start from an externally shared link this page is the whole stack, so
  /// `pop` alone would leave the user with no way off a page whose only
  /// other action irreversibly consumes the invite.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Every state gets the same way out, not just the failure ones.
    final appBar = AppBar(
      title: Text(loc.inviteTitle),
      leading: IconButton(
        key: const Key('invite-back-button'),
        icon: const Icon(Icons.arrow_back),
        // This is the page's only exit in every state, so it must not be an
        // unlabelled icon: the tooltip is what gives it a semantics label.
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _back,
      ),
    );

    if (_controller.status == InviteStatus.previewing) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator(key: Key('invite-loading'))),
      );
    }

    if (_controller.status == InviteStatus.needsReauth) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('invite-sign-in-again-button'),
                onPressed: _signOutAndGoHome,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        ),
      );
    }

    // A generic/network failure (SocialFetchFailure) is not the same problem
    // as an invalid link — telling the user to re-copy a link that's fine is
    // actively wrong advice — so it gets its own message and a retry action
    // instead of falling into the invalid-link copy below.
    if (_controller.status == InviteStatus.error) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.inviteFetchFailedMessage,
                  key: const Key('invite-error-message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('invite-retry-button'),
                  onPressed: _preview,
                  child: Text(loc.retry),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('invite-back-to-friends-button'),
                  onPressed: _backToFriends,
                  child: Text(loc.inviteBackToFriendsButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final errorMessage = switch (_controller.status) {
      InviteStatus.invalidLink => loc.inviteInvalidMessage,
      InviteStatus.expired => loc.inviteExpiredMessage,
      InviteStatus.alreadyUsed => loc.inviteAlreadyUsedMessage,
      InviteStatus.revoked => loc.inviteRevokedMessage,
      InviteStatus.ownInvite => loc.inviteOwnInviteMessage,
      _ => null,
    };

    if (errorMessage != null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorMessage,
                  key: const Key('invite-error-message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('invite-back-to-friends-button'),
                  onPressed: _backToFriends,
                  child: Text(loc.inviteBackToFriendsButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller.status == InviteStatus.alreadyFriends) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.inviteAlreadyFriendsMessage(_controller.inviterDisplayName ?? ''),
                  key: const Key('invite-already-friends-message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('invite-back-to-friends-button'),
                  onPressed: _backToFriends,
                  child: Text(loc.inviteBackToFriendsButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // `ready` (and `accepted`, which is transient — the listener above
    // navigates away as soon as it's reached).
    return Scaffold(
      appBar: appBar,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.inviteFromMessage(_controller.inviterDisplayName ?? ''),
                key: const Key('invite-from-message'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('invite-accept-button'),
                onPressed: _controller.accepting ? null : _accept,
                child: Text(loc.inviteAcceptButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
