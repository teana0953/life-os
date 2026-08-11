import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/build_info.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../finance/domain/finance_money.dart';
import '../../menstrual/domain/next_period_status.dart';
import 'home_controller.dart';
import 'home_dashboard_controller.dart';

const _contentMaxWidth = 960.0;

enum GreetingPeriod { morning, afternoon, evening }

GreetingPeriod greetingPeriodFor(DateTime time) {
  if (time.hour < 12) return GreetingPeriod.morning;
  if (time.hour < 18) return GreetingPeriod.afternoon;
  return GreetingPeriod.evening;
}

class HomeScreen extends StatefulWidget {
  final HomeController controller;
  final HomeDashboardController? dashboardController;
  final DateTime Function() clock;
  final Future<String> Function()? idToken;

  const HomeScreen({
    super.key,
    required this.controller,
    this.dashboardController,
    this.clock = DateTime.now,
    this.idToken,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.dashboardController?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.dashboardController != widget.dashboardController) {
      oldWidget.dashboardController?.removeListener(_onControllerChanged);
      widget.dashboardController?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.dashboardController?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _openSettings() => context.push('/settings');
  void _openHealth() => context.push('/health');
  void _openFinance() => context.push('/finance');
  void _openAssistant() => context.push('/assistant');
  void _openVitals() => context.push('/health/vitals');
  void _openMenstrual() => context.push('/health/menstrual');
  void _openFoodDictionary() => context.push('/health/diet/dictionary');

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.spaceComingSoon)),
      );
  }

  Future<void> _retryDashboard() async {
    final dashboard = widget.dashboardController;
    final token = widget.idToken;
    if (dashboard == null || token == null) return;
    await dashboard.load(await token(), widget.clock());
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
                IconButton(
                  key: const Key('settings-icon-button'),
                  tooltip: loc.settingsIconTooltip,
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0, _contentMaxWidth);
            return Center(
              child: SizedBox(
                width: width.toDouble(),
                child: _buildBody(controller),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(HomeController controller) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    switch (controller.status) {
      case HomeStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HomeStatus.loaded:
        final name = controller.profile?.displayName?.trim() ?? '';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _greeting(loc, widget.clock(), name),
                key: const Key('home-greeting'),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                loc.homeHubPrompt,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _AssistantEntry(onTap: _openAssistant),
              const SizedBox(height: 18),
              _buildDashboard(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _FutureEntry(
                      entryKey: const Key('tasks-tile'),
                      icon: Icons.task_alt_outlined,
                      label: loc.spaceTasks,
                      comingSoon: loc.spaceComingSoon,
                      onTap: _showComingSoon,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FutureEntry(
                      entryKey: const Key('journal-tile'),
                      icon: Icons.menu_book_outlined,
                      label: loc.spaceJournal,
                      comingSoon: loc.spaceComingSoon,
                      onTap: _showComingSoon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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

  Widget _buildDashboard() {
    final loc = AppLocalizations.of(context)!;
    final dashboard = widget.dashboardController;
    // `dashboard == null` ONLY — deliberately not `status == idle`. `idle`
    // means "nobody has asked for the figures yet", and since the fan-out was
    // deferred to the moment home becomes the visible page, that state now
    // outlives the first frame of every return to home: the listener fires,
    // then waits on `idToken()` (which reaches the network whenever the token
    // is close to expiring). Painting the no-data layout during that gap tells
    // a user who has records that they have none. It gets the same placeholder
    // as `loading` below, because that is exactly what it is.
    if (dashboard == null) {
      return Column(
        children: [
          _DashboardSection(
            sectionKey: const Key('health-dashboard-section'),
            openKey: const Key('health-tile'),
            title: loc.spaceHealth,
            openLabel: loc.homeOpenHealth,
            onOpen: _openHealth,
            children: [
              _SnapshotTile(
                tileKey: const Key('home-latest-weight'),
                label: loc.homeLatestWeight,
                value: loc.homeNoData,
                onTap: _openVitals,
              ),
              _SnapshotTile(
                tileKey: const Key('home-food-dictionary'),
                label: loc.homeFoodPortionTool,
                actionLabel: loc.homeFoodPortionButton,
                onTap: _openFoodDictionary,
              ),
              _SnapshotTile(
                tileKey: const Key('home-latest-blood-pressure'),
                label: loc.homeLatestBloodPressure,
                value: loc.homeNoData,
                onTap: _openVitals,
              ),
              _SnapshotTile(
                tileKey: const Key('home-menstrual-prediction'),
                label: loc.homeMenstrualPrediction,
                value: loc.homeNoData,
                onTap: _openMenstrual,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DashboardSection(
            sectionKey: const Key('finance-dashboard-section'),
            openKey: const Key('finance-tile'),
            title: loc.spaceFinance,
            openLabel: loc.homeOpenFinance,
            onOpen: _openFinance,
            children: [
              for (final entry in [
                (const Key('home-budget'), loc.homeBudget),
                (const Key('home-total-assets'), loc.homeTotalAssets),
                (const Key('home-total-liabilities'), loc.homeTotalLiabilities),
                (const Key('home-split-overview'), loc.homeSplitOverview),
              ])
                _SnapshotTile(
                  tileKey: entry.$1,
                  label: entry.$2,
                  value: loc.homeNoData,
                  onTap: _openFinance,
                ),
            ],
          ),
        ],
      );
    }
    if (dashboard.status == HomeDashboardStatus.idle ||
        dashboard.status == HomeDashboardStatus.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (dashboard.status == HomeDashboardStatus.error ||
        dashboard.data == null) {
      return _DashboardUnavailable(
        text: loc.homeDashboardLoadFailed,
        retryLabel: loc.retry,
        onRetry: _retryDashboard,
      );
    }
    final data = dashboard.data!;
    return Column(
      children: [
        _DashboardSection(
          sectionKey: const Key('health-dashboard-section'),
          openKey: const Key('health-tile'),
          title: loc.spaceHealth,
          openLabel: loc.homeOpenHealth,
          onOpen: _openHealth,
          children: [
            _SnapshotTile(
              tileKey: const Key('home-latest-weight'),
              label: loc.homeLatestWeight,
              value: data.weightGoal.currentWeightKg == null
                  ? loc.homeNoData
                  : loc.homeWeightValue(
                      _compactNumber(data.weightGoal.currentWeightKg!),
                    ),
              onTap: _openVitals,
            ),
            _SnapshotTile(
              tileKey: const Key('home-food-dictionary'),
              label: loc.homeFoodPortionTool,
              actionLabel: loc.homeFoodPortionButton,
              onTap: _openFoodDictionary,
            ),
            _SnapshotTile(
              tileKey: const Key('home-latest-blood-pressure'),
              label: loc.homeLatestBloodPressure,
              value: data.bloodPressure == null
                  ? loc.homeNoData
                  : '${_compactNumber(data.bloodPressure!.systolic)} / '
                        '${_compactNumber(data.bloodPressure!.diastolic)}',
              onTap: _openVitals,
            ),
            _SnapshotTile(
              tileKey: const Key('home-menstrual-prediction'),
              label: loc.homeMenstrualPrediction,
              value: _menstrualValue(context, loc, data.menstrualStatus),
              onTap: _openMenstrual,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DashboardSection(
          sectionKey: const Key('finance-dashboard-section'),
          openKey: const Key('finance-tile'),
          title: loc.spaceFinance,
          openLabel: loc.homeOpenFinance,
          onOpen: _openFinance,
          children: [
            _SnapshotTile(
              tileKey: const Key('home-budget'),
              label: loc.homeBudget,
              value: data.overallBudget == null
                  ? loc.homeNoData
                  : loc.homeBudgetRemaining(
                      formatMinorUnitsForDisplay(
                        data.overallBudget!.remaining,
                        defaultCurrency,
                      ),
                    ),
              onTap: _openFinance,
            ),
            _SnapshotTile(
              tileKey: const Key('home-total-assets'),
              label: loc.homeTotalAssets,
              value: formatMinorUnitsForDisplay(
                data.netWorth.totalAsset,
                defaultCurrency,
              ),
              onTap: _openFinance,
            ),
            _SnapshotTile(
              tileKey: const Key('home-total-liabilities'),
              label: loc.homeTotalLiabilities,
              value: formatMinorUnitsForDisplay(
                data.netWorth.totalLiability,
                defaultCurrency,
              ),
              onTap: _openFinance,
            ),
            _SnapshotTile(
              tileKey: const Key('home-split-overview'),
              label: loc.homeSplitOverview,
              value: _splitValue(loc, data),
              onTap: _openFinance,
            ),
          ],
        ),
      ],
    );
  }
}

String _greeting(AppLocalizations loc, DateTime now, String name) {
  final period = greetingPeriodFor(now);
  if (name.isEmpty) {
    return switch (period) {
      GreetingPeriod.morning => loc.greetingMorning,
      GreetingPeriod.afternoon => loc.greetingAfternoon,
      GreetingPeriod.evening => loc.greetingEvening,
    };
  }
  return switch (period) {
    GreetingPeriod.morning => loc.greetingMorningName(name),
    GreetingPeriod.afternoon => loc.greetingAfternoonName(name),
    GreetingPeriod.evening => loc.greetingEveningName(name),
  };
}

String _compactNumber(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

String _menstrualValue(
  BuildContext context,
  AppLocalizations loc,
  NextPeriodStatus status,
) {
  switch (status.state) {
    case NextPeriodState.ongoing:
      return loc.homeMenstrualOngoing(status.days!);
    case NextPeriodState.noRecords:
      return loc.homeNoData;
    case NextPeriodState.needsOneMore:
      return loc.homeMenstrualNeedsMore;
    case NextPeriodState.upcoming:
      return loc.homeMenstrualExpected(
        MaterialLocalizations.of(
          context,
        ).formatShortDate(status.predictedNextStart!),
      );
    case NextPeriodState.today:
      return loc.homeMenstrualToday;
    case NextPeriodState.overdue:
      return loc.homeMenstrualOverdue(status.days!);
  }
}

String _splitValue(AppLocalizations loc, HomeDashboardData data) {
  var receivable = 0;
  var payable = 0;
  for (final person in data.splitBalances) {
    for (final balance in person.balances) {
      if (balance.currency != defaultCurrency) continue;
      if (balance.amount > 0) receivable += balance.amount;
      if (balance.amount < 0) payable += -balance.amount;
    }
  }
  if (receivable == 0 && payable == 0) return loc.homeSplitSettled;
  if (receivable > 0) {
    return loc.homeSplitReceivable(
      formatMinorUnitsForDisplay(receivable, defaultCurrency),
    );
  }
  return loc.homeSplitPayable(
    formatMinorUnitsForDisplay(payable, defaultCurrency),
  );
}

class _AssistantEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _AssistantEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return LedgeCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: const Key('home-assistant-bar'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(loc.homeAssistantBarLabel)),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final Key sectionKey;
  final Key openKey;
  final String title;
  final String openLabel;
  final VoidCallback onOpen;
  final List<Widget> children;

  const _DashboardSection({
    required this.sectionKey,
    required this.openKey,
    required this.title,
    required this.openLabel,
    required this.onOpen,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LedgeCard(
      key: sectionKey,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              TextButton(
                key: openKey,
                onPressed: onOpen,
                child: Text(openLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < 330;
              final tileWidth = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final child in children)
                    SizedBox(width: tileWidth, child: child),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final Key tileKey;
  final String label;
  final String? value;
  final String? actionLabel;
  final VoidCallback onTap;

  const _SnapshotTile({
    required this.tileKey,
    required this.label,
    this.value,
    this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: tileKey,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            if (actionLabel != null)
              Text(actionLabel!, style: theme.textTheme.labelLarge)
            else
              Text(value ?? '', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _FutureEntry extends StatelessWidget {
  final Key entryKey;
  final IconData icon;
  final String label;
  final String comingSoon;
  final VoidCallback onTap;

  const _FutureEntry({
    required this.entryKey,
    required this.icon,
    required this.label,
    required this.comingSoon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: entryKey,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(comingSoon, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardUnavailable extends StatelessWidget {
  final String text;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const _DashboardUnavailable({
    required this.text,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null && retryLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel!)),
          ],
        ],
      ),
    );
  }
}
