import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'locale_controller.dart';

/// Lightweight icon button, shown on the sign-in and home screens, that
/// toggles the active language between English and Traditional Chinese via
/// [controller].
class LanguageSwitcher extends StatelessWidget {
  final LocaleController controller;

  const LanguageSwitcher({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final target = isZh
        ? const Locale('en')
        : const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    return IconButton(
      key: const Key('language-switcher'),
      icon: const Icon(Icons.translate),
      tooltip: AppLocalizations.of(context)!.switchLanguage,
      onPressed: () => controller.setLocale(target),
    );
  }
}
