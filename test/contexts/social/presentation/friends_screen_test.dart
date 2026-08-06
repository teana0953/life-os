import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/application/invite_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/social/presentation/friends_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/config.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/widgets/empty_state.dart';

class _FakeAuthRepository implements AuthRepository {
  bool signedOut = false;
  int idTokenCalls = 0;

  /// A *different* token per call, the way Firebase hands out a refreshed
  /// one after the previous has expired — so a screen that caches the first
  /// token is visible in the tokens the repository receives.
  @override
  Future<String?> idToken() async {
    idTokenCalls += 1;
    return 'token-$idTokenCalls';
  }

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class _FakeSocialRepository implements SocialRepository {
  List<Friend> friends = const [];
  List<FriendInvite> invites = const [];

  final List<String> createInviteTokens = [];
  final List<String> removeFriendTokens = [];
  final List<String> revokeInviteTokens = [];

  Object? listFriendsError;
  Object? removeFriendError;
  Object? createInviteError;
  Object? revokeInviteError;

  ({String token, String expiresAt}) createInviteResult = (
    token: 'plaintext-token',
    expiresAt: '2026-09-01T12:00:00Z',
  );

  @override
  Future<List<Friend>> listFriends(String idToken) async {
    final failure = listFriendsError;
    if (failure != null) throw failure;
    return friends;
  }

  /// Per-friend gates, so a test can hold one removal in flight while it
  /// starts another — the overlap the SnackBar dedupe has to survive.
  final Map<String, Completer<void>> removeGates = {};

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {
    removeFriendTokens.add(idToken);
    final gate = removeGates[friendUserId];
    if (gate != null) await gate.future;
    final failure = removeFriendError;
    if (failure != null) throw failure;
    friends = friends.where((f) => f.userId != friendUserId).toList();
  }

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) async {
    createInviteTokens.add(idToken);
    final failure = createInviteError;
    if (failure != null) throw failure;
    return createInviteResult;
  }

  @override
  Future<List<FriendInvite>> listInvites(String idToken) async => invites;

  @override
  Future<void> revokeInvite(String idToken, String id) async {
    revokeInviteTokens.add(idToken);
    final failure = revokeInviteError;
    if (failure != null) throw failure;
    invites = invites.where((i) => i.id != id).toList();
  }

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) =>
      throw UnimplementedError();

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) =>
      throw UnimplementedError();
}

const _fixedOrigin = 'https://example.test';

Widget _friendsScreen(
  _FakeSocialRepository repository,
  _FakeAuthRepository authRepository, {
  DateTime Function(DateTime)? toLocalTime,
}) {
  return FriendsScreen(
    listFriends: ListFriends(repository),
    removeFriend: RemoveFriend(repository),
    createInvite: CreateInvite(repository),
    listInvites: ListInvites(repository),
    revokeInvite: RevokeInvite(repository),
    authRepository: authRepository,
    signOut: SignOut(authRepository),
    origin: () => _fixedOrigin,
    toLocalTime: toLocalTime ?? (dt) => dt,
  );
}

/// A router where `/friends` is reached directly (no back stack) — the
/// `canPop()`-false case (opened by URL, or landed on from `/invite`).
GoRouter _directRouter(Widget friendsScreen) => GoRouter(
  initialLocation: '/friends',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home-screen'))),
    GoRoute(path: '/friends', builder: (_, __) => friendsScreen),
  ],
);

/// A router where `/friends` is reached by pushing from a fake settings
/// screen — the `canPop()`-true case.
GoRouter _pushedRouter(Widget friendsScreen) => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home-screen'))),
    GoRoute(
      path: '/settings',
      builder: (context, state) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const Key('open-friends'),
            onPressed: () => context.push('/friends'),
            child: const Text('open friends'),
          ),
        ),
      ),
    ),
    GoRoute(path: '/friends', builder: (_, __) => friendsScreen),
  ],
);

Widget _app(GoRouter router) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  routerConfig: router,
);

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('FriendsScreen', () {
    testWidgets('lists friends by display name only', (tester) async {
      // `Friend` (domain/friend.dart) has no email field at all — there is
      // nothing for this screen to leak even by accident.
      final repository = _FakeSocialRepository()
        ..friends = const [
          Friend(userId: 'u1', displayName: 'Alex'),
          Friend(userId: 'u2', displayName: 'Jamie'),
        ];
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Jamie'), findsOneWidget);
    });

    testWidgets('shows the empty-state guide with the invite action when there are no friends', (
      tester,
    ) async {
      final repository = _FakeSocialRepository();
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friends-empty-state')), findsOneWidget);

      // Tier 1 (unify-empty-states): the shared full guide, keyed on its own
      // column, carrying the icon that says *which* kind of empty this is.
      expect(
        find.ancestor(
          of: find.byKey(const Key('friends-empty-state')),
          matching: find.byType(EmptyStateGuide),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EmptyStateGuide),
          matching: find.byIcon(Icons.group_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('friends-invite-button')), findsOneWidget);
    });

    testWidgets('a load failure shows an error with a retry action', (tester) async {
      final repository = _FakeSocialRepository()..listFriendsError = const SocialFetchFailure();
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friends-load-error')), findsOneWidget);

      repository.listFriendsError = null;
      repository.friends = const [Friend(userId: 'u1', displayName: 'Alex')];
      await tester.tap(find.byKey(const Key('friends-retry-button')));
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('a 401 shows the re-authentication exit, which signs out', (tester) async {
      final repository = _FakeSocialRepository()
        ..listFriendsError = const SocialReauthenticationRequired();
      final authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_app(_directRouter(_friendsScreen(repository, authRepository))));
      await tester.pumpAndSettle();

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);

      await tester.tap(find.byKey(const Key('friends-sign-in-again-button')));
      await tester.pumpAndSettle();

      expect(authRepository.signedOut, isTrue);
    });

    testWidgets('removing a friend requires confirmation naming the friend; cancel keeps them', (
      tester,
    ) async {
      final repository = _FakeSocialRepository()
        ..friends = const [Friend(userId: 'u1', displayName: 'Alex')];
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('friend-remove-u1')));
      await tester.pumpAndSettle();

      expect(find.text(loc.friendsRemoveConfirmTitle('Alex')), findsOneWidget);

      await tester.tap(find.byKey(const Key('friends-remove-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('confirming removal removes the friend from the list', (tester) async {
      final repository = _FakeSocialRepository()
        ..friends = const [Friend(userId: 'u1', displayName: 'Alex')];
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('friend-remove-u1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-remove-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsNothing);
      expect(find.byKey(const Key('friends-empty-state')), findsOneWidget);
    });

    testWidgets(
      'a remove failure (404) shows copy distinct from the invite-invalid copy, '
      'and refreshes the list',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..friends = const [Friend(userId: 'u1', displayName: 'Alex')]
          ..removeFriendError = const SocialNotFound();
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('friend-remove-u1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-remove-confirm')));
        await tester.pumpAndSettle();

        expect(find.text(loc.friendsRemoveNotFoundMessage), findsOneWidget);
        expect(find.text(loc.inviteInvalidMessage), findsNothing);
      },
    );

    testWidgets(
      'creating an invite shows the full link (with the injected origin and '
      '/#/) and a new invite appears in the outstanding list without leaving '
      'the page',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..createInviteResult = (
            token: 'secret-token',
            expiresAt: '2026-09-01T12:00:00Z',
          );
        // The repository only returns the new invite once the list is
        // re-fetched — mirrors the real API's no-id create response.
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        repository.invites = [
          const FriendInvite(
            id: 'inv-1',
            expiresAt: '2026-09-01T12:00:00Z',
            createdAt: '2026-08-01T00:00:00Z',
          ),
        ];
        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();

        expect(
          find.text('$_fixedOrigin/#/invite?token=secret-token'),
          findsOneWidget,
        );
        // With no friends yet, the empty-state guide above the outstanding
        // list is a full guide (icon + title + body), so the invite row is
        // past the end of the lazily-built window rather than absent.
        await tester.scrollUntilVisible(
          find.byKey(const Key('invite-row-inv-1')),
          200,
          // The page's own ListView: the link card carries a second,
          // horizontal Scrollable, and the default finder matches both.
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(const Key('invite-row-inv-1')), findsOneWidget);
      },
    );

    testWidgets('an invite-creation failure shows an error and no link', (tester) async {
      final repository = _FakeSocialRepository()..createInviteError = const SocialFetchFailure();
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('friends-invite-button')));
      await tester.pumpAndSettle();

      expect(find.text(loc.friendsCreateInviteFailedMessage), findsOneWidget);
      expect(find.byKey(const Key('friends-invite-link-text')), findsNothing);
    });

    testWidgets('a created link does not outlive the page: leaving and returning shows none', (
      tester,
    ) async {
      final repository = _FakeSocialRepository();
      final authRepository = _FakeAuthRepository();
      final router = _pushedRouter(_friendsScreen(repository, authRepository));
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-friends')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-invite-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('friends-invite-link-text')), findsOneWidget);

      // Leave, then come back — a brand-new FriendsController is built
      // (design D9), so the plaintext token from before is gone.
      await tester.tap(find.byKey(const Key('friends-back-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-friends')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friends-invite-link-text')), findsNothing);
    });

    testWidgets('revoking an invite asks for confirmation first; cancel keeps it', (
      tester,
    ) async {
      final repository = _FakeSocialRepository()
        ..invites = const [
          FriendInvite(
            id: 'inv-1',
            expiresAt: '2026-09-01T12:00:00Z',
            createdAt: '2026-08-01T00:00:00Z',
          ),
        ];
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
      await tester.pumpAndSettle();

      // The person holding the link is the one who pays for a mistaken
      // revoke, so nothing is sent until this is confirmed.
      expect(find.text(loc.friendsRevokeConfirmTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('friends-revoke-cancel')));
      await tester.pumpAndSettle();

      expect(repository.revokeInviteTokens, isEmpty);
      expect(find.byKey(const Key('invite-row-inv-1')), findsOneWidget);
    });

    testWidgets('confirming the revoke removes the invite from the list', (tester) async {
      final repository = _FakeSocialRepository()
        ..invites = const [
          FriendInvite(
            id: 'inv-1',
            expiresAt: '2026-09-01T12:00:00Z',
            createdAt: '2026-08-01T00:00:00Z',
          ),
        ];
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-revoke-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-row-inv-1')), findsNothing);
    });

    testWidgets(
      'two invites expiring on the same day are told apart by their creation time',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..invites = const [
            FriendInvite(
              id: 'inv-1',
              expiresAt: '2026-09-01T12:00:00Z',
              createdAt: '2026-08-25T09:30:00Z',
            ),
            FriendInvite(
              id: 'inv-2',
              expiresAt: '2026-09-01T12:00:00Z',
              createdAt: '2026-08-25T17:45:00Z',
            ),
          ];
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        String rowText(String id) => tester
            .widget<Text>(find.byKey(Key('invite-created-$id')))
            .data!;

        expect(rowText('inv-1'), contains('09:30'));
        expect(rowText('inv-2'), contains('17:45'));
        expect(rowText('inv-1'), isNot(rowText('inv-2')));
      },
    );

    testWidgets('copying the invite link copies the exact text and confirms', (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final repository = _FakeSocialRepository()
        ..createInviteResult = (token: 'secret-token', expiresAt: '2026-09-01T12:00:00Z');
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('friends-invite-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-copy-link-button')));
      await tester.pumpAndSettle();

      expect(copiedText, '$_fixedOrigin/#/invite?token=secret-token');
      expect(find.text(loc.friendsCopiedMessage), findsOneWidget);
    });

    testWidgets(
      'a rejecting clipboard shows a distinct copy-failed message instead of nothing, '
      'and the link text stays on screen so it can be copied manually',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                throw PlatformException(code: 'denied');
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final repository = _FakeSocialRepository()
          ..createInviteResult = (token: 'secret-token', expiresAt: '2026-09-01T12:00:00Z');
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-copy-link-button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(loc.friendsCopyFailedMessage), findsOneWidget);
        expect(find.text(loc.friendsCopiedMessage), findsNothing);
        expect(find.byKey(const Key('friends-invite-link-text')), findsOneWidget);
      },
    );

    testWidgets('shows the invite expiry date using an injected local-time conversion', (
      tester,
    ) async {
      // Fixed offset so the UTC-midnight-adjacent instant rolls to a
      // different local calendar day than a naive UTC read would give —
      // pins that the injected conversion (not the identity) actually ran.
      DateTime toLocal(DateTime utc) => utc.add(const Duration(hours: 10));
      final repository = _FakeSocialRepository()
        ..invites = const [
          FriendInvite(
            // 23:00 UTC on Aug 31 + 10h = 09:00 local on Sep 1.
            id: 'inv-1',
            expiresAt: '2026-08-31T23:00:00Z',
            createdAt: '2026-08-01T00:00:00Z',
          ),
        ];
      await tester.pumpWidget(
        _app(
          _directRouter(
            _friendsScreen(repository, _FakeAuthRepository(), toLocalTime: toLocal),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      final expectedDate = mediumDateLabelOrDash(context, '2026-09-01');
      expect(find.text(loc.friendsInviteExpiresLabel(expectedDate)), findsOneWidget);
    });

    testWidgets('canPop() true: the back button pops back to the caller', (tester) async {
      final repository = _FakeSocialRepository();
      final router = _pushedRouter(_friendsScreen(repository, _FakeAuthRepository()));
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-friends')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('friends-back-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('friends-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('open friends'), findsOneWidget);
    });

    testWidgets('canPop() false: the back button lands on the home screen', (tester) async {
      final repository = _FakeSocialRepository();
      final router = _directRouter(_friendsScreen(repository, _FakeAuthRepository()));
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('friends-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('home-screen'), findsOneWidget);
    });
    testWidgets(
      'the id token is fetched fresh per request, never the one cached at load',
      (tester) async {
        // A friends page left open outlives a Firebase id token (~1h). A
        // cached token 401s, and the 401 exit signs the user out.
        final repository = _FakeSocialRepository()
          ..friends = const [Friend(userId: 'u1', displayName: 'Alex')]
          ..invites = const [
            FriendInvite(
              id: 'inv-1',
              expiresAt: '2026-09-01T12:00:00Z',
              createdAt: '2026-08-01T00:00:00Z',
            ),
          ];
        final authRepository = _FakeAuthRepository();
        await tester.pumpWidget(_app(_directRouter(_friendsScreen(repository, authRepository))));
        await tester.pumpAndSettle();

        // Load used token-1.
        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friend-remove-u1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-remove-confirm')));
        await tester.pumpAndSettle();
        // The link card and (with no friends) the empty-state guide are on
        // screen, so the invite row sits past the end of the lazily-built
        // window — scrolled to first, then brought fully into view.
        await tester.scrollUntilVisible(
          find.byKey(const Key('invite-revoke-inv-1')),
          200,
          // The page's own ListView: the link card carries a second,
          // horizontal Scrollable, and the default finder matches both.
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byKey(const Key('invite-revoke-inv-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-revoke-confirm')));
        await tester.pumpAndSettle();

        expect(repository.createInviteTokens, ['token-2']);
        expect(repository.removeFriendTokens, ['token-3']);
        expect(repository.revokeInviteTokens, ['token-4']);
      },
    );

    testWidgets(
      'the created link is shown with its expiry and a warning that it is '
      'shown only once',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..createInviteResult = (
            token: 'secret-token',
            expiresAt: '2026-09-01T12:00:00Z',
          );
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.friendsInviteLinkOnceWarning), findsOneWidget);

        final context = tester.element(find.byType(Scaffold).first);
        final expected = loc.friendsInviteExpiresLabel(
          mediumDateLabelOrDash(context, '2026-09-01'),
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('friends-invite-link-expiry'))).data,
          expected,
        );
      },
    );

    testWidgets(
      'a failed list refresh after a successful create keeps the one-time link '
      'on screen instead of blanking the page',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..createInviteResult = (
            token: 'secret-token',
            expiresAt: '2026-09-01T12:00:00Z',
          );
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        repository.listFriendsError = const SocialFetchFailure();
        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();

        expect(find.text('$_fixedOrigin/#/invite?token=secret-token'), findsOneWidget);
        expect(find.byKey(const Key('friends-load-error')), findsNothing);
      },
    );

    testWidgets(
      'a revoke failure is surfaced in a SnackBar, not as text that can be '
      'scrolled out of view',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..invites = const [
            FriendInvite(
              id: 'inv-1',
              expiresAt: '2026-09-01T12:00:00Z',
              createdAt: '2026-08-01T00:00:00Z',
            ),
          ]
          ..revokeInviteError = const SocialFetchFailure();
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-revoke-confirm')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(loc.friendsRevokeFailedMessage),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'creating another link while the first is uncopied asks first; '
      'cancelling keeps the first link and sends nothing',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..createInviteResult = (token: 'secret-token', expiresAt: '2026-09-01T12:00:00Z');
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();
        expect(repository.createInviteTokens, hasLength(1));

        // Inviting a second friend is an ordinary reason to press this
        // again — and it destroys the first, uncopied, unrecoverable link.
        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();
        expect(find.text(loc.friendsCreateAnotherConfirmTitle), findsOneWidget);

        await tester.tap(find.byKey(const Key('friends-create-another-cancel')));
        await tester.pumpAndSettle();

        expect(repository.createInviteTokens, hasLength(1));
        expect(find.text('$_fixedOrigin/#/invite?token=secret-token'), findsOneWidget);
      },
    );

    testWidgets(
      'once the link has been copied there is nothing left to lose, so '
      'creating another one does not ask',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final repository = _FakeSocialRepository()
          ..createInviteResult = (token: 'secret-token', expiresAt: '2026-09-01T12:00:00Z');
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-copy-link-button')));
        await tester.pumpAndSettle();

        repository.createInviteResult = (
          token: 'second-token',
          expiresAt: '2026-09-02T12:00:00Z',
        );
        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.friendsCreateAnotherConfirmTitle), findsNothing);
        expect(find.text('$_fixedOrigin/#/invite?token=second-token'), findsOneWidget);
      },
    );

    testWidgets(
      'while a fresh link is on screen Copy is the primary action and the '
      'create button steps down and says it replaces the link',
      (tester) async {
        final repository = _FakeSocialRepository();
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        // Before there is a link, creating one is the page's primary action.
        expect(
          find.descendant(
            of: find.byKey(const Key('friends-invite-button')),
            matching: find.text(loc.friendsInviteButton),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget(find.byKey(const Key('friends-invite-button'))),
          isA<FilledButton>(),
        );

        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();

        expect(
          tester.widget(find.byKey(const Key('friends-copy-link-button'))),
          isA<FilledButton>(),
        );
        expect(
          tester.widget(find.byKey(const Key('friends-invite-button'))),
          isA<OutlinedButton>(),
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('friends-invite-button')),
            matching: find.text(loc.friendsInviteAnotherButton),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'revoking the invite the on-screen link belongs to takes the link card '
      'with it',
      (tester) async {
        final repository = _FakeSocialRepository();
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        repository.invites = const [
          FriendInvite(
            id: 'inv-1',
            expiresAt: '2026-09-01T12:00:00Z',
            createdAt: '2026-08-01T00:00:00Z',
          ),
        ];
        await tester.tap(find.byKey(const Key('friends-invite-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('friends-invite-link-text')), findsOneWidget);

        // The link card and (with no friends) the empty-state guide are on
        // screen, so the invite row sits past the end of the lazily-built
        // window — scrolled to first, then brought fully into view.
        await tester.scrollUntilVisible(
          find.byKey(const Key('invite-revoke-inv-1')),
          200,
          // The page's own ListView: the link card carries a second,
          // horizontal Scrollable, and the default finder matches both.
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byKey(const Key('invite-revoke-inv-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-revoke-confirm')));
        await tester.pumpAndSettle();

        // A revoked link is dead: leaving it on screen next to a live Copy
        // button would have the user share something that only fails.
        expect(find.byKey(const Key('friends-invite-link-text')), findsNothing);
        expect(find.byKey(const Key('friends-copy-link-button')), findsNothing);
      },
    );

    testWidgets(
      'two overlapping removals that fail the same way are both reported, '
      'not deduped into one SnackBar',
      (tester) async {
        final repository = _FakeSocialRepository()
          ..friends = const [
            Friend(userId: 'u1', displayName: 'Alex'),
            Friend(userId: 'u2', displayName: 'Jamie'),
          ]
          ..removeFriendError = const SocialFetchFailure()
          ..removeGates['u1'] = Completer<void>()
          ..removeGates['u2'] = Completer<void>();
        await tester.pumpWidget(
          _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        // Both removals are in flight at the same time (per-item busy flags
        // allow it by design).
        await tester.tap(find.byKey(const Key('friend-remove-u1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-remove-confirm')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('friend-remove-u2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('friends-remove-confirm')));
        await tester.pump();

        repository.removeGates['u1']!.complete();
        await tester.pumpAndSettle();
        expect(find.text(loc.friendsRemoveFailedMessage), findsOneWidget);

        repository.removeGates['u2']!.complete();
        await tester.pumpAndSettle();

        // Dismiss the first SnackBar and see whether a second one is queued
        // behind it: without it, the user concludes the other removal worked.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text(loc.friendsRemoveFailedMessage), findsOneWidget);
      },
    );

    testWidgets('a revoke 404 shows its own copy, distinct from the generic failure', (
      tester,
    ) async {
      final repository = _FakeSocialRepository()
        ..invites = const [
          FriendInvite(
            id: 'inv-1',
            expiresAt: '2026-09-01T12:00:00Z',
            createdAt: '2026-08-01T00:00:00Z',
          ),
        ]
        ..revokeInviteError = const SocialNotFound();
      await tester.pumpWidget(
        _app(_directRouter(_friendsScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('friends-revoke-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(loc.friendsRevokeNotFoundMessage), findsOneWidget);
      expect(find.text(loc.friendsRevokeFailedMessage), findsNothing);
    });
  });

  // The back button is this page's only exit in every state, including the
  // states where there is nothing to pop. An icon-only IconButton with no
  // tooltip has an empty semantics label, so a screen-reader user gets an
  // unlabelled button where the sole way out is.
  //
  // What this proves: with semantics switched on, the button's render object
  // produces a semantics node that carries the localized back-button text as
  // a real semantics property (`SemanticsNode.tooltip`, what a screen reader
  // reads out for a tooltip-labelled button) and a non-empty rect — a
  // zero-rect node is dropped before it could reach any platform tree.
  // What it does NOT prove: that the node was delivered to the *platform*
  // accessibility tree, nor that a screen reader announces it —
  // `getSemantics` reads the framework-side tree this process owns (repo
  // memory: "Flutter 語意測試"). Only a real device pass proves that.
  testWidgets('the back button exposes a labelled semantics node', (tester) async {
    // Disposed at the end of the body, not via addTearDown: the binding
    // verifies no handle is outstanding *before* tear-downs run.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(_directRouter(_friendsScreen(_FakeSocialRepository(), _FakeAuthRepository()))),
    );
    await tester.pumpAndSettle();

    final finder = find.byKey(const Key('friends-back-button'));
    final expectedLabel = MaterialLocalizations.of(
      tester.element(finder),
    ).backButtonTooltip;
    final node = tester.getSemantics(finder);

    expect(node.tooltip, expectedLabel);
    expect(node.rect.isEmpty, isFalse);

    handle.dispose();
  });

  // `Uri.base.origin` throws `StateError` off the web (`Uri.base` is a
  // `file://` URI on the VM and on a native build), and nothing injects an
  // origin in production — so an unguarded default red-screens the friends
  // page the moment a link is rendered. This runs on the VM, i.e. exactly the
  // non-web platform where the unguarded version throws.
  test('the default invite origin is safe off the web', () {
    expect(defaultInviteOrigin(), appWebOrigin);
  });
}