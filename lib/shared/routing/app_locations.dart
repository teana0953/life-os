/// The router locations that are *not* a real screen: the auth-bootstrap
/// transitions and the sign-in gates.
///
/// Single source of truth — the `GoRoute` declarations, `resolveAuthRedirect`
/// (which routes to them), and `PendingDeepLinkController` (which refuses to
/// consume a hand-over on them, design.md D6 gate 2) all read these. Renaming
/// a gate here therefore moves the route and both guards together; leaving the
/// route paths as literals would let a rename update the guards alone, and a
/// guard that no longer matches its route stacks 今日照護 on top of the sign-in
/// screen with no test going red.
const splashLocation = '/splash';
const authErrorLocation = '/auth-error';
const loginLocation = '/login';
const registerLocation = '/register';
const passwordResetLocation = '/reset-password';

bool isTransientLocation(String loc) =>
    loc == splashLocation || loc == authErrorLocation;

bool isAuthGateLocation(String loc) =>
    loc == loginLocation || loc == registerLocation || loc == passwordResetLocation;
