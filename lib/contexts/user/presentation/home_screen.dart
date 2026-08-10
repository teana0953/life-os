import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/build_info.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/mascot.dart';
import 'home_controller.dart';

const _contentMaxWidth = 960.0;

/// Time-of-day period the home screen's greeting is based on.
enum GreetingPeriod { morning, afternoon, evening }

/// Buckets [time] into a [GreetingPeriod]. Takes a [DateTime] directly
/// (rather than reading `DateTime.now()` itself) so callers can inject a
/// fixed clock and keep tests deterministic.
GreetingPeriod greetingPeriodFor(DateTime time) {
  if (time.hour < 12) return GreetingPeriod.morning;
  if (time.hour < 18) return GreetingPeriod.afternoon;
  return GreetingPeriod.evening;
}

class HomeScreen extends StatefulWidget {
  final HomeController controller;

  /// Returns the current time, used to pick the home screen's time-of-day
  /// greeting. Defaults to [DateTime.now]; tests inject a fixed clock to
  /// avoid time-of-day flakiness.
  final DateTime Function() clock;

  const HomeScreen({
    super.key,
    required this.controller,
    this.clock = DateTime.now,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  // Navigation targets are built by the app router (from injected controllers),
  // so these just push the path — no screen construction here.
  void _openSettings(BuildContext context) => context.push('/settings');

  void _openHealth(BuildContext context) => context.push('/health');

  void _openFinance(BuildContext context) => context.push('/finance');

  void _openAssistant(BuildContext context) => context.push('/assistant');

  void _selectPrimaryDestination(BuildContext context, int index) {
    switch (index) {
      case 0:
        _openHealth(context);
        return;
      case 1:
        _openFinance(context);
        return;
      case 2:
      case 3:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.spaceComingSoon),
            ),
          );
        return;
      case 4:
        _openSettings(context);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: controller.status == HomeStatus.loaded
          ? AppBar(
              title: Text(loc.appTitle),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(
                      controller.profile?.displayName?.isNotEmpty == true
                          ? controller.profile!.displayName!.substring(0, 1)
                          : 'L',
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth < _contentMaxWidth
                ? constraints.maxWidth
                : _contentMaxWidth;
            return Center(
              child: SizedBox(
                width: contentWidth,
                child: _buildBody(context, controller),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: controller.status == HomeStatus.loaded
          ? NavigationBar(
              key: const Key('primary-navigation-bar'),
              selectedIndex: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) =>
                  _selectPrimaryDestination(context, index),
              destinations: [
                NavigationDestination(
                  key: const Key('health-tile'),
                  icon: const Icon(Icons.favorite_outline),
                  selectedIcon: const Icon(Icons.favorite),
                  label: loc.spaceHealth,
                ),
                NavigationDestination(
                  key: const Key('finance-tile'),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(Icons.account_balance_wallet),
                  label: loc.spaceFinance,
                ),
                NavigationDestination(
                  key: const Key('tasks-tile'),
                  icon: const Icon(Icons.task_alt),
                  label: loc.spaceTasks,
                ),
                NavigationDestination(
                  key: const Key('journal-tile'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: loc.spaceJournal,
                ),
                NavigationDestination(
                  key: const Key('settings-icon-button'),
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: loc.settingsTitle,
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, HomeController controller) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    switch (controller.status) {
      case HomeStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HomeStatus.loaded:
        final profile = controller.profile!;
        final greeting = switch (greetingPeriodFor(widget.clock())) {
          GreetingPeriod.morning => loc.greetingMorning,
          GreetingPeriod.afternoon => loc.greetingAfternoon,
          GreetingPeriod.evening => loc.greetingEvening,
        };
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Mascot(size: 64)),
              const SizedBox(height: 12),
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 2,
                  ),
                  boxShadow: ledgeShadow(theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile.email ?? '',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        loc.signedIn,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const Key('home-assistant-bar'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openAssistant(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 2,
                      ),
                      boxShadow: ledgeShadow(theme.colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.homeAssistantBarLabel,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // A small build id so a deployed (Flutter web) build can be told
              // apart from a cached one on the device. Not localized — it's a
              // technical build tag, not user-facing copy.
              Center(
                child: Text(
                  buildLabel,
                  key: const Key('build-label'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      case HomeStatus.error:
        final errorText = controller.error == ProfileError.fetchFailed
            ? loc.errorProfileLoadFailed
            : loc.errorSomethingWentWrong;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorText,
                key: const Key('error-message'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sign-out-button'),
                onPressed: controller.signOut,
                child: Text(loc.signOut),
              ),
            ],
          ),
        );
      case HomeStatus.needsReauth:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pleaseSignInAgain, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('sign-in-again-button'),
                onPressed: controller.signOut,
                child: Text(loc.signInAgain),
              ),
            ],
          ),
        );
    }
  }
}
