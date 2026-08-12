import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The semantics data of the live-tree node whose merged label is [label].
///
/// Walks the real `SemanticsOwner` tree rather than reading a widget's cached
/// node, so it can only pass when the node actually reaching the platform
/// carries the flags.
SemanticsData? semanticsDataForLabel(WidgetTester tester, String label) {
  return _walk(tester, (node, data) {
    // Nodes merged into an ancestor never reach the platform on their own —
    // only the surviving node is what a screen reader reads.
    if (!node.isMergedIntoParent && data.label == label) return data;
    return null;
  });
}

/// Every label the live semantics tree exposes, merged nodes included.
///
/// For the "no node anywhere says X" half of a masking guard: asserting that
/// one named node reads `Hidden` cannot see a *second* node still reading the
/// figure out loud, and merged-in children are included precisely because
/// their text is what the surviving ancestor reads.
List<String> allSemanticsLabels(WidgetTester tester) {
  final labels = <String>[];
  _walk(tester, (node, data) {
    if (data.label.isNotEmpty) labels.add(data.label);
    return null;
  });
  return labels;
}

/// Every non-empty `tooltip` the live semantics tree exposes.
///
/// An icon-only button's accessible name arrives as a semantics *tooltip*,
/// not a label — reading `IconButton.tooltip` off the widget proves the
/// property was set, not that a node carrying it reached the platform.
List<String> allSemanticsTooltips(WidgetTester tester) {
  final tooltips = <String>[];
  _walk(tester, (node, data) {
    if (data.tooltip.isNotEmpty) tooltips.add(data.tooltip);
    return null;
  });
  return tooltips;
}

/// Visits every node of the live tree, returning the first non-null [visitor]
/// result.
T? _walk<T>(WidgetTester tester, T? Function(SemanticsNode, SemanticsData) visitor) {
  var root = tester.getSemantics(find.byType(MaterialApp));
  while (root.parent != null) {
    root = root.parent!;
  }
  T? found;
  void visit(SemanticsNode node) {
    found ??= visitor(node, node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return found;
}
