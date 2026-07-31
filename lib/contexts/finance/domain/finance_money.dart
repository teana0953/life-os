import 'finance_type.dart';

/// Currencies with no minor-unit decimals (whole-number amounts). Every
/// other supported currency uses two decimals.
const _zeroDecimalCurrencies = {'TWD', 'JPY', 'KRW'};

/// The supported currency whitelist (design.md), in the order shown in the
/// currency selector — TWD first (the default).
const supportedCurrencies = [
  'TWD',
  'USD',
  'JPY',
  'EUR',
  'CNY',
  'KRW',
  'GBP',
  'HKD',
  'AUD',
  'CAD',
];

const defaultCurrency = 'TWD';

/// The number of minor-unit decimal digits for [currency]: 0 for
/// TWD/JPY/KRW, 2 for everything else.
int decimalDigitsFor(String currency) =>
    _zeroDecimalCurrencies.contains(currency) ? 0 : 2;

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

/// Formats a backend minor-unit integer [amount] (always non-negative) as a
/// display string for [currency], e.g. `1234` TWD -> `"1234"`, `1234` USD ->
/// `"12.34"`.
String formatMinorUnits(int amount, String currency) {
  final digits = decimalDigitsFor(currency);
  if (digits == 0) return amount.toString();
  final divisor = _pow10(digits);
  final whole = amount ~/ divisor;
  final fraction = (amount % divisor).toString().padLeft(digits, '0');
  return '$whole.$fraction';
}

/// [formatMinorUnits] prefixed with a sign for [type] — `"-1234"` for an
/// expense, `"+1234"` for income — used by the transaction list rows.
String formatSignedMinorUnits(int amount, String currency, FinanceType type) {
  final sign = type == FinanceType.expense ? '-' : '+';
  return '$sign${formatMinorUnits(amount, currency)}';
}

/// Parses user-typed amount [text] (e.g. `"12.5"`) into a backend minor-unit
/// integer for [currency], rounding to the currency's decimal digits.
/// Returns `null` for empty, non-numeric, or negative input — the caller
/// (the record sheet's save gate) treats that the same as "no amount yet".
int? parseAmountToMinorUnits(String text, String currency) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = double.tryParse(trimmed);
  if (value == null || value < 0) return null;
  final digits = decimalDigitsFor(currency);
  return (value * _pow10(digits)).round();
}
