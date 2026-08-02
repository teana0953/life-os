import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';

import 'app_test.dart';

/// Reports a different inviter name for every distinct token, so a test can
/// tell "the app re-previewed the new token" apart from "the app reused a
/// stale controller still holding the first preview" (design D13).
class _TokenAwareSocialRepository implements SocialRepository {
  final List<String?> previewedTokens = [];

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) async {
    previewedTokens.add(token);
    return InvitePreview(inviterDisplayName: 'Inviter-$token', alreadyFriends: false);
  }

  @override
  Future<List<Friend>> listFriends(String idToken) async => const [];

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {}

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) =>
      throw UnimplementedError();

  @override
  Future<List<FriendInvite>> listInvites(String idToken) async => const [];

  @override
  Future<void> revokeInvite(String idToken, String id) async {}

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) =>
      throw UnimplementedError();
}

void main() {
  group('App social routing', () {
    testWidgets(
      'a second /invite link (different token) replaces the first, without leaving the app '
      '(design D13: route builder gives InviteScreen key: ValueKey(token))',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(
          UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'user@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
            isAdmin: false,
          ),
        );
        final socialRepository = _TokenAwareSocialRepository();
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          socialRepository: socialRepository,
        );
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byKey(const Key('settings-icon-button'))),
        );

        router.go('/invite?token=a');
        await tester.pumpAndSettle();
        expect(find.text('Inviter-a invited you to be friends'), findsOneWidget);

        // Without leaving the app, open a second invite link carrying a
        // different token.
        router.go('/invite?token=b');
        await tester.pumpAndSettle();

        // The second inviter is shown — never the first — and the new token
        // was actually previewed (not just displayed from stale state).
        expect(find.text('Inviter-b invited you to be friends'), findsOneWidget);
        expect(find.text('Inviter-a invited you to be friends'), findsNothing);
        expect(socialRepository.previewedTokens, ['a', 'b']);
      },
    );
  });
}
