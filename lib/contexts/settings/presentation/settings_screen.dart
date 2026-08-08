import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/assistant/gemini_key_controller.dart';
import '../../../shared/i18n/locale_controller.dart';
import '../../../shared/pwa/pwa_install.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/ledge_card.dart';
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
  final GeminiKeyController geminiKeyController;
  final SignOut signOut;
  final PwaInstall pwaInstall;

  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.localeController,
    required this.geminiKeyController,
    required this.signOut,
    required this.pwaInstall,
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
    widget.geminiKeyController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onControllerChanged);
    widget.localeController.removeListener(_onControllerChanged);
    widget.geminiKeyController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  /// Signs out, then pops the settings page (if it was pushed on top of the
  /// home screen) so the app-level auth-state routing — which has by then
  /// switched `MaterialApp.home` to [LoginScreen] — becomes visible again.
  Future<void> _signOut(BuildContext context) async {
    await widget.signOut();
    if (context.mounted && context.canPop()) {
      context.pop();
    }
  }

  /// The web-PWA install affordance. Renders nothing (native/mobile builds,
  /// already-installed standalone sessions, or browsers with nothing to offer),
  /// an "Install LifeOS" button when the browser has a pending install prompt,
  /// or a short add-to-home instruction on iOS Safari.
  List<Widget> _buildInstallSection(BuildContext context, AppLocalizations loc) {
    final pwa = widget.pwaInstall;
    if (pwa.isStandalone) return const [];

    final Widget content;
    if (pwa.canInstall) {
      content = FilledButton(
        key: const Key('settings-install-button'),
        onPressed: pwa.promptInstall,
        child: Text(loc.settingsInstallButton),
      );
    } else if (pwa.isIosHint) {
      content = ListTile(title: Text(loc.settingsInstallIosHint));
    } else {
      return const [];
    }

    return [
      const SizedBox(height: 20),
      _SettingsSection(
        title: loc.settingsInstallSectionTitle,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: content,
          ),
        ],
      ),
    ];
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
                _SettingsSection(
                  title: loc.settingsFriendsSectionTitle,
                  children: [
                    _NavRow(
                      rowKey: const Key('settings-friends-row'),
                      label: loc.settingsFriendsRowLabel,
                      onTap: () => context.push('/friends'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _AssistantKeySection(controller: widget.geminiKeyController),
                ..._buildInstallSection(context, loc),
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
    return LedgeCard(
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

/// The "AI assistant" section: paste/store a Gemini API key on this device.
///
/// The full key exists in memory only while it sits in the input field; once
/// saved, the UI only ever shows the last four characters (via
/// [GeminiKeyController.last4]) and the field is cleared. Both states carry
/// the same two always-visible notices: the key lives in device-local storage
/// (a PWA reinstall or cleared browser data removes it), and free-tier Gemini
/// content may be used by Google for model training.
class _AssistantKeySection extends StatefulWidget {
  final GeminiKeyController controller;

  const _AssistantKeySection({required this.controller});

  @override
  State<_AssistantKeySection> createState() => _AssistantKeySectionState();
}

class _AssistantKeySectionState extends State<_AssistantKeySection> {
  final _keyFieldController = TextEditingController();

  @override
  void dispose() {
    _keyFieldController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.controller.setKey(_keyFieldController.text);
    // Drop the only in-memory copy of the full key the UI holds: if the user
    // later clears the stored key, the field must come back empty, not
    // pre-filled with the secret.
    _keyFieldController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return _SettingsSection(
      title: loc.settingsAssistantSectionTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.controller.hasKey) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        key: const Key('assistant-key-set-label'),
                        loc.settingsAssistantKeySet(widget.controller.last4!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('assistant-key-clear-button'),
                  onPressed: widget.controller.clear,
                  child: Text(loc.settingsAssistantClearKeyButton),
                ),
              ] else ...[
                Text(loc.settingsAssistantIntro),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('assistant-key-field'),
                  controller: _keyFieldController,
                  // A secret: dots on screen, and keep it out of the
                  // keyboard's learning/suggestion dictionary.
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: loc.settingsAssistantKeyFieldLabel,
                    hintText: loc.settingsAssistantKeyFieldHint,
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _keyFieldController,
                  builder: (context, value, _) => FilledButton(
                    key: const Key('assistant-key-save-button'),
                    onPressed: value.text.trim().isEmpty ? null : _save,
                    child: Text(loc.settingsAssistantSaveKeyButton),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                loc.settingsAssistantDeviceNotice,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                loc.settingsAssistantTrainingNotice,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
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

/// A tappable row that navigates elsewhere (trailing chevron) — distinct
/// from [_OptionRow], which models a selectable option within a group
/// (value/groupValue/onSelected + a filled/outline circle).
class _NavRow extends StatelessWidget {
  final Key rowKey;
  final String label;
  final VoidCallback onTap;

  const _NavRow({required this.rowKey, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: rowKey,
      onTap: onTap,
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
