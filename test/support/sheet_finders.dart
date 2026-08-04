import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locates the drag handle Flutter renders for `showModalBottomSheet(
/// showDragHandle: true)`. The handle itself is the SDK-private `_DragHandle`
/// widget (`material/bottom_sheet.dart`), so it is matched structurally by what
/// it uniquely renders: a 48x48 `Semantics` **button** labelled with the
/// modal-barrier dismiss label, *inside* the sheet. Without `showDragHandle`
/// the sheet's child is the builder's content alone and nothing matches.
///
/// Scoping to [sheet] matters: the modal barrier carries the same label, so an
/// unscoped `find.bySemanticsLabel` would match with or without the handle.
Finder dragHandleIn(WidgetTester tester, Finder sheet) {
  final label = MaterialLocalizations.of(
    tester.element(sheet),
  ).modalBarrierDismissLabel;
  return find.descendant(
    of: sheet,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label == label,
    ),
  );
}

/// Asserts the currently open bottom sheet has a working drag handle — the
/// only close affordance left when a tall sheet fills the viewport.
void expectSheetHasDragHandle(WidgetTester tester) {
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget);
  final handle = dragHandleIn(tester, sheet);
  expect(handle, findsOneWidget);
  // The handle's interactive area, i.e. the region a pull-down can grab.
  expect(tester.getSize(handle), const Size(48, 48));
}
