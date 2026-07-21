import '../../../l10n/generated/app_localizations.dart';

/// Extracts the dictionary-basis unit word from a food's name (e.g.
/// `飯/1碗` -> `碗`, stripping the leading digits) — used as the after-field
/// unit label in portion mode, and for the consumed-amount label on Today.
/// Falls back to a generic quantity word when the name has no `/` unit
/// segment. Never returns a bare "g"/"ml".
String unitLabelForName(String? name, AppLocalizations loc) {
  if (name == null) return loc.dietQuantityLabel;
  final slash = name.indexOf('/');
  if (slash == -1 || slash == name.length - 1) return loc.dietQuantityLabel;
  final segment = name.substring(slash + 1);
  final digits = RegExp(r'^[0-9.]+').firstMatch(segment);
  final unit = digits == null ? segment : segment.substring(digits.end);
  return unit.isEmpty ? loc.dietQuantityLabel : unit;
}
