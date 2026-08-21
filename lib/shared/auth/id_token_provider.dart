import '../../contexts/auth/domain/auth_repository.dart';
import '../config.dart';

/// Resolves the current auth ID token **at the moment of the call**.
///
/// Screens take one of these instead of a `String` captured when they were
/// built: a Firebase ID token lives one hour, so a PWA left open (or resumed
/// from the background) past that would otherwise send a dead token on every
/// write. `getIdToken()` renews the token when it is close to expiry, so
/// resolving at the point of use removes staleness with no subscription and
/// no rebuild.
///
/// A plain function typedef rather than a named class: the 70-odd call sites
/// read as `await widget.idToken()`, and the ~35 construction sites can pass a
/// closure directly instead of wrapping one in an object.
///
/// **Never** satisfy this with a closure over an already-resolved token
/// (`() async => _token!`) — that compiles and reads cleanly while preserving
/// exactly the staleness this type exists to remove. Each call must go back to
/// the auth repository.
///
/// Signed out resolves to `''` (the pre-existing `?? ''` semantics): the
/// request goes out unauthenticated and the backend's 401 drives the existing
/// re-auth exit.
///
/// **An implementation must not let a failed renewal throw.** `getIdToken()`
/// goes to the network once the token nears expiry and throws when that fails;
/// a throw here escapes before the controller is entered, so no controller's
/// error handling runs and the user's action disappears with neither a write
/// nor a message. Resolve to `''` instead and let the 401 path handle it —
/// see `_AppState._idToken`.
typedef IdTokenProvider = Future<String> Function();

/// The one correct way to build an [IdTokenProvider] from an [AuthRepository].
///
/// Every screen that owns its own provider must delegate here rather than
/// writing `await repository.idToken() ?? ''` inline. That inline form is what
/// this exists to stop being copied: it looks complete, and it throws.
///
/// `idToken()` goes to the network once the token nears expiry, and a failed
/// renewal **throws**. Thrown from a provider, it escapes the tap handler
/// before any controller is entered — so no controller's error handling runs,
/// no state is set, and the user's action disappears with neither a write nor
/// a message. (On a sheet that sets a `_saving` flag before awaiting, it also
/// latches the submit button off for good.)
///
/// Resolving to `''` instead reproduces the behaviour this app had before the
/// token moved to the call sites: the request goes out unauthenticated, the
/// backend answers 401, and the existing re-auth exit takes over. A transport
/// failure is *not* turned into a sign-out — controllers already separate a
/// real HTTP 401 (`ReauthenticationRequired`) from an offline/transport error
/// (the retryable error state).
Future<String> guardedIdToken(AuthRepository repository) async {
  try {
    // Bounded, not just guarded: `idToken()` goes to the network near expiry,
    // and a *hung* renewal is not a throw — it is silence. Every screen awaits
    // this before entering any controller, so an unbounded wait here is a
    // screen frozen on its initial spinner with no controller state to show an
    // error from (issue #193). Timing out resolves to `''` like every other
    // failure: the request goes out unauthenticated and the 401 path takes
    // over, which is an exit the user can act on.
    return await repository.idToken().timeout(httpRequestTimeout) ?? '';
  } catch (_) {
    return '';
  }
}
