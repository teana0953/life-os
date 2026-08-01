import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The semantics data of the live-tree node whose merged label is [label].
///
/// Walks the real `SemanticsOwner` tree rather than reading a widget's cached
/// node, so it can only pass when the node actually reaching the platform
/// carries the flags.
SemanticsData? semanticsDataForLabel(WidgetTester tester, String label) {
  var root = tester.getSemantics(find.byType(MaterialApp));
  while (root.parent != null) {
    root = root.parent!;
  }
  SemanticsData? found;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    // Nodes merged into an ancestor never reach the platform on their own —
    // only the surviving node is what a screen reader reads.
    if (!node.isMergedIntoParent && data.label == label) found ??= data;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return found;
}
