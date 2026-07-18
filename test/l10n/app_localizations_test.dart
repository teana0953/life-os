import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('en provides English strings', () {
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(loc.welcomeBack, 'Welcome back');
      expect(loc.yourSpaces, 'Your spaces');
      expect(loc.errorIncorrectCredentials, 'Incorrect email or password.');
    });

    test('zh-Hant provides Traditional Chinese strings', () {
      final loc = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );

      expect(loc.welcomeBack, '歡迎回來');
      expect(loc.yourSpaces, '你的空間');
      expect(loc.errorIncorrectCredentials, '電子郵件或密碼錯誤。');
    });
  });
}
