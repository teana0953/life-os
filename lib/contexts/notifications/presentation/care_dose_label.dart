import '../domain/care_item.dart';
import '../../../l10n/generated/app_localizations.dart';

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// The dose a care slot or schedule takes, as `×2 · 5mg` — or `×2` alone when
/// there is no free-text [dose] (optional even for medication) — or `''` for
/// any non-medication [category]. `doseQuantity` is sent for every category
/// (it defaults to 1 server-side) but the form only lets it be set for
/// medication (`careDoseQuantityLabel`'s "medication-only" contract), so a
/// rehab/radiotherapy/custom item's quantity is never a value the user chose
/// — showing it would read as real data that isn't there.
///
/// The quantity carries no unit anywhere in the contract, so it is rendered as
/// a unit-less multiplier rather than an invented unit word (design D1). The
/// number is formatted here and passed to the ARB message as a string so `×2` /
/// `×0.5` read identically in both locales (D4); the ` · ` separator is
/// punctuation, not translatable copy.
String careDoseLabel(
  AppLocalizations loc,
  CareCategory category,
  double doseQuantity,
  String? dose,
) {
  if (category != CareCategory.medication) return '';
  final quantity = loc.careDoseQuantityValue(_formatQuantity(doseQuantity));
  if (dose == null || dose.isEmpty) return quantity;
  return '$quantity · $dose';
}
