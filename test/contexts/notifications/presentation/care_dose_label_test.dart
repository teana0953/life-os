import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/presentation/care_dose_label.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  test('joins the quantity and the free-text dose', () {
    expect(
      careDoseLabel(loc, CareCategory.medication, 2, '5mg'),
      '${loc.careDoseQuantityValue('2')} · 5mg',
    );
  });

  test('shows the quantity alone when there is no free-text dose', () {
    expect(
      careDoseLabel(loc, CareCategory.medication, 1, null),
      loc.careDoseQuantityValue('1'),
    );
  });

  // An empty-string dose reaches here as readily as a null one (the form
  // stores what the user left blank), and must not produce a dangling ' · '.
  test('shows the quantity alone when the free-text dose is empty', () {
    expect(
      careDoseLabel(loc, CareCategory.medication, 1, ''),
      loc.careDoseQuantityValue('1'),
    );
  });

  test('a whole-number quantity drops its trailing .0', () {
    expect(
      careDoseLabel(loc, CareCategory.medication, 2, null),
      loc.careDoseQuantityValue('2'),
    );
    expect(careDoseLabel(loc, CareCategory.medication, 2, null), contains('2'));
    expect(
      careDoseLabel(loc, CareCategory.medication, 2, null),
      isNot(contains('2.0')),
    );
  });

  test('a fractional quantity keeps its decimal', () {
    expect(
      careDoseLabel(loc, CareCategory.medication, 0.5, null),
      loc.careDoseQuantityValue('0.5'),
    );
  });

  test('the Traditional Chinese label formats the number the same way', () {
    final zh = lookupAppLocalizations(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
    expect(
      careDoseLabel(zh, CareCategory.medication, 2, '5mg'),
      '${zh.careDoseQuantityValue('2')} · 5mg',
    );
  });

  // The dose-quantity field is medication-only (`careDoseQuantityLabel`'s
  // form contract) — the backend still sends a default quantity of 1 for
  // every category, so a non-medication slot must render nothing rather
  // than showing a quantity the user never set.
  test('is empty for a non-medication category, even with a dose', () {
    expect(careDoseLabel(loc, CareCategory.rehab, 1, '10 reps'), '');
    expect(careDoseLabel(loc, CareCategory.radiotherapyCare, 1, null), '');
    expect(careDoseLabel(loc, CareCategory.custom, 3, 'note'), '');
  });
}
