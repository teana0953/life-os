import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'log_entry_controller.dart';
import 'quantity_card.dart';

/// Thin screen hosting the [QuantityCard] for logging one dictionary item.
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
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.dietLogEntryTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: QuantityCard(
            controller: controller,
            idToken: idToken,
            day: day,
            onSaved: () {
              onSaved?.call();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}
