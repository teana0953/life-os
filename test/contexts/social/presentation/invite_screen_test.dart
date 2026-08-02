import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/social/application/invite_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_exceptions.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/social/presentation/invite_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  bool signedOut = false;

  @override
  Future<String?> idToken() async => 'token-123';

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
  InvitePreview previewResult = const InvitePreview(
    inviterDisplayName: 'Alex',
    alreadyFriends: false,
  );
  AcceptInviteResult acceptResult = const AcceptInviteResult(
    friend: Friend(userId: 'u1', displayName: 'Alex'),
    alreadyFriends: false,
  );
  Object? previewError;
  Object? acceptError;
  String? lastPreviewToken;
  String? lastAcceptToken;

  /// When set, `acceptInvite` waits on this before resolving — lets a test
  /// observe the in-flight state deterministically instead of racing the
  /// microtask queue.
  Completer<void>? acceptGate;

  /// Same idea as [acceptGate], for the initial preview — lets a test hold
  /// the page in its `previewing` state.
  Completer<void>? previewGate;

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) async {
    lastPreviewToken = token;
    final gate = previewGate;
    if (gate != null) await gate.future;
    final failure = previewError;
    if (failure != null) throw failure;
    return previewResult;
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) async {
    lastAcceptToken = token;
    final gate = acceptGate;
    if (gate != null) await gate.future;
    final failure = acceptError;
    if (failure != null) throw failure;
    return acceptResult;
  }

  @override
  Future<List<Friend>> listFriends(String idToken) => throw UnimplementedError();

  @override
  Future<void> removeFriend(String idToken, String friendUserId) =>
      throw UnimplementedError();

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) =>
      throw UnimplementedError();

  @override
  Future<List<FriendInvite>> listInvites(String idToken) => throw UnimplementedError();

  @override
  Future<void> revokeInvite(String idToken, String id) => throw UnimplementedError();
}

Widget _inviteScreen(
  _FakeSocialRepository repository,
  _FakeAuthRepository authRepository, {
  String? token = 'abc',
}) {
  return InviteScreen(
    previewInvite: PreviewInvite(repository),
    acceptInvite: AcceptInvite(repository),
    authRepository: authRepository,
    signOut: SignOut(authRepository),
    token: token,
  );
}

/// A router with `/invite` and `/friends` — accept success navigates via
/// `context.go('/friends')`.
GoRouter _router(Widget inviteScreen) => GoRouter(
  initialLocation: '/invite',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home-screen'))),
    GoRoute(path: '/invite', builder: (_, __) => inviteScreen),
    GoRoute(
      path: '/friends',
      builder: (_, __) => const Scaffold(body: Text('friends-screen')),
    ),
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

  group('InviteScreen', () {
    testWidgets('previews the invite and shows the inviter with no accept request sent yet', (
      tester,
    ) async {
      final repository = _FakeSocialRepository();
      await tester.pumpWidget(
        _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.inviteFromMessage('Alex')), findsOneWidget);
      expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
      expect(repository.lastAcceptToken, isNull);
    });

    testWidgets('accepting succeeds and navigates to the friends list', (tester) async {
      final repository = _FakeSocialRepository();
      await tester.pumpWidget(
        _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invite-accept-button')));
      await tester.pumpAndSettle();

      expect(repository.lastAcceptToken, 'abc');
      expect(find.text('friends-screen'), findsOneWidget);
    });

    testWidgets('the accept action is disabled while accepting is in flight', (tester) async {
      final gate = Completer<void>();
      final repository = _FakeSocialRepository()..acceptGate = gate;
      await tester.pumpWidget(
        _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invite-accept-button')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('invite-accept-button')),
      );
      expect(button.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('already_friends shows distinct wording from a fresh acceptance', (tester) async {
      final repository = _FakeSocialRepository()
        ..previewResult = const InvitePreview(
          inviterDisplayName: 'Alex',
          alreadyFriends: true,
        );
      await tester.pumpWidget(
        _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.inviteAlreadyFriendsMessage('Alex')), findsOneWidget);
      expect(find.text(loc.inviteFromMessage('Alex')), findsNothing);

      await tester.tap(find.byKey(const Key('invite-back-to-friends-button')));
      await tester.pumpAndSettle();

      expect(find.text('friends-screen'), findsOneWidget);
    });

    for (final entry in {
      const InviteExpired(): 'inviteExpiredMessage',
      const InviteAlreadyUsed(): 'inviteAlreadyUsedMessage',
      const InviteRevoked(): 'inviteRevokedMessage',
      const InviteNotFound(): 'inviteInvalidMessage',
    }.entries) {
      testWidgets('${entry.key.runtimeType} on preview shows its own actionable message', (
        tester,
      ) async {
        final repository = _FakeSocialRepository()..previewError = entry.key;
        await tester.pumpWidget(
          _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('invite-error-message')), findsOneWidget);
        expect(find.byKey(const Key('invite-back-to-friends-button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('invite-back-to-friends-button')));
        await tester.pumpAndSettle();
        expect(find.text('friends-screen'), findsOneWidget);
      });
    }

    testWidgets(
      "the user's own invite: preview succeeds and offers accept; only "
      'after accepting (cannot_friend_self) does it explain this is the '
      "user's own invite",
      (tester) async {
        final repository = _FakeSocialRepository()..acceptError = const CannotFriendSelf();
        await tester.pumpWidget(
          _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
        expect(find.byKey(const Key('invite-error-message')), findsNothing);

        await tester.tap(find.byKey(const Key('invite-accept-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.inviteOwnInviteMessage), findsOneWidget);
      },
    );

    testWidgets(
      'a generic/network failure (SocialFetchFailure) on preview shows its own message '
      'with a retry action, distinct from the invalid-link copy',
      (tester) async {
        final repository = _FakeSocialRepository()..previewError = const SocialFetchFailure();
        await tester.pumpWidget(
          _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();

        expect(find.text(loc.inviteFetchFailedMessage), findsOneWidget);
        expect(find.text(loc.inviteInvalidMessage), findsNothing);
        expect(find.byKey(const Key('invite-retry-button')), findsOneWidget);

        // Retrying re-runs preview; once it succeeds, the ready state shows.
        repository.previewError = null;
        await tester.tap(find.byKey(const Key('invite-retry-button')));
        await tester.pumpAndSettle();

        expect(find.text(loc.inviteFromMessage('Alex')), findsOneWidget);
      },
    );

    testWidgets('a blank/missing token shows the invalid-link state without a preview request', (
      tester,
    ) async {
      final repository = _FakeSocialRepository();
      await tester.pumpWidget(
        _app(_router(_inviteScreen(repository, _FakeAuthRepository(), token: null))),
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.inviteInvalidMessage), findsOneWidget);
      expect(repository.lastPreviewToken, isNull);
    });

    testWidgets('a 401 shows the re-authentication exit, which signs out', (tester) async {
      final repository = _FakeSocialRepository()
        ..previewError = const SocialReauthenticationRequired();
      final authRepository = _FakeAuthRepository();
      await tester.pumpWidget(_app(_router(_inviteScreen(repository, authRepository))));
      await tester.pumpAndSettle();

      expect(find.text(loc.pleaseSignInAgain), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-sign-in-again-button')));
      await tester.pumpAndSettle();

      expect(authRepository.signedOut, isTrue);
    });
    testWidgets(
      'the preview state offers a way out that is not accepting: with nothing '
      'to pop, back lands on the home screen and consumes no invite',
      (tester) async {
        // Cold start from an externally shared link: this page is the whole
        // in-app stack, and accept is irreversible.
        final repository = _FakeSocialRepository();
        await tester.pumpWidget(
          _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('invite-back-button')));
        await tester.pumpAndSettle();

        expect(find.text('home-screen'), findsOneWidget);
        expect(repository.lastAcceptToken, isNull);
      },
    );

    testWidgets('the loading state can be left too', (tester) async {
      final repository = _FakeSocialRepository()..previewGate = Completer<void>();
      await tester.pumpWidget(
        _app(_router(_inviteScreen(repository, _FakeAuthRepository()))),
      );
      await tester.pump();
      expect(find.byKey(const Key('invite-loading')), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('home-screen'), findsOneWidget);

      repository.previewGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('canPop() true: the back button pops back to the caller', (tester) async {
      final repository = _FakeSocialRepository();
      final router = GoRouter(
        initialLocation: '/friends',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home-screen'))),
          GoRoute(
            path: '/friends',
            builder: (context, state) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-invite'),
                  onPressed: () => context.push('/invite'),
                  child: const Text('open invite'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/invite',
            builder: (_, __) => _inviteScreen(repository, _FakeAuthRepository()),
          ),
        ],
      );
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-invite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-back-button')));
      await tester.pumpAndSettle();

      expect(find.text('open invite'), findsOneWidget);
    });
  });

  // Same reasoning as the friends page: this is the only exit in every state,
  // and an icon-only IconButton with no tooltip has an empty semantics label.
  //
  // What this proves: with semantics switched on, the button's render object
  // produces a semantics node carrying the localized back-button text as a
  // real semantics property (`SemanticsNode.tooltip`) and a non-empty rect —
  // a zero-rect node is dropped before it could reach any platform tree.
  // What it does NOT prove: delivery to the *platform* accessibility tree or
  // that a screen reader announces it — `getSemantics` reads the
  // framework-side tree this process owns (repo memory: "Flutter 語意測試").
  testWidgets('the back button exposes a labelled semantics node', (tester) async {
    // Disposed at the end of the body, not via addTearDown: the binding
    // verifies no handle is outstanding *before* tear-downs run.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(_router(_inviteScreen(_FakeSocialRepository(), _FakeAuthRepository()))),
    );
    await tester.pumpAndSettle();

    final finder = find.byKey(const Key('invite-back-button'));
    final expectedLabel = MaterialLocalizations.of(
      tester.element(finder),
    ).backButtonTooltip;
    final node = tester.getSemantics(finder);

    expect(node.tooltip, expectedLabel);
    expect(node.rect.isEmpty, isFalse);

    handle.dispose();
  });
}