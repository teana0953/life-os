import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/i18n/locale_controller.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../auth/application/sign_out.dart';

const _zhHantLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
);

/// Settings page: theme, language, and sign-out. Presentation-only —
/// orchestrates the shared [ThemeController]/[LocaleController] and the
/// auth context's [SignOut] use case; holds no business logic of its own.
class SettingsScreen extends StatefulWidget {
  final ThemeController themeController;
  final LocaleController localeController;
  final SignOut signOut;

  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.localeController,
    required this.signOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_onControllerChanged);
    widget.localeController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onControllerChanged);
    widget.localeController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Signs out, then pops the settings page (if it was pushed on top of the
  /// home screen) so the app-level auth-state routing — which has by then
  /// switched `MaterialApp.home` to [LoginScreen] — becomes visible again.
  Future<void> _signOut(BuildContext context) async {
    await widget.signOut();
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _SettingsSection(
                  title: loc.themeSectionTitle,
                  children: [
                    _OptionRow<ThemeMode>(
                      rowKey: const Key('theme-option-system'),
                      label: loc.themeSystem,
                      value: ThemeMode.system,
                      groupValue: widget.themeController.themeMode,
                      onSelected: widget.themeController.setThemeMode,
                    ),
                    _OptionRow<ThemeMode>(
                      rowKey: const Key('theme-option-light'),
                      label: loc.themeLight,
                      value: ThemeMode.light,
                      groupValue: widget.themeController.themeMode,
                      onSelected: widget.themeController.setThemeMode,
                    ),
                    _OptionRow<ThemeMode>(
                      rowKey: const Key('theme-option-dark'),
                      label: loc.themeDark,
                      value: ThemeMode.dark,
                      groupValue: widget.themeController.themeMode,
                      onSelected: widget.themeController.setThemeMode,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: loc.languageSectionTitle,
                  children: [
                    _OptionRow<Locale?>(
                      rowKey: const Key('settings-language-option-system'),
                      label: loc.followSystemLanguage,
                      value: null,
                      groupValue: widget.localeController.locale,
                      onSelected: (_) => widget.localeController.clear(),
                    ),
                    _OptionRow<Locale?>(
                      rowKey: const Key('settings-language-option-en'),
                      label: loc.languageEnglish,
                      value: const Locale('en'),
                      groupValue: widget.localeController.locale,
                      onSelected: (locale) =>
                          widget.localeController.setLocale(locale!),
                    ),
                    _OptionRow<Locale?>(
                      rowKey: const Key('settings-language-option-zh'),
                      label: loc.languageTraditionalChinese,
                      value: _zhHantLocale,
                      groupValue: widget.localeController.locale,
                      onSelected: (locale) =>
                          widget.localeController.setLocale(locale!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  key: const Key('settings-sign-out-button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                  onPressed: () => _signOut(context),
                  child: Text(loc.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A themed, rounded card grouping a titled cluster of settings rows.
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline, width: 2),
        boxShadow: ledgeShadow(theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// A tappable row representing one choice in a settings selection group
/// (theme or language), showing a filled/outline circle to indicate whether
/// [value] is the current [groupValue]. Avoids the deprecated
/// `RadioListTile.groupValue`/`onChanged` API.
class _OptionRow<T> extends StatelessWidget {
  final Key rowKey;
  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onSelected;

  const _OptionRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = value == groupValue;
    return ListTile(
      key: rowKey,
      selected: selected,
      onTap: () => onSelected(value),
      title: Text(label),
      leading: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
    );
  }
}
