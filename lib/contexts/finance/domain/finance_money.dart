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

/// Formats a backend minor-unit integer [amount] (always non-negative) for an
/// **input field**: no digit grouping, e.g. `1234` TWD -> `"1234"`, `1234` USD
/// -> `"12.34"`.
///
/// Use [formatMinorUnitsForDisplay] for anything the user only reads. This
/// plain form exists because its output is fed straight back into
/// [parseAmountToMinorUnits] when a sheet pre-fills an amount for editing, and
/// that parser takes a bare number — a grouped `"1,234"` would parse as null
/// and silently blank the field.
String formatMinorUnits(int amount, String currency) {
  final digits = decimalDigitsFor(currency);
  if (digits == 0) return amount.toString();
  final divisor = _pow10(digits);
  final whole = amount ~/ divisor;
  final fraction = (amount % divisor).toString().padLeft(digits, '0');
  return '$whole.$fraction';
}

/// Groups the integer part of [digits] into three-digit runs separated by
/// commas: `"1234567"` -> `"1,234,567"`, `"1234.56"` -> `"1,234.56"`.
String _groupThousands(String digits) {
  final dot = digits.indexOf('.');
  final whole = dot == -1 ? digits : digits.substring(0, dot);
  final rest = dot == -1 ? '' : digits.substring(dot);
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '$buffer$rest';
}

/// Formats a backend minor-unit integer [amount] (always non-negative) for
/// **display**, with thousands separators: `1234567` TWD -> `"1,234,567"`,
/// `123456` USD -> `"1,234.56"`.
///
/// Never feed this back into [parseAmountToMinorUnits] — see [formatMinorUnits].
String formatMinorUnitsForDisplay(int amount, String currency) =>
    _groupThousands(formatMinorUnits(amount, currency));

/// [formatMinorUnitsForDisplay] prefixed with a sign for [type] — `"-1234"` for an
/// expense, `"+1234"` for income — used by the transaction list rows.
String formatSignedMinorUnits(int amount, String currency, FinanceType type) {
  final sign = type == FinanceType.expense ? '-' : '+';
  return '$sign${formatMinorUnitsForDisplay(amount, currency)}';
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
