/// The app's two shapes for "there is nothing here", and nothing else.
///
/// Before this file the app said "empty" in twenty-odd places with five
/// different shapes, five title styles, three spacings and two icon sizes,
/// and no site recorded why it differed from the one next to it. The two
/// shapes here are chosen by **what the empty region is**, not by what it
/// happens to look like today:
///
/// * [EmptyStateGuide] — a screen or tab with nothing on it. It has room to
///   explain, so it does: which kind of empty (the icon), what this place is
///   (the title), what to do (the body and the actions).
/// * [EmptyStateNote] — an empty region *inside* a populated screen. One
///   muted line, because a full guide dropped into a card interior reads as
///   a page that has taken over the middle of another page.
///
/// Neither is for a control that is merely *shown when* a region is empty
/// but exists to be acted on — the care-today summary card's setup banner is
/// a tap target, and turning it into an explanation would delete the thing
/// it is for.
///
/// Loading and failure are different states with their own widgets
/// (`CardLoading`, `CardErrorRetry`, `AsyncStateScaffold`); neither shape
/// here is for them.
library;

import 'package:flutter/material.dart';

/// Tier 1 — the full guide, for a screen or tab that has nothing to show.
///
/// A **bare `Column`**, deliberately: the shape it generalises
/// (`food_search`'s `_ResultsMessage`) wrapped itself in a
/// `SingleChildScrollView`, and most of the sites adopting it are direct
/// `ListView` children or sit inside a `LedgeCard` — a nested vertical
/// viewport there is handed an unbounded height and asserts. **Scrolling,
/// and padding, stay at the call site**, which is also the only place that
/// knows whether its box is bounded.
///
/// The [icon] comes from the call site because it is the part that says
/// *which kind* of empty — nothing found, nothing scheduled yet, nothing
/// favourited — and a shared widget cannot guess that.
class EmptyStateGuide extends StatelessWidget {
  /// Identifies the whole guide to the screen's tests. Sits on the column,
  /// which is the node the pre-existing per-screen empty states carried it
  /// on, so a `find.descendant(of: byKey(...))` still spans the same subtree.
  final Key stateKey;

  final IconData icon;
  final String title;

  /// The second line, when the title alone doesn't say what to do next.
  final String? body;

  /// Finished controls, rendered in order, 16 below the text and 8 apart.
  ///
  /// **What goes in here: buttons.** The guide styles nothing it is handed —
  /// it neither wraps an action nor gives it a shape — so each one arrives
  /// ready to render and to be tapped. Give the first move a `FilledButton`
  /// and every other action an `OutlinedButton` or a `TextButton`; the guide
  /// draws no distinction between them, so **the call site owns the
  /// emphasis** (`split_tab` and `care_history` are the worked examples). A
  /// bare `Text` here is a bug: it reads as a button, does nothing when
  /// tapped, and is not reachable by keyboard or screen reader.
  ///
  /// A list rather than a primary/secondary pair: `care_history` shows two
  /// (widen the period / go to care management) and `split_tab` shows three
  /// (add a friend / record an expense / create a group), and a pair cannot
  /// express three. A list covers 0, 1, 2 and 3 without a third shape and
  /// without a call site having to smuggle two buttons into one slot.
  final List<Widget> actions;

  const EmptyStateGuide({
    super.key,
    required this.stateKey,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: stateKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        for (var i = 0; i < actions.length; i++) ...[
          SizedBox(height: i == 0 ? 16 : 8),
          actions[i],
        ],
      ],
    );
  }
}

/// Tier 2 — one muted, centred line, for an empty region inside a card or
/// section of an otherwise populated screen.
///
/// Three lines of code, and worth a widget anyway: of the ten sites this
/// tier covers, nine were already this shape — and of those, four had
/// forgotten the muted colour and seven the centring. Nothing but a shared
/// widget stops the eleventh from forgetting too, and this is the one place
/// to check the `onSurfaceVariant` contrast.
///
/// It has no action slot. A card is still free to put a button *next to* the
/// note — `budget_card` and `goal_card` do — but the button is the card's,
/// not part of how the emptiness is explained; folding it in here would make
/// the two tiers differ by more than the size of the region.
class EmptyStateNote extends StatelessWidget {
  /// Optional because not every site has one: `today_screen`'s per-meal note
  /// is located by its text, and inventing a key for it would be a change no
  /// test asked for.
  final Key? stateKey;

  final String text;

  const EmptyStateNote({super.key, this.stateKey, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      key: stateKey,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
