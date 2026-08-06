import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/social/application/friend_use_cases.dart';
import 'package:life_os/contexts/social/application/invite_use_cases.dart';
import 'package:life_os/contexts/social/domain/friend.dart';
import 'package:life_os/contexts/social/domain/friend_invite.dart';
import 'package:life_os/contexts/social/domain/invite_preview.dart';
import 'package:life_os/contexts/social/domain/social_repository.dart';
import 'package:life_os/contexts/social/presentation/friends_screen.dart';
import 'package:life_os/contexts/social/presentation/invite_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';
import '../../../support/layout_guard.dart';
import '../../../support/month_label.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => 'token-123';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

/// Backs both `/friends` (friends + outstanding invites) and `/invite`
/// (preview) so one fake repository serves every layout-guard case below.
class _FakeSocialRepository implements SocialRepository {
  List<Friend> friends = const [];
  List<FriendInvite> invites = const [];
  InvitePreview previewResult = const InvitePreview(
    inviterDisplayName: 'Alex',
    alreadyFriends: false,
  );

  /// A realistic base64url invite token: the link is a ~70-char unbreakable
  /// URL, which is the shape this guard exists to keep from overflowing.
  ({String token, String expiresAt}) createInviteResult = (
    token: 'v3xQ2mB7pR9kLd0sTnW4yG6hJ1cZaE8fUiO5rMqXbNvKt2SgH',
    expiresAt: '2026-09-01T12:00:00Z',
  );

  @override
  Future<List<Friend>> listFriends(String idToken) async => friends;

  @override
  Future<void> removeFriend(String idToken, String friendUserId) async {}

  @override
  Future<({String token, String expiresAt})> createInvite(String idToken) async =>
      createInviteResult;

  @override
  Future<List<FriendInvite>> listInvites(String idToken) async => invites;

  @override
  Future<void> revokeInvite(String idToken, String id) async {}

  @override
  Future<InvitePreview> previewInvite(String idToken, String token) async =>
      previewResult;

  @override
  Future<AcceptInviteResult> acceptInvite(String idToken, String token) =>
      throw UnimplementedError();
}

const _fixedOrigin = 'https://example.test';

/// A realistic phone viewport height. The previous guard pumped every case
/// into a 2400dp-tall surface — taller than any real phone — which is
/// exactly how the remove-friend confirmation dialog's overflow at
/// textScale 2.0 (QA finding 1) slipped through: nothing that tall ever
/// runs out of room.
const _phoneHeight = 800.0;

/// Origin is injected as a fixed value (design D1): `Uri.base.origin` throws
/// `StateError` on the VM, and this guard renders the invite-link card.
Widget _friendsScreen(_FakeSocialRepository repository, AuthRepository authRepository) =>
    FriendsScreen(
      listFriends: ListFriends(repository),
      removeFriend: RemoveFriend(repository),
      createInvite: CreateInvite(repository),
      listInvites: ListInvites(repository),
      revokeInvite: RevokeInvite(repository),
      authRepository: authRepository,
      signOut: SignOut(authRepository),
      origin: () => _fixedOrigin,
      toLocalTime: (dt) => dt,
    );

Widget _inviteScreen(_FakeSocialRepository repository, AuthRepository authRepository) =>
    InviteScreen(
      previewInvite: PreviewInvite(repository),
      acceptInvite: AcceptInvite(repository),
      authRepository: authRepository,
      signOut: SignOut(authRepository),
      token: 'abc',
    );

/// Wraps [home] as the `/` route of a minimal `go_router` app with the given
/// [locale] — both screens use `context.push`/`context.pop`/`context.go`
/// internally, so a bare `MaterialApp` isn't enough (mirrors
/// `friends_screen_test.dart`'s router setup).
Future<void> _pumpAtRoot(WidgetTester tester, Widget home, Locale locale) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => home)],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: testSupportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('friends and invite pages: narrow-width layout guard', () {
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            'FriendsScreen lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repository = _FakeSocialRepository()
                ..friends = const [
                  Friend(userId: 'u1', displayName: 'Alex'),
                  Friend(userId: 'u2', displayName: 'Jamie'),
                ]
                ..invites = const [
                  FriendInvite(
                    id: 'inv-1',
                    expiresAt: '2026-09-01T12:00:00Z',
                    createdAt: '2026-08-01T00:00:00Z',
                  ),
                ];
              // Assertions stay *outside* the body on purpose
              // (`layout_guard.dart`'s doc comment): a failing `expect` while
              // `FlutterError.onError` is still redirected aborts before the
              // collected layout errors are ever reported, and the real
              // diagnosis is lost.
              await expectNoLayoutErrors(
                () => _pumpAtRoot(
                  tester,
                  _friendsScreen(repository, _FakeAuthRepository()),
                  locale,
                ),
              );

              // A blank screen also reports no layout error, so pin that the
              // page this guard is about actually rendered.
              expect(find.byKey(const Key('friend-row-u1')), findsOneWidget);

              // The invite-link card is the whole reason the origin is
              // injected — render it, don't just claim it is rendered. It is
              // a ~70-char unbreakable URL in a card, so it only gets laid
              // out once an invite is actually created.
              await expectNoLayoutErrors(() async {
                await tester.tap(find.byKey(const Key('friends-invite-button')));
                await tester.pumpAndSettle();
              });

              expect(find.byKey(const Key('friends-invite-link-text')), findsOneWidget);

              // No layout error is raised by content that merely scrolls out
              // of sight — and that is exactly how the one-time-link warning
              // and its Copy action ended up ~400dp below the fold at
              // textScale 2.0, behind a wall of unbreakable URL. The user who
              // needs the warning most is the one who never saw it, so pin
              // both inside the viewport without scrolling.
              final warningRect = tester.getRect(
                find.byKey(const Key('friends-invite-link-warning')),
              );
              final copyRect = tester.getRect(
                find.byKey(const Key('friends-copy-link-button')),
              );
              expect(warningRect.bottom, lessThanOrEqualTo(_phoneHeight));
              expect(copyRect.bottom, lessThanOrEqualTo(_phoneHeight));
              expect(copyRect.right, lessThanOrEqualTo(width));
            },
          );

          testWidgets(
            'InviteScreen lays out cleanly at ${width.toInt()}dp, '
            'textScale=$textScale, locale=$locale',
            (tester) async {
              useTextScaleFactor(tester, textScale);
              await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
              addTearDown(() => tester.binding.setSurfaceSize(null));

              final repository = _FakeSocialRepository();
              await expectNoLayoutErrors(
                () => _pumpAtRoot(
                  tester,
                  _inviteScreen(repository, _FakeAuthRepository()),
                  locale,
                ),
              );

              expect(find.byKey(const Key('invite-accept-button')), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('friends page: long display name', () {
    testWidgets(
      'a very long friend name wraps or shrinks and the remove action stays fully visible',
      (tester) async {
        const width = 320.0;
        await tester.binding.setSurfaceSize(const Size(width, _phoneHeight));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const longName =
            'Alexandria Bartholomew-Featherstonehaugh the Third of Wonderland';
        final repository = _FakeSocialRepository()
          ..friends = const [Friend(userId: 'u1', displayName: longName)];

        await expectNoLayoutErrors(
          () => _pumpAtRoot(
            tester,
            _friendsScreen(repository, _FakeAuthRepository()),
            const Locale('en'),
          ),
        );

        final buttonFinder = find.byKey(const Key('friend-remove-u1'));
        expect(buttonFinder, findsOneWidget);

        // The action must stay within the surface's bounds — not pushed off
        // to the right by an unwrapped, unshrunk long name.
        final rect = tester.getRect(buttonFinder);
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.left, greaterThanOrEqualTo(0));

        // And genuinely tappable, not just laid out: it opens the remove
        // confirmation naming the friend.
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();
        final loc = lookupAppLocalizations(const Locale('en'));
        expect(find.text(loc.friendsRemoveConfirmTitle(longName)), findsOneWidget);
      },
    );

    // QA finding 1: at textScale 2.0 on a real phone-height viewport, a long
    // name in the remove-confirmation dialog pushed Cancel/Remove below the
    // fold with a RenderFlex overflow — the user could neither confirm nor
    // cancel. The guard above missed it because it pumped every case into a
    // 2400dp-tall surface (no phone is that tall) and only opened the
    // dialog at textScale 1.0. This covers the dialog itself, at the scale
    // and height that actually reproduced the defect.
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'the remove-confirmation dialog for a long name keeps Cancel and '
        'Remove reachable at ${width.toInt()}dp, textScale=2.0',
        (tester) async {
          useTextScaleFactor(tester, 2.0);
          await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          const longName =
              'Alexandria Bartholomew-Featherstonehaugh the Third of Wonderland';
          final repository = _FakeSocialRepository()
            ..friends = const [Friend(userId: 'u1', displayName: longName)];

          await expectNoLayoutErrors(() async {
            await _pumpAtRoot(
              tester,
              _friendsScreen(repository, _FakeAuthRepository()),
              const Locale('en'),
            );
            await tester.tap(find.byKey(const Key('friend-remove-u1')));
            await tester.pumpAndSettle();
          });

          final loc = lookupAppLocalizations(const Locale('en'));
          expect(find.text(loc.friendsRemoveConfirmTitle(longName)), findsOneWidget);

          // Both actions must actually sit within the visible viewport, not
          // merely be laid out without error.
          final cancelRect = tester.getRect(find.byKey(const Key('friends-remove-cancel')));
          final confirmRect = tester.getRect(find.byKey(const Key('friends-remove-confirm')));
          expect(cancelRect.bottom, lessThanOrEqualTo(_phoneHeight));
          expect(confirmRect.bottom, lessThanOrEqualTo(_phoneHeight));

          // And genuinely reachable/tappable, not just within bounds: tapping
          // it closes the dialog.
          await tester.tap(find.byKey(const Key('friends-remove-confirm')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('friends-remove-confirm')), findsNothing);
        },
      );
    }

    // The revoke confirmation is the change's *other* destructive dialog and
    // carries its longest zh-Hant body copy, but the guard above was written
    // for the remove dialog only — the identical overflow was found by hand
    // on the sibling. Same viewport, same text scale, both locales.
    for (final width in [320.0, 360.0]) {
      for (final locale in testSupportedLocales) {
        testWidgets(
          'the revoke-confirmation dialog keeps Cancel and Revoke reachable '
          'at ${width.toInt()}dp, textScale=2.0, locale=$locale',
          (tester) async {
            useTextScaleFactor(tester, 2.0);
            await tester.binding.setSurfaceSize(Size(width, _phoneHeight));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            final repository = _FakeSocialRepository()
              ..invites = const [
                FriendInvite(
                  id: 'inv-1',
                  expiresAt: '2026-09-01T12:00:00Z',
                  createdAt: '2026-08-01T00:00:00Z',
                ),
              ];

            await expectNoLayoutErrors(() async {
              await _pumpAtRoot(
                tester,
                _friendsScreen(repository, _FakeAuthRepository()),
                locale,
              );
              // At textScale 2.0 the invite row sits below the fold of this
              // phone-height viewport; scroll it in so the tap lands on it
              // rather than outside the surface.
              await tester.scrollUntilVisible(
                find.byKey(const Key('invite-revoke-inv-1')),
                200,
              );
              // `scrollUntilVisible` stops as soon as the row is *built*,
              // which the cache extent makes true while it is still below
              // the fold — and the empty-state guide above it is now a full
              // guide, so that gap is wider than it was.
              await tester.ensureVisible(
                find.byKey(const Key('invite-revoke-inv-1')),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
              await tester.pumpAndSettle();
            });

            final loc = lookupAppLocalizations(locale);
            expect(find.text(loc.friendsRevokeConfirmTitle), findsOneWidget);

            final cancelRect = tester.getRect(find.byKey(const Key('friends-revoke-cancel')));
            final confirmRect = tester.getRect(find.byKey(const Key('friends-revoke-confirm')));
            expect(cancelRect.bottom, lessThanOrEqualTo(_phoneHeight));
            expect(confirmRect.bottom, lessThanOrEqualTo(_phoneHeight));

            // Reachable, not merely within bounds: tapping closes the dialog.
            await tester.tap(find.byKey(const Key('friends-revoke-confirm')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('friends-revoke-confirm')), findsNothing);
          },
        );
      }
    }
  });
}
