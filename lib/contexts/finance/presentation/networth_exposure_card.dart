import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../domain/finance_money.dart';
import '../domain/networth_exposure.dart';
import 'networth_controller.dart';
import 'networth_exposure_settings.dart';

class NetWorthExposureCard extends StatelessWidget {
  final NetWorthController controller;
  const NetWorthExposureCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final result = controller.exposure!;
    final names = {
      for (final account in controller.accounts) account.id: account.name,
      for (final row in controller.monthly!.accounts) row.accountId: row.name,
    };
    final settingsStatus = controller.exposureSettingsStatus;
    return LedgeCard(
      key: const Key('networth-exposure-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc.exposureTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (result.status == ExposureStatus.empty)
            Text(loc.exposureEmpty)
          else if (result.status == ExposureStatus.unrecorded)
            Text(loc.exposureUnrecorded),
          if (result.unrecordedAccountIds.isNotEmpty)
            Text(
              loc.exposureMissingAccounts(
                result.unrecordedAccountIds
                    .map((id) => names[id] ?? id)
                    .join(', '),
              ),
              key: const Key('exposure-missing-balances'),
            ),
          if (settingsStatus == ExposureSettingsStatus.loading)
            Text(loc.exposureReading)
          else if (settingsStatus == ExposureSettingsStatus.readFailed) ...[
            Text(
              loc.exposureReadFailed,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            OutlinedButton(
              onPressed: controller.reloadExposureSettings,
              child: Text(loc.retry),
            ),
          ] else if (settingsStatus == ExposureSettingsStatus.unavailable)
            Text(loc.exposureUnavailable)
          else ...[
            if (result.unclassifiedAccountIds.isNotEmpty)
              Text(
                loc.exposureUnknownAccounts(
                  result.unclassifiedAccountIds
                      .map((id) => names[id] ?? id)
                      .join(', '),
                ),
              ),
            if (result.status == ExposureStatus.complete) ...[
              Text(loc.exposureTotal, style: theme.textTheme.titleMedium),
              Text(
                formatMinorUnitsForDisplay(
                  result.totalExposure!,
                  defaultCurrency,
                ),
                key: const Key('exposure-total'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(loc.exposureLeverage, style: theme.textTheme.titleMedium),
              if (result.leverage case final ratio?)
                Text(
                  loc.exposureRatio(ratio.toStringAsFixed(2)),
                  key: const Key('exposure-ratio'),
                  style: theme.textTheme.headlineSmall,
                )
              else
                Text(loc.exposureNoRatio, key: const Key('exposure-no-ratio')),
            ],
          ],
          if (controller.exposureSaveFailed)
            Text(
              loc.exposureSaveFailed,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('exposure-settings-button'),
            onPressed: () => showExposureSettings(context, controller),
            child: Text(loc.exposureSettings, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          Text(loc.exposureLocalCaveat, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
