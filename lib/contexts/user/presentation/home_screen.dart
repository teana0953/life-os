import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/build_info.dart';
import '../../../shared/i18n/locale_controller.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/mascot.dart';
import '../../auth/application/sign_out.dart';
import '../../auth/domain/auth_repository.dart';
import '../../health/application/get_logged_days.dart';
import '../../health/presentation/create_meal_controller.dart';
import '../../health/presentation/daily_target_controller.dart';
import '../../health/presentation/dictionary_controller.dart';
import '../../health/presentation/diet_shell_screen.dart';
import '../../health/presentation/today_controller.dart';
import '../../hydration/presentation/water_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import 'home_controller.dart';

const _contentMaxWidth = 960.0;

int _spacesCrossAxisCount(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

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
  final LocaleController localeController;
  final ThemeController themeController;
  final SignOut signOut;
  final AuthRepository authRepository;
  final TodayController healthTodayController;
  final DictionaryController healthDictionaryController;
  final DailyTargetController healthDailyTargetController;
  final CreateMealController healthCreateMealController;
  final GetLoggedDays healthGetLoggedDays;
  final WaterController waterController;

  /// Returns the current time, used to pick the home screen's time-of-day
  /// greeting. Defaults to [DateTime.now]; tests inject a fixed clock to
  /// avoid time-of-day flakiness.
  final DateTime Function() clock;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.localeController,
    required this.themeController,
    required this.signOut,
    required this.authRepository,
    required this.healthTodayController,
    required this.healthDictionaryController,
    required this.healthDailyTargetController,
    required this.healthCreateMealController,
    required this.healthGetLoggedDays,
    required this.waterController,
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

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController,
          localeController: widget.localeController,
          signOut: widget.signOut,
        ),
      ),
    );
  }

  void _openHealth(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DietShellScreen(
          authRepository: widget.authRepository,
          todayController: widget.healthTodayController,
          dictionaryController: widget.healthDictionaryController,
          dailyTargetController: widget.healthDailyTargetController,
          waterController: widget.waterController,
          createMealController: widget.healthCreateMealController,
          getLoggedDays: widget.healthGetLoggedDays,
          signOut: widget.signOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth < _contentMaxWidth
                    ? constraints.maxWidth
                    : _contentMaxWidth;
                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: _buildBody(context, controller, contentWidth),
                  ),
                );
              },
            ),
            if (controller.status == HomeStatus.loaded)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  key: const Key('settings-icon-button'),
                  icon: const Icon(Icons.settings),
                  tooltip: loc.settingsIconTooltip,
                  onPressed: () => _openSettings(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HomeController controller,
    double contentWidth,
  ) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    switch (controller.status) {
      case HomeStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HomeStatus.loaded:
        final profile = controller.profile!;
        final spacePreviewNames = [
          loc.spaceHealth,
          loc.spaceFinance,
          loc.spaceTasks,
          loc.spaceJournal,
        ];
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
                  border: Border.all(color: theme.colorScheme.outline, width: 2),
                  boxShadow: ledgeShadow(theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(profile.email ?? '', style: theme.textTheme.bodyLarge),
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
              Text(loc.yourSpaces, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              GridView.builder(
                key: const Key('spaces-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _spacesCrossAxisCount(contentWidth),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: spacePreviewNames.length,
                itemBuilder: (context, index) {
                  final tile = Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.colorScheme.outline, width: 2),
                    ),
                    child: Text(spacePreviewNames[index]),
                  );
                  if (index != 0) return tile;
                  return Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const Key('health-tile'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openHealth(context),
                      child: tile,
                    ),
                  );
                },
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
