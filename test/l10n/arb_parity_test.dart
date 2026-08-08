import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three ARB files agree (issue #99).
///
/// Nothing else in the repo reads a `.arb`, and the one failure this guards
/// is silent by construction: `AppLocalizationsZhHant extends
/// AppLocalizationsZh`, so a key missing from `app_zh_Hant.arb` inherits the
/// `zh` value instead of failing. The build passes, the tests pass,
/// `flutter analyze` is clean, and the app quietly shows the wrong string.
/// `app_en.arb` is the gen_l10n template, so a key missing *there* is a
/// compile error and needs no guard.
///
/// Every recent round of copy changes ended with a reviewer diffing the key
/// sets by hand (#92, #97, #98, and twice more since). This is that diff,
/// written down.
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

  /// Message keys — everything that is not `@`-prefixed metadata.
  Set<String> messageKeys(Map<String, dynamic> file) =>
      file.keys.where((key) => !key.startsWith('@')).toSet();

  /// The argument names an ICU message takes: `{name}` and `{name, plural,`
  /// / `{name, select,`, and nothing else. `=1{` and `other{` open plural
  /// *sub-messages*, not arguments, and counting them would flag every
  /// correctly translated plural in the file — measured: six false positives
  /// before this pattern was narrowed.
  Set<String> placeholders(String message) =>
      RegExp(r'\{\s*([A-Za-z_]\w*)\s*[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

  final en = arb('en');
  final zh = arb('zh');
  final zhHant = arb('zh_Hant');

  test('the files are actually being read', () {
    // Without this, a wrong path or a rename turns every set below into the
    // empty set, every difference into no difference, and the whole file into
    // a suite that cannot fail. The floor is far under the real count (789 at
    // the time of writing) — it is a smoke test, not a budget.
    for (final entry in {'en': en, 'zh': zh, 'zh_Hant': zhHant}.entries) {
      expect(messageKeys(entry.value).length, greaterThan(500), reason: entry.key);
    }
  });

  test('en and zh_Hant carry exactly the same keys', () {
    // The pair that matters, and the pair that is copy-pasted: zh_Hant is the
    // only translation the app actually resolves to (`supportedLocales`).
    expect(
      messageKeys(en).difference(messageKeys(zhHant)),
      isEmpty,
      reason: 'translated in English but not in zh_Hant',
    );
    expect(
      messageKeys(zhHant).difference(messageKeys(en)),
      isEmpty,
      reason: 'in zh_Hant with no English template entry — gen_l10n ignores these, so they are dead',
    );
  });

  test('app_zh.arb holds nothing the template does not', () {
    // It is deliberately a subset: a fallback base that exists only because a
    // script-coded locale needs a plain-language ARB to exist (CLAUDE.md), so
    // it is not required to be complete. What it must not do is carry a key
    // of its own — that is either a typo or a string nothing can ever reach.
    expect(messageKeys(zh).difference(messageKeys(en)), isEmpty);
  });

  test('every English key has its translator description', () {
    // The existing convention (789/789 when this was written), and the thing
    // a translator has instead of the calling code.
    final undocumented = messageKeys(en).where((key) => !en.containsKey('@$key')).toList()..sort();
    expect(undocumented, isEmpty);
  });

  test('no description is left behind by a deleted key', () {
    final orphans = en.keys
        .where((key) => key.startsWith('@') && key != '@@locale' && !en.containsKey(key.substring(1)))
        .toList()
      ..sort();
    expect(orphans, isEmpty);
  });

  test('a translation takes the same arguments as its template', () {
    // A translation that drops `{name}` compiles and renders — with the name
    // simply missing from the sentence. Nothing else in the toolchain
    // notices: gen_l10n reads the placeholder list from the template only.
    final mismatched = <String>[];
    for (final key in messageKeys(en)) {
      final template = en[key];
      if (template is! String) continue;
      for (final entry in {'zh': zh, 'zh_Hant': zhHant}.entries) {
        final translated = entry.value[key];
        if (translated is! String) continue;
        if (!setEquals(placeholders(translated), placeholders(template))) {
          mismatched.add(
            '$key (${entry.key}): template takes ${placeholders(template)}, '
            'translation takes ${placeholders(translated)}',
          );
        }
      }
    }
    expect(mismatched..sort(), isEmpty);
  });
}
