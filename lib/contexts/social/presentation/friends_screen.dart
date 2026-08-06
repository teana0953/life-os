import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/config.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/label_value_row.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../application/friend_use_cases.dart';
import '../application/invite_use_cases.dart';
import '../domain/friend.dart';
import 'friends_controller.dart';

/// Default origin for the invite link: the running origin on the web, the
/// configured deployed origin everywhere else.
///
/// `Uri.base.origin` throws `StateError` on any non-web platform (`Uri.base`
/// is a `file://` URI on the Dart VM and on a native build), so evaluating it
/// unguarded red-screens the page the moment a link is rendered. Public so a
/// test can call it on the VM — the platform where the unguarded version
/// throws.
String defaultInviteOrigin() => kIsWeb ? Uri.base.origin : appWebOrigin;

DateTime _defaultToLocal(DateTime dt) => dt.toLocal();

/// The friends page: friends list (each removable with confirmation),
/// outstanding invites (each revokable without confirmation), and an action
/// that mints a new invite link.
///
/// Takes stateless use cases plus [authRepository] (a fresh id token is
/// fetched per request, never a cached one) and [signOut] (the 401 exit) —
/// its [FriendsController] is built by this widget's `State` in `initState`
/// and released in `dispose` (design D9), not injected pre-built, so the
/// controller — and the plaintext invite token it may be holding — cannot
/// outlive this page.
class FriendsScreen extends StatefulWidget {
  final ListFriends listFriends;
  final RemoveFriend removeFriend;
  final CreateInvite createInvite;
  final ListInvites listInvites;
  final RevokeInvite revokeInvite;
  final AuthRepository authRepository;
  final SignOut signOut;

  /// Origin used to build the shareable `<origin>/#/invite?token=…` link
  /// (design D12). Defaults to [defaultInviteOrigin], a **lazily evaluated**
  /// closure so the web branch (`Uri.base.origin`) is only read when a link
  /// is actually rendered (design D1). Tests inject a fixed value.
  final String Function() origin;

  /// Converts a UTC instant to local time for invite-expiry display; tests
  /// inject a fixed offset (design D11).
  final DateTime Function(DateTime) toLocalTime;

  const FriendsScreen({
    super.key,
    required this.listFriends,
    required this.removeFriend,
    required this.createInvite,
    required this.listInvites,
    required this.revokeInvite,
    required this.authRepository,
    required this.signOut,
    this.origin = defaultInviteOrigin,
    this.toLocalTime = _defaultToLocal,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendsController _controller;

  /// The [FriendsController.mutationErrorSeq] already surfaced as a SnackBar,
  /// so a rebuild for an unrelated reason doesn't re-show it.
  ///
  /// Deliberately the sequence number and not the error value: two
  /// overlapping mutations (remove A, then remove B before A answers) can
  /// fail the *same* way, and comparing by enum value would swallow the
  /// second failure — leaving the user to conclude that operation succeeded.
  int? _shownMutationErrorSeq;

  /// The invite link the user has actually copied, so replacing an
  /// **uncopied** link can ask first (and replacing a copied one doesn't
  /// nag). Compared by link text, not a flag, so it cannot survive into the
  /// next link.
  String? _copiedLink;

  @override
  void initState() {
    super.initState();
    _controller = FriendsController(
      widget.listFriends,
      widget.removeFriend,
      widget.createInvite,
      widget.listInvites,
      widget.revokeInvite,
    );
    _controller.addListener(_onChanged);
    _load();
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
    _surfaceMutationError();
  }

  /// Mutation failures go through a SnackBar, like every other mutation in
  /// this app (finance/care/trackers, and `_copyLink` right below). Inline
  /// text at the top of the page's `ListView` was invisible for a failure
  /// triggered by a button further down the scroll.
  void _surfaceMutationError() {
    final error = _controller.mutationError;
    if (error == null) {
      _shownMutationErrorSeq = null;
      return;
    }
    if (_controller.mutationErrorSeq == _shownMutationErrorSeq) return;
    _shownMutationErrorSeq = _controller.mutationErrorSeq;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_mutationErrorText(loc, error))));
  }

  /// A fresh id token per request (design.md, and `SocialRepository`'s own
  /// doc comment): Firebase id tokens expire after ~1h, so a cached snapshot
  /// taken in `initState` 401s on a friends page left open — and that 401's
  /// exit signs the user out.
  Future<String> _token() async => await widget.authRepository.idToken() ?? '';

  Future<void> _load() async {
    final idToken = await _token();
    if (!mounted) return;
    await _controller.load(idToken);
  }

  String _linkFor(String token) => '${widget.origin()}/#/invite?token=$token';

  /// Creating a second invite overwrites the first one's plaintext token —
  /// which exists exactly once (design D5). Inviting a second friend is a
  /// perfectly ordinary reason to press this button again, so the loss must
  /// not be silent: if the link on screen has not been copied yet, ask first.
  /// Once it has been copied there is nothing left to lose, so no prompt.
  Future<void> _createInvite() async {
    final token = _controller.newInviteToken;
    if (token != null && _copiedLink != _linkFor(token)) {
      final loc = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          // Same reason as the other two dialogs: keep the actions reachable
          // at large text scales on short viewports.
          scrollable: true,
          title: Text(loc.friendsCreateAnotherConfirmTitle),
          content: Text(loc.friendsCreateAnotherConfirmMessage),
          actions: [
            TextButton(
              key: const Key('friends-create-another-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              key: const Key('friends-create-another-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(loc.friendsCreateAnotherConfirmButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }
    final idToken = await _token();
    if (!mounted) return;
    await _controller.createInvite(idToken);
  }

  /// `canPop()` ? pop : go home — the page must always be leavable, whether
  /// pushed from settings (has a back stack) or reached directly by URL /
  /// after accepting an invite (doesn't) (design.md).
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _signOutAndClose() async {
    await widget.signOut();
    if (!mounted) return;
    _back();
  }

  Future<void> _confirmRemove(Friend friend) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Large text scales on short (phone) viewports can otherwise push
        // the actions below the fold with no way to reach them (QA finding
        // 1): `scrollable: true` keeps title/content in a
        // `SingleChildScrollView` while the actions stay pinned and always
        // reachable.
        scrollable: true,
        title: Text(loc.friendsRemoveConfirmTitle(friend.displayName)),
        content: Text(loc.friendsRemoveConfirmMessage(friend.displayName)),
        actions: [
          TextButton(
            key: const Key('friends-remove-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            key: const Key('friends-remove-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.friendsRemoveConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _controller.removeFriend(await _token(), friend.userId);
  }

  /// Revoking is confirmed even though it costs the *user* nothing: the cost
  /// lands on the other person, who is holding a link that silently stops
  /// working and has no way to find out (design.md D8, reversed).
  Future<void> _confirmRevoke(String inviteId) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // Same reason as the remove dialog: keep the actions reachable at
        // large text scales on short viewports.
        scrollable: true,
        title: Text(loc.friendsRevokeConfirmTitle),
        content: Text(loc.friendsRevokeConfirmMessage),
        actions: [
          TextButton(
            key: const Key('friends-revoke-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            key: const Key('friends-revoke-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.friendsRevokeConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _controller.revokeInvite(await _token(), inviteId);
  }

  Future<void> _copyLink(String link) async {
    final loc = AppLocalizations.of(context)!;
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: link));
      message = loc.friendsCopiedMessage;
      _copiedLink = link;
    } catch (_) {
      // The clipboard can reject the write (browser permission denied,
      // non-user-gesture context, ...). The link text stays visible on
      // screen precisely so the user can select and copy it manually in
      // that case (design) — tell them the copy failed rather than leaving
      // them with no feedback at all.
      message = loc.friendsCopyFailedMessage;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _mutationErrorText(AppLocalizations loc, FriendsMutationError error) =>
      switch (error) {
        FriendsMutationError.removeNotFound => loc.friendsRemoveNotFoundMessage,
        FriendsMutationError.removeFailed => loc.friendsRemoveFailedMessage,
        FriendsMutationError.createInviteFailed => loc.friendsCreateInviteFailedMessage,
        FriendsMutationError.createInviteRefreshFailed =>
          loc.friendsCreateInviteRefreshFailedMessage,
        FriendsMutationError.revokeNotFound => loc.friendsRevokeNotFoundMessage,
        FriendsMutationError.revokeInviteFailed => loc.friendsRevokeFailedMessage,
      };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appBar = AppBar(
      title: Text(loc.friendsTitle),
      leading: IconButton(
        key: const Key('friends-back-button'),
        icon: const Icon(Icons.arrow_back),
        // This is the page's only exit in every state, so it must not be an
        // unlabelled icon: the tooltip is what gives it a semantics label.
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _back,
      ),
    );

    if (_controller.status == FriendsStatus.loading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(
          child: CircularProgressIndicator(key: Key('friends-loading')),
        ),
      );
    }

    if (_controller.status == FriendsStatus.needsReauth) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('friends-sign-in-again-button'),
                onPressed: _signOutAndClose,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.status == FriendsStatus.error) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.friendsLoadErrorMessage,
                key: const Key('friends-load-error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('friends-retry-button'),
                onPressed: _load,
                child: Text(loc.retry),
              ),
            ],
          ),
        ),
      );
    }

    final token = _controller.newInviteToken;
    final newLink = token == null ? null : _linkFor(token);

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // While a fresh link is on screen, Copy (inside the card) is
                // the action the user must take — so this one steps down to
                // a secondary style and says what it really does: replace
                // the link above.
                if (newLink == null)
                  FilledButton(
                    key: const Key('friends-invite-button'),
                    onPressed: _controller.creatingInvite ? null : _createInvite,
                    child: Text(loc.friendsInviteButton),
                  )
                else
                  OutlinedButton(
                    key: const Key('friends-invite-button'),
                    onPressed: _controller.creatingInvite ? null : _createInvite,
                    child: Text(loc.friendsInviteAnotherButton),
                  ),
                if (newLink != null) ...[
                  const SizedBox(height: 16),
                  _InviteLinkCard(
                    link: newLink,
                    expiryLabel: _controller.newInviteExpiresAt == null
                        ? null
                        : _localDateLabel(
                            context,
                            widget.toLocalTime,
                            _controller.newInviteExpiresAt!,
                          ),
                    onCopy: () => _copyLink(newLink),
                  ),
                ],
                const SizedBox(height: 24),
                if (_controller.friends.isEmpty)
                  const _EmptyState(stateKey: Key('friends-empty-state'))
                else ...[
                  Text(loc.friendsSectionFriends, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  LedgeCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final friend in _controller.friends)
                          ListTile(
                            key: Key('friend-row-${friend.userId}'),
                            title: LabelValueRow(
                              gap: 12,
                              label: Text(friend.displayName),
                              value: IconButton(
                                key: Key('friend-remove-${friend.userId}'),
                                tooltip: loc.friendsRemoveTooltip,
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: _controller.isFriendBusy(friend.userId)
                                    ? null
                                    : () => _confirmRemove(friend),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_controller.invites.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(loc.friendsSectionInvites, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  LedgeCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final invite in _controller.invites)
                          ListTile(
                            key: Key('invite-row-${invite.id}'),
                            title: LabelValueRow(
                              gap: 12,
                              // Created *and* expiring: invites live 7 days,
                              // so several outstanding ones normally share an
                              // expiry date — the creation timestamp is what
                              // tells the rows apart before revoking one.
                              label: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    loc.friendsInviteCreatedLabel(
                                      _localDateTimeLabel(
                                        context,
                                        widget.toLocalTime,
                                        invite.createdAt,
                                      ),
                                    ),
                                    key: Key('invite-created-${invite.id}'),
                                  ),
                                  Text(
                                    loc.friendsInviteExpiresLabel(
                                      _localDateLabel(
                                        context,
                                        widget.toLocalTime,
                                        invite.expiresAt,
                                      ),
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              value: OutlinedButton(
                                key: Key('invite-revoke-${invite.id}'),
                                onPressed: _controller.isInviteBusy(invite.id)
                                    ? null
                                    : () => _confirmRevoke(invite.id),
                                child: Text(loc.friendsRevokeButton),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A UTC ISO instant → medium local-date text, or "—" for a
/// malformed/unparsable instant (design D11). The intermediate `dayString`
/// step is required: `mediumDateLabelOrDash` expects a `YYYY-MM-DD` string,
/// not an ISO instant.
String _localDateLabel(
  BuildContext context,
  DateTime Function(DateTime) toLocalTime,
  String iso,
) {
  final instant = parseInstant(iso);
  if (instant == null) return mediumDateLabelOrDash(context, '');
  return mediumDateLabelOrDash(context, dayString(toLocalTime(instant)));
}

/// As [_localDateLabel] but with the local time of day appended — two
/// invites created on the same day are otherwise indistinguishable. `HH:mm`
/// (24h) matches the repo's existing time rendering (`care_today_screen`).
String _localDateTimeLabel(
  BuildContext context,
  DateTime Function(DateTime) toLocalTime,
  String iso,
) {
  final instant = parseInstant(iso);
  if (instant == null) return mediumDateLabelOrDash(context, '');
  final local = toLocalTime(instant);
  return '${mediumDateLabelOrDash(context, dayString(local))} '
      '${DateFormat('HH:mm').format(local)}';
}

class _InviteLinkCard extends StatelessWidget {
  final String link;
  final String? expiryLabel;
  final VoidCallback onCopy;

  const _InviteLinkCard({
    required this.link,
    required this.expiryLabel,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order matters more than it looks: at 320dp / textScale 2.0 the
          // link alone is ~20 lines of unbreakable URL (~480dp), so anything
          // placed after it starts below the fold — which is where the
          // warning and the Copy button used to be, invisible to exactly the
          // large-text user who most needs them. Instruction first, action
          // second, reference material (the URL, a fallback for manual
          // selection) last and height-capped.
          Text(loc.friendsInviteLinkTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // The plaintext token exists only in the create response (design
          // D5) — there is genuinely no way to show this link again, so say
          // so before the user leaves to paste it somewhere.
          Text(
            loc.friendsInviteLinkOnceWarning,
            key: const Key('friends-invite-link-warning'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('friends-copy-link-button'),
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: Text(loc.friendsCopyButton),
            ),
          ),
          const SizedBox(height: 12),
          // Capped: the full string stays selectable (the clipboard can be
          // refused — `friendsCopyFailedMessage` sends the user here), but it
          // must not push the rest of the card off a phone screen.
          SelectableText(
            link,
            key: const Key('friends-invite-link-text'),
            // `minLines` is not decoration: with only `maxLines` set, the
            // field is always that many lines tall, so a link that fits on
            // one line would still reserve three.
            minLines: 1,
            maxLines: 3,
            style: theme.textTheme.bodySmall,
          ),
          if (expiryLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              loc.friendsInviteExpiresLabel(expiryLabel!),
              key: const Key('friends-invite-link-expiry'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tier 1: the friends list is what this screen is, and it is empty. Gains
/// the icon; the body picks up the muted colour it lacked and moves from 8
/// to the standard 4 below the title. The key still comes from the call
/// site, and now lands on the guide's own column. No action: the invite
/// control is already the first thing on the screen, above this.
class _EmptyState extends StatelessWidget {
  final Key stateKey;

  const _EmptyState({required this.stateKey});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EmptyStateGuide(
        stateKey: stateKey,
        icon: Icons.group_outlined,
        title: loc.friendsEmptyTitle,
        body: loc.friendsEmptyMessage,
      ),
    );
  }
}
