import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/finance_money.dart';
import '../domain/networth_account.dart';
import '../domain/networth_exposure.dart';
import 'networth_controller.dart';

Future<void> showExposureSettings(
  BuildContext context,
  NetWorthController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.9,
    child: _ExposureSettings(
      controller: controller,
      session: controller.exposureSession,
    ),
  ),
);

class _ExposureSettings extends StatelessWidget {
  final NetWorthController controller;
  final int session;
  const _ExposureSettings({required this.controller, required this.session});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final loc = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final current = session == controller.exposureSession;
      final status = controller.exposureSettingsStatus;
      final enabled =
          current &&
          status == ExposureSettingsStatus.ready &&
          !controller.exposureSaving;
      final assets = {
        for (final account in controller.accounts)
          if (account.kind == NetWorthKind.asset) account.id: account.name,
        for (final row in controller.monthly?.accounts ?? [])
          if (row.kind == NetWorthKind.asset) row.accountId: row.name,
      };
      final archivedIds = {
        for (final account in controller.accounts)
          if (account.archived) account.id,
      };
      final values = {
        for (final row in controller.monthly?.accounts ?? [])
          row.accountId: row.value,
      };
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.exposureSettings,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: loc.exposureClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (current &&
                (controller.exposureSaveFailed ||
                    controller.exposureSaving ||
                    status == ExposureSettingsStatus.loading ||
                    status == ExposureSettingsStatus.readFailed))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (status == ExposureSettingsStatus.loading)
                      Text(loc.exposureReading),
                    if (status == ExposureSettingsStatus.readFailed) ...[
                      Text(
                        loc.exposureReadFailed,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      OutlinedButton(
                        key: const Key('exposure-read-retry'),
                        onPressed: controller.reloadExposureSettings,
                        child: Text(loc.retry),
                      ),
                    ],
                    if (controller.exposureSaveFailed)
                      Text(
                        loc.exposureSaveFailed,
                        key: const Key('exposure-save-error'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    if (controller.exposureSaving) Text(loc.exposureSaving),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                key: const Key('exposure-settings-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (!current || status == ExposureSettingsStatus.unavailable)
                    Text(loc.exposureUnavailable)
                  else ...[
                    Text(loc.exposureLocalCaveat),
                    const SizedBox(height: 12),
                    Text(loc.exposureFactorGuide),
                    const SizedBox(height: 12),
                    if (assets.isEmpty) Text(loc.exposureNoAssets),
                    for (final entry in assets.entries) ...[
                      const SizedBox(height: 12),
                      LedgeCard(
                        key: Key('exposure-account-${entry.key}'),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              entry.value,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (archivedIds.contains(entry.key))
                              Text(loc.networthArchivedLabel),
                            Text(
                              values.containsKey(entry.key)
                                  ? formatMinorUnitsForDisplay(
                                      values[entry.key]!,
                                      defaultCurrency,
                                    )
                                  : loc.networthNotRecorded,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final factor in <ExposureFactor?>[
                                  null,
                                  ...ExposureFactor.values,
                                ])
                                  ChoiceChip(
                                    key: Key(
                                      'exposure-factor-${entry.key}-${factor?.multiplier ?? 'unknown'}',
                                    ),
                                    label: Text(
                                      factor == null
                                          ? loc.exposureUnknown
                                          : factor == ExposureFactor.cash
                                          ? loc.exposureCash
                                          : loc.exposureRatio(
                                              factor.multiplier.toString(),
                                            ),
                                    ),
                                    selected:
                                        controller.exposureFactors[entry.key] ==
                                        factor,
                                    onSelected: !enabled
                                        ? null
                                        : (_) => controller.saveExposureFactor(
                                            entry.key,
                                            factor,
                                            session: session,
                                          ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(loc.exposureFormula),
                    const SizedBox(height: 12),
                    Text(loc.exposureExamples),
                    const SizedBox(height: 12),
                    Text(loc.exposureSource, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
