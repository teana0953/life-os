import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Presents the assistant as a panel anchored to the bottom of the screen
/// with the screen it was opened from left showing above it.
///
/// **Why not `showModalBottomSheet`.** A modal sheet is not a route: the URL
/// would not change, a web refresh would lose the conversation, and the
/// browser/Android back button would leave the *shell* instead of closing the
/// assistant. All three already work today because `/assistant` is a real
/// route, and this keeps them — it changes only how that route paints, by
/// being non-opaque (see `app.dart`'s `CustomTransitionPage`), so the route
/// underneath stays visible behind the panel.
///
/// **The gap is deliberately empty.** Nothing is drawn in it and nothing
/// handles taps there, so a tap falls through to the route's own modal
/// barrier and dismisses — which is also what gives a screen-reader user the
/// standard "dismiss" affordance without a bespoke button.
class AssistantSheetPage extends StatelessWidget {
  /// The assistant itself. Kept a plain child rather than built here: this
  /// widget is presentation only and must not know what it is framing.
  final Widget child;

  const AssistantSheetPage({super.key, required this.child});

  /// The widest the panel gets. On a phone it never binds; on a desktop
  /// window it stops the panel from stretching into a letterbox.
  static const double _maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    // There is always something underneath to show through. This used to
    // carry a `if (!Navigator.of(context).canPop()) return child;` escape for
    // a deep link or a web refresh landing straight on `/assistant` with an
    // empty navigator below — framing a gap over nothing would have been a
    // strip of nothing. `/assistant` is now a CHILD of `/` (app.dart), so a
    // URL-driven rebuild always puts home in the stack first and that case no
    // longer exists; the sole construction site is that one route.
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;
    // Proportional, with a cap: a fixed inset is most of a short phone's
    // screen at the small end, and a pointless waste at the large one.
    //
    // Floored to the status-bar/notch inset plus a margin: the proportional
    // value alone is measured from the physical top of the screen, so on a
    // phone with a tall safe-area inset the status bar alone could eat
    // nearly all of it, leaving a sliver too thin to read as "home showing
    // through" (caught in review — a plain `min(72, height * 0.12)` left as
    // little as ~13px visible on a notched phone).
    final gap = math.max(math.min(72.0, height * 0.12), topPadding + 16);

    return Column(
      children: [
        SizedBox(key: const Key('assistant-sheet-gap'), height: gap),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Container(
                // Flush to the bottom of the screen, not inset: the framed
                // child's own `Scaffold` lifts the composer by
                // `MediaQuery.viewInsets.bottom`, a measurement taken from
                // the *screen's* bottom edge. Flush, that inset is exactly
                // the keyboard's height. Float the panel instead and the
                // inset would still be measured from the screen's bottom —
                // the composer would clear the keyboard but by more than
                // needed, wasting vertical space for no benefit.
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                // The framed child brings its own `Scaffold`, whose square
                // background would paint over the rounded corners.
                clipBehavior: Clip.antiAlias,
                // Deliberately no grab handle. A handle is the bottom-sheet
                // convention for *drag to dismiss*, and this panel has no
                // drag gesture — drawing one would promise a pull that does
                // nothing. The two real exits are the framed `Scaffold`'s own
                // AppBar back button (present because this route can pop) and
                // a tap in the gap above.
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
