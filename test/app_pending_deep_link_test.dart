import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_screen.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/shared/pwa/pending_deep_link.dart';

import 'app_test.dart';

/// A fake [PendingDeepLinkStore] holding at most one queued entry — [take]
/// consumes it exactly once, mirroring the real store's contract.
class _FakeStore implements PendingDeepLinkStore {
  _FakeStore([this._entry]);

  PendingDeepLink? _entry;
  bool taken = false;

  @override
  Future<PendingDeepLink?> take() async {
    taken = true;
    final result = _entry;
    _entry = null;
    return result;
  }

  @override
  Stream<void> get handoverSignals => const Stream.empty();
}

/// A [PendingDeepLinkStore] whose [take] always throws, simulating a broken
/// Cache read (design.md: "a failed hand-over is silent").
class _ThrowingStore implements PendingDeepLinkStore {
  const _ThrowingStore();

  @override
  Future<PendingDeepLink?> take() async => throw StateError('cache boom');

  @override
  Stream<void> get handoverSignals => const Stream.empty();
}

/// A [PendingDeepLinkStore] that can hand over more than one entry (queued in
/// order, one per [take]) and whose [handoverSignals] the test fires on
/// demand via [fireHandover] — needed to reproduce a *second* hand-over
/// arriving while the app is already on the destination screen, which
/// `_FakeStore` (single entry, `Stream.empty()`) can never exercise.
class _RepeatingFakeStore implements PendingDeepLinkStore {
  _RepeatingFakeStore(this._entries);

  final List<PendingDeepLink> _entries;
  int _index = 0;
  final _signals = StreamController<void>.broadcast();

  /// How many times the app actually read the store. Asserted so that a
  /// broken signal path can't leave the dedupe test passing for the wrong
  /// reason — it would otherwise stay green while never delivering the second
  /// hand-over at all.
  int takes = 0;

  @override
  Future<PendingDeepLink?> take() async {
    takes++;
    if (_index >= _entries.length) return null;
    return _entries[_index++];
  }

  @override
  Stream<void> get handoverSignals => _signals.stream;

  void fireHandover() => _signals.add(null);
}

final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
);

void main() {
  group('App pending deep-link hand-over', () {
    testWidgets(
      'a fresh pending deep link pushes 今日照護 over the home screen '
      '(push, not go: the home screen is still beneath it)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final store = _FakeStore(
          PendingDeepLink(path: '/care-today', savedAt: DateTime.now()),
        );
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();

        expect(find.byType(CareTodayScreen), findsOneWidget);
        final context = tester.element(find.byType(CareTodayScreen));
        expect(Navigator.canPop(context), isTrue);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('spaces-grid')), findsOneWidget);
        expect(find.byType(CareTodayScreen), findsNothing);
      },
    );

    testWidgets('an expired pending deep link leaves the app on home', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
      final profileRepository = FakeProfileRepository(_testProfile);
      final store = _FakeStore(
        PendingDeepLink(
          path: '/care-today',
          savedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      );
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
        pendingDeepLinkStore: store,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('spaces-grid')), findsOneWidget);
      expect(find.byType(CareTodayScreen), findsNothing);
    });

    testWidgets(
      'a store that throws on take() leaves the app on home without an '
      'error surfacing',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          pendingDeepLinkStore: const _ThrowingStore(),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('spaces-grid')), findsOneWidget);
        expect(find.byType(CareTodayScreen), findsNothing);
      },
    );

    testWidgets(
      'tapping a notification while signed out consumes nothing; 今日照護 '
      'opens over home once signed in',
      (tester) async {
        final authRepository = FakeAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        final store = _FakeStore(
          PendingDeepLink(path: '/care-today', savedAt: DateTime.now()),
        );
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('email-field')), findsOneWidget);
        expect(store.taken, isFalse);

        await tester.enterText(
          find.byKey(const Key('email-field')),
          FakeAuthRepository.validEmail,
        );
        await tester.enterText(
          find.byKey(const Key('password-field')),
          FakeAuthRepository.validPassword,
        );
        await tester.tap(find.byKey(const Key('submit-button')));
        await tester.pumpAndSettle();

        expect(find.byType(CareTodayScreen), findsOneWidget);
        final context = tester.element(find.byType(CareTodayScreen));
        expect(Navigator.canPop(context), isTrue);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('spaces-grid')), findsOneWidget);
      },
    );

    testWidgets(
      'a second hand-over while already on 今日照護 does not stack a second '
      'copy (one pageBack returns home, not two)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final store = _RepeatingFakeStore([
          PendingDeepLink(path: '/care-today', savedAt: DateTime.now()),
          PendingDeepLink(path: '/care-today', savedAt: DateTime.now()),
        ]);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();

        expect(find.byType(CareTodayScreen), findsOneWidget);

        // A second hand-over arrives (e.g. a second care reminder tapped)
        // while 今日照護 is already open; it targets the same route.
        store.fireHandover();
        await tester.pumpAndSettle();

        // The second hand-over must actually have been read — otherwise this
        // test would pass simply because the signal never arrived, which is
        // the failure mode it exists to catch.
        expect(store.takes, greaterThan(1));
        expect(find.byType(CareTodayScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('spaces-grid')), findsOneWidget);
        expect(find.byType(CareTodayScreen), findsNothing);
      },
    );
  });
}
