import 'package:flutter/material.dart';

/// Opens the Material time picker forced to a 24-hour clock, regardless of
/// the device locale.
///
/// Every call site that uses this stores and displays its time in 24-hour
/// "HH:mm" form. Letting the picker follow a 12-hour locale instead would
/// have the user pick e.g. "9:30 PM" and then read it back as "21:30", with
/// nothing on screen explaining why — their input wasn't wrong, it was just
/// rewritten in a different notation.
///
/// This bug shipped, and was independently fixed with a hand-written
/// `MediaQuery` builder, in `care_item_form.dart` (twice) and
/// `care_today_screen.dart` before this shared helper existed — three
/// duplicated fixes with no common `lib/shared/` home for the next call site
/// to find and copy. This is that shared version.
Future<TimeOfDay?> pickTime24h(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}
