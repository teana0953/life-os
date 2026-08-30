import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_screen.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_screen.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_screen.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';
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

/// A signed-in [AuthRepository] whose id token can be rotated mid-test. This
/// is the real Firebase behaviour the hand-over reload has to survive:
/// `authStateChanges` does **not** fire when the ID token is renewed, so a
/// token captured at the last auth event is stale within the hour — exactly
/// the "tapped the next morning" case the reload exists for.
class _RotatingTokenAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  String token = 'stale-token';

  @override
  Future<String?> idToken() async => token;

  @override
  Stream<bool> get authStateChanges => Stream<bool>.value(true);

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

/// A care-today backend whose one slot is already `done` (in the Done
/// group, editable) from the first read, and whose `getCount` still counts
/// every read — so a test can open the edit sheet without a mark step and
/// still tell a reload from a no-op.
class _DoneCareTodayRepository implements CareTodayRepository {
  int getCount = 0;

  @override
  Future<CareToday> getToday(String idToken) async {
    getCount++;
    return CareToday(
      date: '2026-07-27',
      slots: [
        CareTodaySlot(
          careItemId: 'item-1',
          careScheduleId: 'sched-1',
          category: CareCategory.medication,
          title: '藥',
          timeOfDay: '08:00',
          localDate: '2026-07-27',
          status: CareTodayStatus.done,
          doseQuantity: 1,
        ),
      ],
    );
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {}
}

/// A care-today backend whose checklist *changes* between reads: each
/// `getToday` returns a differently-titled slot, so a test can tell a real
/// reload from a stale screen (the cross-day symptom: yesterday's list still
/// showing after a new reminder is tapped).
class _ChangingCareTodayRepository implements CareTodayRepository {
  int getCount = 0;

  /// The id token each `getToday` was called with, in order.
  final tokens = <String>[];

  /// Thrown by (and cleared on) the next `getToday` — lets a test fail the
  /// hand-over's reload only, after the screen has already rendered a list.
  Object? failNext;

  @override
  Future<CareToday> getToday(String idToken) async {
    tokens.add(idToken);
    if (failNext != null) {
      final error = failNext!;
      failNext = null;
      throw error;
    }
    getCount++;
    return CareToday(
      date: '2026-07-27',
      slots: [
        CareTodaySlot(
          careItemId: 'item-1',
          careScheduleId: 'sched-1',
          category: CareCategory.medication,
          title: '藥 #$getCount',
          timeOfDay: '08:00',
          localDate: '2026-07-27',
          status: CareTodayStatus.pending,
          doseQuantity: 1,
        ),
      ],
    );
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {}
}

class _FakeCareHistoryRepository implements CareHistoryRepository {
  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async => const [];

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  }) async {}
}


/// A care-today backend whose `getToday` **never settles** — the shape a
/// Workers/Neon stall actually has on the wire (the request is accepted and
/// no response ever comes), and the one that leaves a screen on a spinner.
///
/// Deliberately not "throws immediately": a zero-latency fake settles before
/// the first pump, so the window this guard has to observe would already be
/// closed and the test would pass without the fix.
class _StallingCareTodayRepository implements CareTodayRepository {
  /// How many requests were actually issued. The second hand-over's whole
  /// point is that it issues another one; counting is the only way to tell a
  /// re-request from a silently dropped call.
  int getCount = 0;

  final _never = Completer<CareToday>();

  @override
  Future<CareToday> getToday(String idToken) {
    getCount++;
    return _never.future;
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {}
}

/// Drives frames without `pumpAndSettle`, which cannot be used while a
/// spinner is on screen: its animation never quiesces, so `pumpAndSettle`
/// would fail with a timeout instead of the assertion under test.
Future<void> _pumpFrames(
  WidgetTester tester, [
  Duration step = const Duration(milliseconds: 20),
  int frames = 12,
]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// A popup route that DECLINES to be dismissed: returning `false` from
/// `didPop` is how a Flutter route refuses a pop, and the route stays on the
/// stack (`_RouteEntry.handlePop` puts it straight back to `idle`).
///
/// Deliberately not a `PopScope(canPop: false)` fixture: `_popTo` pops the
/// popup layer with `maybePop` (see `lib/app.dart`), which does consult
/// `PopScope`, so that would work too — but it would only exercise
/// `maybePop`'s own `popDisposition` check, not the loops' own
/// stack-stopped-changing bound, which is what these tests exist to prove.
/// Overriding `didPop` refuses regardless of which pop method is used,
/// isolating the bound itself as the thing under test.
class _RefusingRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  // Deliberately does not call super: `Route.didPop` completes the route and
  // returns true, which is the opposite of the refusal this fixture is.
  @override
  // ignore: must_call_super
  bool didPop(void result) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const Center(child: Text('submitting'));
}

/// A route that refuses to be dismissed via `PopScope(canPop: false)` — the
/// mechanism a real screen uses (`shared_food_item_sheet.dart:401`), unlike
/// `_RefusingRoute` above which overrides `didPop` and so refuses no matter
/// which pop method is called. `PopScope`'s refusal is only consulted by
/// `NavigatorState.maybePop` (and the system back gesture) — `.pop()` (which
/// is what `GoRouter.pop()` resolves to) ignores it outright. So this
/// fixture is what actually distinguishes `_popTo` popping with `maybePop`
/// from popping with `pop`/`GoRouter.pop()`.
class _PopScopeRefusingRoute extends MaterialPageRoute<void> {
  _PopScopeRefusingRoute()
      : super(
          builder: (_) => const PopScope(
            canPop: false,
            child: Center(child: Text('submitting')),
          ),
        );
}

final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
  isAdmin: false,
);

void main() {
  group('App pending deep-link hand-over', () {

    testWidgets(
      'a hand-over this app version cannot match leaves the app on home — no '
      'not-found page, no error, nothing navigated',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        // The service worker that writes a hand-over outlives app updates
        // (design D6b), so the writer and the reader can be different
        // versions: a path one knows and the other does not is the normal
        // case, not a corner one.
        final store = _FakeStore(
          PendingDeepLink(path: '/no-such-route', savedAt: DateTime.now()),
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

        // go_router's untranslated default, which currently replaces the
        // whole app when the hand-over path matches nothing.
        expect(find.text('Page Not Found'), findsNothing);
        // …and not our own localized one either: an unrecognized hand-over is
        // "no hand-over at all", so nothing navigates in the first place.
        expect(find.byKey(const Key('route-error-screen')), findsNothing);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        // Consumed anyway (read-and-delete), so it cannot come back.
        expect(store.taken, isTrue);
      },
    );

    testWidgets(
      'a Today load that never returns ends as a retryable error, not an '
      'endless spinner',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _StallingCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          careTodayRepository: careRepository,
          pendingDeepLinkStore: store,
        );
        await _pumpFrames(tester);

        expect(find.byType(CareTodayScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        // Past any bound a user would wait through.
        await tester.pump(const Duration(seconds: 45));
        await _pumpFrames(tester);

        expect(find.byKey(const Key('care-today-load-error')), findsOneWidget);
        expect(
          find.byKey(const Key('care-today-retry-button')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'tapping the notification again after a stalled load issues a fresh '
      'request instead of being swallowed by the in-flight guard',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _StallingCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          careTodayRepository: careRepository,
          pendingDeepLinkStore: store,
        );
        await _pumpFrames(tester);
        expect(find.byType(CareTodayScreen), findsOneWidget);

        await tester.pump(const Duration(seconds: 45));
        await _pumpFrames(tester);
        final afterTimeout = careRepository.getCount;

        // The user taps the notification a second time to get out of the
        // stuck screen.
        store.fireHandover();
        await _pumpFrames(tester);

        expect(store.takes, greaterThan(1));
        expect(
          careRepository.getCount,
          greaterThan(afterTimeout),
          reason: 'the second tap must send a request, not be discarded',
        );

        // The second request stalls too; let its bound elapse so the test does
        // not end with that timer still pending.
        await tester.pump(const Duration(seconds: 45));
        await _pumpFrames(tester);
      },
    );

    testWidgets(
      'eight hand-overs with alternating destinations still take a single '
      'back to return to the screen the user was on',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _ChangingCareTodayRepository();
        final store = _RepeatingFakeStore([
          for (var i = 0; i < 8; i++)
            PendingDeepLink(
              path: i.isEven ? '/care-today' : '/care-history',
              savedAt: DateTime.now(),
            ),
        ]);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          careTodayRepository: careRepository,
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CareTodayScreen), findsOneWidget);

        for (var i = 1; i < 8; i++) {
          store.fireHandover();
          await tester.pumpAndSettle();
        }
        expect(store.takes, 8);
        expect(find.byType(CareHistoryScreen), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
          reason: 'one back must return to the screen before the first tap',
        );
      },
    );

    testWidgets(
      'a hand-over destination sitting below the top of the stack (not just '
      'one below it) is popped down to, past a screen the user opened '
      'themselves',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final store = _RepeatingFakeStore([
          PendingDeepLink(path: '/care-today', savedAt: DateTime.now()),
          PendingDeepLink(path: '/care-history', savedAt: DateTime.now()),
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

        // The user opens 照護項目 themselves — not a hand-over, so
        // `_lastHandoverPush` still names 今日照護. Stack is now
        // [home, 今日照護, 照護項目].
        await tester.tap(find.byKey(const Key('care-today-empty-manage-button')));
        await tester.pumpAndSettle();
        expect(find.byType(CareItemsScreen), findsOneWidget);

        // A hand-over for 照護歷史 arrives: `_lastHandoverPush` (今日照護) is
        // still on the stack but not on top, so it is popped to first, then
        // replaced. Stack becomes [home, 照護歷史].
        store.fireHandover();
        await tester.pumpAndSettle();
        expect(find.byType(CareHistoryScreen), findsOneWidget);
        expect(find.byType(CareItemsScreen), findsNothing);

        // A second hand-over for 今日照護 arrives while the stack is only
        // [home, 照護歷史] — 今日照護 isn't on the stack at all here, so this
        // pushes rather than pops. What this test guards is the *previous*
        // step: that popping past a self-opened screen (照護項目) that sits
        // below the hand-over's own last destination actually happens,
        // rather than `_popTo` only ever finding a match one below the top.
        store.fireHandover();
        await tester.pumpAndSettle();
        expect(find.byType(CareTodayScreen), findsOneWidget);
        expect(store.takes, 3);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
          reason: 'one back must return to home, not to 照護項目',
        );
      },
    );

    testWidgets(
      'a hand-over to the destination already on top of the stack still '
      'closes a bottom sheet the user had open over it',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _DoneCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          careTodayRepository: careRepository,
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CareTodayScreen), findsOneWidget);

        // Expand the Done group, then open its edit sheet — a `PopupRoute`
        // on the same Navigator, not a GoRoute, so it does not change
        // `matches`. Stack (declarative) is still just [home, 今日照護]; the
        // sheet sits on top of it outside that list.
        await tester.tap(find.byKey(const Key('care-today-done-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('care-today-row-sched-1-2026-07-27-08:00')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('care-today-edit-sheet-title')), findsOneWidget);

        // A second hand-over for 今日照護 arrives while it is already the
        // topmost *page*. `_popTo`'s length-based loop alone would never
        // run here (matches.length already equals targetDepth), leaving the
        // sheet open over a screen the controller believes it just quietly
        // reloaded — this is the regression this test guards.
        store.fireHandover();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('care-today-edit-sheet-title')),
          findsNothing,
          reason: 'the hand-over must close the sheet sitting over the '
              'destination, not leave it covering the reloaded screen',
        );
        expect(find.byType(CareTodayScreen), findsOneWidget);
        expect(
          careRepository.getCount,
          greaterThan(1),
          reason: 'the destination was already showing, so this must be a '
              'reload, not a no-op',
        );
      },
    );

    testWidgets(
      'a foreground signal with nothing pending still runs the foreground '
      'effect, and the screen stays tappable (issue #226: the signal used to '
      'die in the hand-over gates, leaving nothing to restore the engine\'s '
      'foreground lifecycle)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        // Empty: `take()` answers null, so every gate after the store read is
        // reached with nothing to act on — the reported case exactly.
        final store = _RepeatingFakeStore([]);
        var foregrounded = 0;
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          pendingDeepLinkStore: store,
          onForegrounded: () => foregrounded++,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        expect(
          foregrounded,
          0,
          reason: 'start()-time is not a foregrounding',
        );

        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(0));
        expect(foregrounded, 1);

        // What `foregrounded == 1` above proves, and all it proves: the
        // composition root wires the foreground seam and a worker signal
        // reaches it. It says nothing about the freeze itself.
        //
        // The real effect is `restoreForegroundLifecycle()`, which dispatches
        // a synthetic `visibilitychange` on `document` and `focus` on
        // `window` so Flutter web's `_BrowserAppLifecycleState` leaves
        // `hidden`. It lives in `pending_deep_link_web.dart` behind a
        // `dart.library.js_interop` conditional import, so this VM test
        // compiles the stub instead and executes no line of it — not the
        // dispatch, not the `isTrusted` guard, not the `visibilityState ==
        // 'visible'` precondition (design D6). A test here that claimed
        // otherwise could not fail.
        //
        // The tap below is likewise not a repaint guard, for a second and
        // independent reason: `flutter_test`'s binding services a frame on
        // every `pump`/`tap` whether or not any lifecycle state was restored,
        // so it stays green against a completely frozen engine. It is a smoke
        // check that navigation still works after the hand-over path runs.
        //
        // A green run of this file therefore means "the seam is wired", never
        // "the freeze is fixed". Only tasks.md section 4 — a reinstalled
        // WebAPK, a real push, and three further interactions after the tap —
        // can say the latter.
        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('health-tile')), findsNothing);
      },
    );

    testWidgets(
      'a hand-over arriving under a screen that refuses to be dismissed '
      'leaves the app usable instead of spinning forever on the UI thread '
      '(issue #226 H1)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _ChangingCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          careTodayRepository: careRepository,
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CareTodayScreen), findsOneWidget);

        // A route that refuses to be dismissed. Before the fix this test does
        // not fail — it HANGS, because both of `_popTo`'s loops assume every
        // pop removes a route, and a spinning loop on the UI thread never
        // yields to the test's own timeout.
        final context = tester.element(find.byType(CareTodayScreen));
        unawaited(
          Navigator.of(context, rootNavigator: true).push(_RefusingRoute()),
        );
        await tester.pumpAndSettle();
        expect(find.text('submitting'), findsOneWidget);

        final getCountBeforeHandover = careRepository.getCount;
        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(1));
        expect(
          find.text('submitting'),
          findsOneWidget,
          reason: 'a screen that declines to be dismissed costs the user an '
              'unchanged screen, never a frozen app',
        );
        expect(
          careRepository.getCount,
          getCountBeforeHandover,
          reason: 'the destination is still covered by the refusing route, '
              'so it was never uncovered — reloading a screen the user '
              'cannot see is silent wasted work at best (Finding A)',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a hand-over destination is still bound even when a refusing route '
      'sits above it rather than directly on top of it (issue #226 H1: the '
      'matches.length loop, not just the popup loop, needs its own '
      'no-progress bound)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        // Two entries: the first is what `start()` consumes to land on
        // 今日照護 in the first place (`_RepeatingFakeStore` only serves each
        // entry once — despite the name — so without a second one here the
        // later `fireHandover()` below would find nothing pending and never
        // call `_navigateToHandover` at all).
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

        // Destination is `/care-today` (index 1), but `CareItemsScreen`
        // (index 2) is what's on top — the destination is two matches deep,
        // not the topmost one, so the `matches.length` loop (not the popup
        // loop) is what has to unwind it. (Default care-today fake data is
        // empty, which is what puts the manage button on screen.)
        await tester.tap(
          find.byKey(const Key('care-today-empty-manage-button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CareItemsScreen), findsOneWidget);

        // A refusing route above that: the popup loop's own attempt to
        // clear it fails and breaks after one try, leaving it on top when
        // the `matches.length` loop runs. Before its `movedNothing` break
        // existed, that loop called `_router.pop()` in a cycle nothing ever
        // interrupts — the popup route refuses every time, so neither the
        // depth nor the top route ever changes.
        final context = tester.element(find.byType(CareItemsScreen));
        unawaited(
          Navigator.of(context, rootNavigator: true).push(_RefusingRoute()),
        );
        await tester.pumpAndSettle();
        expect(find.text('submitting'), findsOneWidget);

        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(1));
        expect(
          find.text('submitting'),
          findsOneWidget,
          reason: 'a route that refuses to be dismissed, sitting above (not '
              'on) the destination, must still leave the app usable rather '
              'than spinning forever trying to reach a destination it '
              'cannot uncover',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a hand-over whose destination is not in the stack at all still does '
      'not stack a fresh copy of it on top of a route that refuses to be '
      'dismissed (Finding A applies even when _popTo would otherwise '
      'return null, not just false)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        // Starts empty so the app settles on home with no hand-over yet —
        // `_lastHandoverPush` stays null, isolating `_popTo`'s own `index <
        // 0` branch from the separate `previous`-branch fix in
        // `_navigateToHandover`, which would otherwise mask this bug (a
        // refused pop of `previous` already returns `false` there).
        final entries = <PendingDeepLink>[];
        final store = _RepeatingFakeStore(entries);
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
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );

        // A route that refuses to be dismissed, directly on top of home.
        final context = tester.element(
          find.byKey(const Key('health-dashboard-section')),
        );
        unawaited(
          Navigator.of(context, rootNavigator: true).push(_RefusingRoute()),
        );
        await tester.pumpAndSettle();
        expect(find.text('submitting'), findsOneWidget);

        // Only now does a hand-over arrive, for a destination that was never
        // in the stack — so `_popTo` hits `index < 0`, not a blocked pop of
        // a match it found.
        entries.add(
          PendingDeepLink(path: '/care-history', savedAt: DateTime.now()),
        );
        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(0));
        expect(
          find.byType(CareHistoryScreen),
          findsNothing,
          reason: 'the destination must not be pushed on top of a route '
              'that is still refusing to close, even though that '
              'destination was never in the stack to begin with',
        );
        expect(
          find.text('submitting'),
          findsOneWidget,
          reason: 'the refusing route must still be the one on top — '
              'nothing was pushed over it',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a hand-over does not force-close a PopScope(canPop: false) route '
      'sitting above a destination that is not the top of the stack (the '
      'matches.length loop must pop with maybePop, not GoRouter.pop, or it '
      'silently defeats the guard instead of terminating)',
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

        // Destination is `/care-today` (index 1); `CareItemsScreen` is on
        // top of it — so unwinding to the destination is the
        // `matches.length` loop's job, not the popup loop's (which only
        // ever looks at what's directly on top before that loop starts).
        await tester.tap(
          find.byKey(const Key('care-today-empty-manage-button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CareItemsScreen), findsOneWidget);

        // A route that refuses via `PopScope`, not `didPop` — the only
        // fixture that can tell `maybePop` apart from `GoRouter.pop()`.
        final context = tester.element(find.byType(CareItemsScreen));
        unawaited(
          Navigator.of(
            context,
            rootNavigator: true,
          ).push(_PopScopeRefusingRoute()),
        );
        await tester.pumpAndSettle();
        expect(find.text('submitting'), findsOneWidget);

        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(1));
        expect(
          find.text('submitting'),
          findsOneWidget,
          reason: 'GoRouter.pop() resolves to NavigatorState.pop(), which '
              'ignores PopScope.canPop outright — using it here would force '
              'the route closed instead of stopping at its refusal, losing '
              'exactly the in-flight state the guard exists to protect',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a hand-over destination two screens down is still unwound to (the '
      'bound stops when the stack stops changing, not after one pop)',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final store = _RepeatingFakeStore([
          PendingDeepLink(path: '/care-today', savedAt: DateTime.now()),
          // Home itself: the only destination this app has with TWO ordinary
          // dismissible screens above it, which is what tells a real bound
          // apart from one that stops after a single pop.
          PendingDeepLink(path: '/', savedAt: DateTime.now()),
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

        await tester.tap(
          find.byKey(const Key('care-today-empty-manage-button')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CareItemsScreen), findsOneWidget);

        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(1));
        expect(find.byType(CareItemsScreen), findsNothing);
        expect(find.byType(CareTodayScreen), findsNothing);
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a fresh pending deep link pushes 今日照護 over the home screen '
        '(push, not go: the home screen is still beneath it)', (tester) async {
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

      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
      expect(find.byType(CareTodayScreen), findsNothing);
    });

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

      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
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
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
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

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a second hand-over while already on 今日照護 does not stack a second '
      'copy (one pageBack returns home, not two) but does reload the list',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _ChangingCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();

        expect(find.byType(CareTodayScreen), findsOneWidget);
        expect(find.text('藥 #1'), findsOneWidget);

        // A second hand-over arrives (e.g. a second care reminder tapped)
        // while 今日照護 is already open; it targets the same route.
        store.fireHandover();
        await tester.pumpAndSettle();

        // The second hand-over must actually have been read — otherwise this
        // test would pass simply because the signal never arrived, which is
        // the failure mode it exists to catch.
        expect(store.takes, greaterThan(1));
        expect(find.byType(CareTodayScreen), findsOneWidget);
        // …and the screen the user is looking at was re-fetched, rather than
        // left showing what it loaded when it first opened.
        expect(find.text('藥 #2'), findsOneWidget);
        expect(find.text('藥 #1'), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        expect(find.byType(CareTodayScreen), findsNothing);
      },
    );

    testWidgets(
      'the reload a hand-over triggers fetches a fresh id token rather than '
      'reusing the one captured at the last auth event (which never renews)',
      (tester) async {
        final authRepository = _RotatingTokenAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _ChangingCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();

        expect(find.byType(CareTodayScreen), findsOneWidget);

        // Overnight: Firebase renews the ID token without emitting an auth
        // state change, so anything still holding the old snapshot would send
        // an expired token and be bounced to the re-auth screen.
        authRepository.token = 'fresh-token';

        store.fireHandover();
        await tester.pumpAndSettle();

        expect(careRepository.tokens.last, 'fresh-token');
        expect(find.byType(CareTodayScreen), findsOneWidget);
      },
    );

    testWidgets(
      'a hand-over whose reload fails leaves the checklist on screen — no '
      'error screen over a list that was rendering fine',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        final careRepository = _ChangingCareTodayRepository();
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
          careTodayController: CareTodayController(
            GetCareToday(careRepository),
            MarkCareDone(careRepository),
            MarkCareSkipped(careRepository),
            EditCareSlot(_FakeCareHistoryRepository()),
          ),
          pendingDeepLinkStore: store,
        );
        await tester.pumpAndSettle();

        expect(find.text('藥 #1'), findsOneWidget);

        // The network drops just as a second reminder is tapped.
        careRepository.failNext = const CareRequestFailed();
        store.fireHandover();
        await tester.pumpAndSettle();

        expect(store.takes, greaterThan(1));
        expect(find.text('藥 #1'), findsOneWidget);
        expect(find.byKey(const Key('care-today-load-error')), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });
}
