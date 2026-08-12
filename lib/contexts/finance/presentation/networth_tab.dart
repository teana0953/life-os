import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/label_value_row.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/month_nav_header.dart';
import '../../../shared/widgets/month_picker_dialog.dart';
import '../domain/finance_month.dart';
import '../domain/finance_money.dart';
import '../domain/networth_account.dart';
import '../domain/networth_snapshot.dart';
import 'finance_controller.dart';
import 'networth_controller.dart';

/// 淨值: the month switcher, the net worth headline with its month-over-month
/// growth, asset/liability accounts with the month's values, and the recent
/// net worth trend. Loading/reauth go through [AsyncStateScaffold]; the load
/// failure and the empty-month guide are handled here, mirroring
/// `FinanceOverviewTab`.
class NetWorthTab extends StatelessWidget {
  final NetWorthController controller;
  final Future<void> Function(String month) onSwitchMonth;
  final void Function(NetWorthAccount account) onEditAccountValue;
  final VoidCallback onManageAccounts;

  /// Invoked when the user taps the reauth state's sign-in-again control
  /// (see [AsyncStateScaffold]).
  final VoidCallback onSignInAgain;

  const NetWorthTab({
    super.key,
    required this.controller,
    required this.onSwitchMonth,
    required this.onEditAccountValue,
    required this.onManageAccounts,
    required this.onSignInAgain,
  });

  /// Opens the month picker and, if a month was chosen, switches to it through
  /// [onSwitchMonth] — the same guarded path the arrows use, so the stale-
  /// response guard still applies. No first/last bound, matching the arrows
  /// (a net worth value can be back-filled for any month).
  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showMonthPicker(
      context,
      initialMonth: monthDateTime(controller.selectedMonth),
    );
    if (picked == null) return;
    await onSwitchMonth(monthStringOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AsyncStateScaffold(
      isLoading:
          controller.status == FinanceStatus.loading && controller.monthly == null,
      isReauth: controller.status == FinanceStatus.needsReauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: onSignInAgain,
      builder: (context) {
        if (controller.status == FinanceStatus.error && controller.monthly == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.financeLoadFailed, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('networth-retry'),
                    onPressed: () => onSwitchMonth(controller.selectedMonth),
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final monthly = controller.monthly!;
        // Archived accounts leave the entry list but their past snapshots
        // keep counting toward the month's totals (the backend aggregates
        // them), so this filter is display-only.
        final active = controller.accounts.where((a) => !a.archived).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final valueByAccount = {
          for (final value in monthly.accounts) value.accountId: value.value,
        };
        // …which would otherwise leave the group total larger than the rows
        // above it with nothing on screen to explain the gap. Surfacing the
        // archived accounts' share as its own row keeps the arithmetic
        // visible without diverging from the backend's totals (and so from
        // the headline net worth).
        final activeIds = {for (final account in active) account.id};
        int archivedTotal(NetWorthKind kind) => monthly.accounts
            .where((v) => v.kind == kind && !activeIds.contains(v.accountId))
            .fold(0, (sum, v) => sum + v.value);

        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  MonthNavHeader(
                    monthLabel: monthYearLabel(
                      context,
                      monthDateTime(controller.selectedMonth),
                    ),
                    keyPrefix: 'networth-month',
                    onPickMonth: () => _pickMonth(context),
                    onPrevious: () =>
                        onSwitchMonth(previousMonth(controller.selectedMonth)),
                    onNext: () => onSwitchMonth(nextMonth(controller.selectedMonth)),
                  ),
                  const SizedBox(height: 16),
                  _NetWorthCard(monthly: monthly),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.networthManageAccounts,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        key: const Key('account-manage-button'),
                        tooltip: loc.networthManageAccounts,
                        icon: const Icon(Icons.tune),
                        onPressed: onManageAccounts,
                      ),
                    ],
                  ),
                  if (monthly.accounts.isEmpty)
                    // With no account to record against, "record a value" has
                    // nowhere to go — so the CTA points at the step that is
                    // actually missing (create an account) instead of being a
                    // dead button whose only escape is the tune icon.
                    _EmptyState(
                      ctaLabel: active.isEmpty
                          ? loc.networthManageAccounts
                          : loc.networthEmptyCta,
                      onCta: active.isEmpty
                          ? onManageAccounts
                          : () => onEditAccountValue(active.first),
                    ),
                  const SizedBox(height: 8),
                  _AccountGroup(
                    title: loc.networthAssetsTitle,
                    totalLabel: loc.networthTotalAssets,
                    total: monthly.totalAsset,
                    archivedTotal: archivedTotal(NetWorthKind.asset),
                    archivedKey: const Key('networth-archived-asset'),
                    accounts: active.where((a) => a.kind == NetWorthKind.asset).toList(),
                    valueByAccount: valueByAccount,
                    onTap: onEditAccountValue,
                  ),
                  const SizedBox(height: 16),
                  _AccountGroup(
                    title: loc.networthLiabilitiesTitle,
                    totalLabel: loc.networthTotalLiabilities,
                    total: monthly.totalLiability,
                    archivedTotal: archivedTotal(NetWorthKind.liability),
                    archivedKey: const Key('networth-archived-liability'),
                    accounts: active
                        .where((a) => a.kind == NetWorthKind.liability)
                        .toList(),
                    valueByAccount: valueByAccount,
                    onTap: onEditAccountValue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc.networthTrendTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _TrendSection(points: controller.trend),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The headline net worth figure plus its month-over-month growth. The growth
/// row is omitted entirely when the rate is null (the first recorded month, or
/// a non-positive prior net worth) — design.md: show the net worth alone
/// rather than a meaningless rate.
class _NetWorthCard extends StatelessWidget {
  final MonthlyNetWorth monthly;

  const _NetWorthCard({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final growth = monthly.growthRate;

    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.networthNetWorthLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            formatNetMinorUnitsForDisplay(monthly.netWorth, defaultCurrency),
            key: const Key('networth-net-value'),
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (growth != null) ...[
            const SizedBox(height: 8),
            _GrowthRow(growth: growth),
          ],
        ],
      ),
    );
  }
}

/// Arrow + direction word + percentage — the direction is never carried by
/// color alone (design.md accessibility).
class _GrowthRow extends StatelessWidget {
  final double growth;

  const _GrowthRow({required this.growth});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 0 is its own case: it is neither a rise nor a fall, so it gets a neutral
    // dash rather than an up arrow claiming growth that didn't happen.
    final flat = growth == 0;
    final rising = growth > 0;
    final color = flat
        ? theme.colorScheme.onSurfaceVariant
        : rising
        ? financeIncomeColor(theme.colorScheme)
        : theme.colorScheme.error;
    final percent = '${(growth * 100).abs().toStringAsFixed(1)}%';

    return Row(
      key: const Key('networth-growth'),
      children: [
        Icon(
          flat
              ? Icons.remove
              : rising
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          flat
              ? loc.networthGrowthFlat
              : rising
              ? loc.networthGrowthUp
              : loc.networthGrowthDown,
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
        const SizedBox(width: 6),
        Text(
          percent,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One asset/liability group: its accounts (tap a row to record that month's
/// value), the archived accounts' share of the month when there is one, and
/// the group's month total.
class _AccountGroup extends StatelessWidget {
  final String title;
  final String totalLabel;
  final int total;

  /// How much of [total] comes from archived accounts, which have no row of
  /// their own. Shown as its own row when non-zero so the listed values plus
  /// this add up to [total]; `0` hides the row entirely.
  final int archivedTotal;
  final Key archivedKey;
  final List<NetWorthAccount> accounts;
  final Map<String, int> valueByAccount;
  final void Function(NetWorthAccount account) onTap;

  const _AccountGroup({
    required this.title,
    required this.totalLabel,
    required this.total,
    required this.archivedTotal,
    required this.archivedKey,
    required this.accounts,
    required this.valueByAccount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        LedgeCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final account in accounts)
                ListTile(
                  key: Key('account-row-${account.id}'),
                  // The amount rides in the title row rather than in
                  // `trailing`: a `ListTile`'s trailing slot is laid out
                  // unconstrained, so at a 2x text scale the amount consumed
                  // the whole tile and the tile refused to lay out at all —
                  // an assertion, not a RenderFlex overflow. Inside the row
                  // the name wraps instead.
                  title: LabelValueRow(
                    gap: 12,
                    label: Text(account.name),
                    value: Text(
                      valueByAccount.containsKey(account.id)
                          ? formatMinorUnitsForDisplay(
                              valueByAccount[account.id]!,
                              defaultCurrency,
                            )
                          : loc.networthNotRecorded,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: valueByAccount.containsKey(account.id)
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  onTap: () => onTap(account),
                ),
              if (archivedTotal != 0)
                Padding(
                  key: archivedKey,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: LabelValueRow(
                    gap: 12,
                    label: Text(
                      loc.networthArchivedSubtotal,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: Text(
                      formatMinorUnitsForDisplay(archivedTotal, defaultCurrency),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                // The label wraps rather than pushing the amount out: at
                // 320dp/en the two ran 15px past the card even at a 1x text
                // scale.
                child: LabelValueRow(
                  gap: 12,
                  label: Text(totalLabel, style: theme.textTheme.bodyMedium),
                  value: Text(
                    formatMinorUnitsForDisplay(total, defaultCurrency),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The net worth trend line, or — below two points — the insufficient-data
/// note (design.md: never an empty chart).
class _TrendSection extends StatelessWidget {
  final List<NetWorthTrendPoint> points;

  const _TrendSection({required this.points});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (points.length < 2) {
      return Text(
        loc.networthTrendInsufficient,
        key: const Key('networth-trend-insufficient'),
        style: theme.textTheme.bodyMedium,
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].netWorth.toDouble()),
    ];

    return Semantics(
      label: loc.networthTrendSummary,
      child: SizedBox(
        key: const Key('networth-trend-chart'),
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(
                        // `YYYY-MM` -> `MM`, so 12 labels fit a phone width.
                        points[index].month.substring(5),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) => Text(
                    meta.formattedValue,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: theme.colorScheme.primary,
                barWidth: 3,
                dotData: FlDotData(show: points.length <= 14),
                belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The guide shown when the selected month holds no snapshot at all
/// (design.md — never a blank tab).
/// Tier 1: the month has no recorded account values, which is the whole of
/// what this tab shows for that month. Gains the icon and the standard
/// `titleMedium` heading; the 12dp gap before the action becomes the
/// standard 16. A `ListView` child, so no scroll of its own.
class _EmptyState extends StatelessWidget {
  final String ctaLabel;
  final VoidCallback onCta;

  const _EmptyState({required this.ctaLabel, required this.onCta});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EmptyStateGuide(
        stateKey: const Key('networth-empty-title'),
        icon: Icons.account_balance_outlined,
        title: loc.networthEmptyTitle,
        actions: [
          FilledButton(
            key: const Key('networth-empty-cta'),
            onPressed: onCta,
            child: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}
