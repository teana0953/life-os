import 'package:flutter/material.dart';

/// Opens a modal bottom sheet with the three options every form sheet in
/// this app needs, so the reasoning behind them lives here instead of being
/// restated at each call site:
///
/// - `isScrollControlled: true` — an uncontrolled sheet is capped at 9/16 of
///   the screen height, which has clipped a submit button off the bottom.
/// - `showDragHandle: true` — the handle sits outside the sheet's scrollable
///   content, so a pull-down on it always closes the sheet. Without it, a
///   tall sheet fills the viewport, the scrim disappears, and the drag is
///   swallowed by the content's own scrolling — leaving the browser back
///   button as the only exit, which on the PWA unwinds the router stack to
///   the home screen (PR #115). It also gives a screen-reader user a dismiss
///   affordance inside the sheet's own semantics — the scrim and the
///   system-back gesture are not discoverable by scanning the content. (Not
///   a keyboard affordance: Flutter's `_DragHandle` is a `Semantics(button)`
///   tap target with no focus node.) Sheets whose content already ends in a
///   Cancel button have one either way; the handle is the fallback for those
///   that don't, such as `care_history_screen.dart`'s status picker.
/// - `useSafeArea: true` — applies `SafeArea(bottom: false)`; the bottom
///   edge is still left to the sheet itself (so some sheets add
///   `MediaQuery.paddingOf(context).bottom` on top of the keyboard inset).
///
/// A sheet that needs different behaviour should call
/// `showModalBottomSheet` directly and say why at that call site, rather
/// than use this helper — see `food_search_screen.dart`'s meal picker and
/// `care_history_screen.dart`'s status picker.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}
