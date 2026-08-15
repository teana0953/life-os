import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// The standard full-screen async-state scaffold shared by the diet-target
/// and water screens: a centered loading spinner while [isLoading], a
/// centered reauth state ([reauthMessage] + a sign-in-again control) while
/// [isReauth], and otherwise the loaded content from [builder].
///
/// [isLoading] takes precedence over [isReauth]. Screen-specific states
/// beyond these two (e.g. a load-failed error) belong inside [builder].
///
/// [appBar] is optional (default `null` → the loading/reauth Scaffolds have no
/// app bar, the original behavior). A full-screen tracker pushed onto the
/// navigation stack passes its app bar so the loading and reauth states keep a
/// back button. **That back button is not what makes reauth escapable** — it
/// was once described that way here, but going back doesn't revive an expired
/// token, so every screen would 401 again. [onSignInAgain] below is the
/// actual exit; the app bar just preserves ordinary navigation.
///
/// [onSignInAgain] is `required`, not optional: making it optional would let
/// "this screen has no way out of reauth" and "this screen doesn't need one"
/// look identical in code, which is exactly the silent dead end this
/// parameter exists to close (see `openspec/changes/archive/2026-08-04-add-reauth-exit`). The
/// control invokes exactly this callback and does no navigation of its own —
/// what happens to the route stack afterwards is the caller's job.
///
/// **D3 (does the caller need to `pop` after signing out?): no.** Verified by
/// `test/app_test.dart`'s "AsyncStateScaffold reauth exit (add-reauth-exit
/// design.md D3)" test: it pushes `DailyTargetScreen` on top of the app root
/// (`context.push('/health/diet/target', …)`), drives it into the reauth
/// state, and wires [onSignInAgain] to a **plain** `signOut()` call with no
/// pop/navigation. Tapping the control still ends on the login screen with
/// the pushed screen (and its sign-in-again button) gone from the tree —
/// `signOut()` flips `AuthRepository.authStateChanges` to `false`,
/// `AuthRouterNotifier` notifies go_router's `refreshListenable`, and the
/// top-level `redirect` (`app.dart`'s `_buildRouter`) replaces the *entire*
/// match list with the login route, discarding the pushed screen along with
/// it. This differs from the pre-go_router architecture CLAUDE.md's
/// "Sign-out-and-close" section describes (there, `MaterialApp.home` swapped
/// under an untouched root `Navigator`, so a pushed route had to be popped
/// explicitly to avoid being stranded on top of a now-stale screen).
///
/// **Scope of that conclusion: go_router's match list only.** Every one of
/// this widget's 15 call sites is reached through a `GoRoute`, so the redirect
/// covers all of them. It does **not** cover routes pushed imperatively onto
/// a `Navigator` outside the router — e.g. `care_items_screen.dart`'s form
/// push, or `SettingsScreen`, whose own post-sign-out pop
/// (`settings_screen.dart`) is still load-bearing. Do not read this as
/// permission to delete those.
class AsyncStateScaffold extends StatelessWidget {
  final bool isLoading;
  final bool isReauth;
  final String? reauthMessage;

  final VoidCallback onSignInAgain;
  final PreferredSizeWidget? appBar;
  final WidgetBuilder builder;

  const AsyncStateScaffold({
    super.key,
    required this.isLoading,
    required this.isReauth,
    this.reauthMessage,
    required this.onSignInAgain,
    this.appBar,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (isReauth) {
      // The button's label is looked up here rather than passed in, matching
      // `card_error_retry.dart` — the repo's other caller-message + fixed-action
      // widget, which takes `message` from the caller and reads `loc.retry`
      // itself. [reauthMessage] stays caller-supplied because it predates this
      // change, not because the two are meant to differ.
      final loc = AppLocalizations.of(context)!;
      return Scaffold(
        appBar: appBar,
        // Centred when it fits, scrollable when it doesn't. This branch grew
        // from a bare `Text` (which could not overflow) into text + button,
        // and at large text scales on a short viewport the button lands below
        // the fold — present but not hittable, which is the same dead end
        // this widget's `onSignInAgain` exists to close. The `minHeight`
        // keeps the normal case vertically centred rather than top-aligned,
        // which a plain `SingleChildScrollView` would have changed.
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(reauthMessage ?? '', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('async-state-reauth-sign-in-button'),
                        onPressed: onSignInAgain,
                        child: Text(loc.signInAgain),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return builder(context);
  }
}
