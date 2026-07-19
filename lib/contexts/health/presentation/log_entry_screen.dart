import 'package:flutter/material.dart';

import 'log_entry_controller.dart';
import 'quantity_card.dart';

/// Bottom-sheet body hosting the [QuantityCard] for logging one dictionary
/// item into the current session's meal (D1 in design.md). Pushed via
/// `showModalBottomSheet(isScrollControlled: true)` by the shell, mirroring
/// `EditEntryScreen`. Pop is this sheet's own responsibility: on a
/// successful save it pops itself (from its own context) and then invokes
/// [onSaved] — the shell's own `onSaved` handler stays pop-free.
class LogEntryScreen extends StatelessWidget {
  final LogEntryController controller;
  final String idToken;
  final String day;
  final VoidCallback? onSaved;

  const LogEntryScreen({
    super.key,
    required this.controller,
    required this.idToken,
    required this.day,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: QuantityCard(
            controller: controller,
            idToken: idToken,
            day: day,
            onSaved: () {
              Navigator.of(context).pop();
              onSaved?.call();
            },
          ),
        ),
      ),
    );
  }
}
