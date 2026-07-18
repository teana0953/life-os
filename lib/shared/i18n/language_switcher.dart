import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'locale_controller.dart';

const _zhHantLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
);

/// The three choices offered by [LanguageSwitcher]'s menu.
enum _LanguageOption { system, english, zhHant }

/// Chip-style control, shown on the sign-in and home screens, that opens a
/// menu to choose the app's language: follow the system locale, English, or
/// Traditional Chinese, via [controller].
class LanguageSwitcher extends StatelessWidget {
  final LocaleController controller;

  const LanguageSwitcher({super.key, required this.controller});

  void _onSelected(_LanguageOption option) {
    switch (option) {
      case _LanguageOption.system:
        controller.clear();
      case _LanguageOption.english:
        controller.setLocale(const Locale('en'));
      case _LanguageOption.zhHant:
        controller.setLocale(_zhHantLocale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final currentLabel = isZh
        ? loc.languageTraditionalChinese
        : loc.languageEnglish;

    return PopupMenuButton<_LanguageOption>(
      key: const Key('language-switcher'),
      tooltip: loc.switchLanguage,
      onSelected: _onSelected,
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          key: const Key('language-option-system'),
          value: _LanguageOption.system,
          checked: controller.locale == null,
          child: Text(loc.followSystemLanguage),
        ),
        CheckedPopupMenuItem(
          key: const Key('language-option-en'),
          value: _LanguageOption.english,
          checked: controller.locale == const Locale('en'),
          child: Text(loc.languageEnglish),
        ),
        CheckedPopupMenuItem(
          key: const Key('language-option-zh'),
          value: _LanguageOption.zhHant,
          checked: controller.locale == _zhHantLocale,
          child: Text(loc.languageTraditionalChinese),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              currentLabel,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
