/// The router locations that are *not* a real screen: the auth-bootstrap
/// transitions and the sign-in gates.
///
/// Single source of truth — both `resolveAuthRedirect` (which routes to them)
/// and `PendingDeepLinkController` (which refuses to consume a hand-over on
/// them, design.md D6 gate 2) read these, so adding or renaming a gate can't
/// silently update only one of the two.
const splashLocation = '/splash';
const authErrorLocation = '/auth-error';
const loginLocation = '/login';
const registerLocation = '/register';

bool isTransientLocation(String loc) =>
    loc == splashLocation || loc == authErrorLocation;

bool isAuthGateLocation(String loc) =>
    loc == loginLocation || loc == registerLocation;
