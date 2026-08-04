import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/date/day_format.dart';
import '../../../shared/widgets/async_state_scaffold.dart';
import '../../../shared/widgets/ledge_card.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/care_item.dart';
import 'care_item_form.dart';
import 'care_items_controller.dart';
import 'push_health_controller.dart';
import 'push_off_banner.dart';

const _categoryOrder = [
  CareCategory.medication,
  CareCategory.rehab,
  CareCategory.radiotherapyCare,
  CareCategory.custom,
];

String _categoryLabel(AppLocalizations loc, CareCategory category) =>
    switch (category) {
      CareCategory.medication => loc.careCategoryMedication,
      CareCategory.rehab => loc.careCategoryRehab,
      CareCategory.radiotherapyCare => loc.careCategoryRadiotherapyCare,
      CareCategory.custom => loc.careCategoryCustom,
    };

IconData _categoryIcon(CareCategory category) => switch (category) {
  CareCategory.medication => Icons.medication_outlined,
  CareCategory.rehab => Icons.fitness_center,
  CareCategory.radiotherapyCare => Icons.healing,
  CareCategory.custom => Icons.category_outlined,
};

String _weekdayShortLabel(AppLocalizations loc, int day) => switch (day) {
  0 => loc.weekdayShortSun,
  1 => loc.weekdayShortMon,
  2 => loc.weekdayShortTue,
  3 => loc.weekdayShortWed,
  4 => loc.weekdayShortThu,
  5 => loc.weekdayShortFri,
  _ => loc.weekdayShortSat,
};

String _weekdaysLabel(AppLocalizations loc, List<int> days) {
  if (days.isEmpty) return loc.careEveryDay;
  final sorted = List.of(days)..sort();
  return sorted.map((d) => _weekdayShortLabel(loc, d)).join(' ');
}

/// A single schedule's one-line summary: time · weekdays[empty=每天] ·
/// every-N-weeks · start date (when the interval makes it meaningful) ·
/// optional end date.
String _scheduleSummary(
  BuildContext context,
  AppLocalizations loc,
  CareSchedule schedule,
) {
  final buffer = StringBuffer(schedule.timeOfDay);
  buffer.write(' · ');
  buffer.write(_weekdaysLabel(loc, schedule.repeatDays));
  if (schedule.weekInterval > 1) {
    buffer.write(' ${loc.careWeekIntervalSuffix(schedule.weekInterval)}');
    // The start (anchor) date only matters once weekInterval > 1 — it's
    // what determines which weeks the schedule falls on (mirrors the form's
    // own start-date visibility rule).
    buffer.write(
      ' · ${loc.careScheduleFrom(mediumDateLabel(context, schedule.startDate))}',
    );
  }
  if (schedule.endDate != null) {
    buffer.write(
      ' · ${loc.careScheduleUntil(mediumDateLabel(context, schedule.endDate!))}',
    );
  }
  return buffer.toString();
}

String _formatStock(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// The care reminders list: reminders grouped by category (medication /
/// rehab / radiotherapy care / custom), each row showing its title, a note
/// snippet, a schedules summary, and — for medication — its stock; a FAB
/// opens the add form; tapping a row opens the edit form; delete requires
/// confirmation; an empty state guides the user to add one; a load reauth
/// shows a full-screen exit.
class CareItemsScreen extends StatefulWidget {
  final CareItemsController controller;
  final AuthRepository authRepository;

  /// Read-only: drives the push-off banner. Unlike the overview and 今日照護
  /// this screen shows it regardless of whether there are care slots today —
  /// reaching it already expresses intent to use reminders. Enabling/testing
  /// push remains `/reminders`'s job.
  final PushHealthController pushHealthController;

  const CareItemsScreen({
    super.key,
    required this.controller,
    required this.authRepository,
    required this.pushHealthController,
  });

  @override
  State<CareItemsScreen> createState() => _CareItemsScreenState();
}

class _CareItemsScreenState extends State<CareItemsScreen> {
  String _idToken = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.pushHealthController.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.pushHealthController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    _idToken = await widget.authRepository.idToken() ?? '';
    if (!mounted) return;
    await widget.controller.load(_idToken);
  }

  Future<void> _openForm({CareItem? existing}) {
    widget.controller.clearMutationError();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CareItemForm(
          controller: widget.controller,
          idToken: _idToken,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CareItem item) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.careDeleteConfirmTitle),
        content: Text(loc.careDeleteConfirmMessage),
        actions: [
          TextButton(
            key: const Key('care-item-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.careCancelButton),
          ),
          FilledButton(
            key: const Key('care-item-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.careDeleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.delete(_idToken, item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final appBar = AppBar(
      title: Text(loc.careRemindersTitle),
      actions: [
        IconButton(
          key: const Key('care-items-history-button'),
          tooltip: loc.careHistoryEntryTooltip,
          onPressed: () => context.push('/care-history'),
          icon: const Icon(Icons.history),
        ),
      ],
    );

    return AsyncStateScaffold(
      isLoading: controller.status == CareItemsStatus.loading,
      isReauth: controller.status == CareItemsStatus.reauth,
      reauthMessage: loc.pleaseSignInAgain,
      onSignInAgain: () => unawaited(widget.authRepository.signOut()),
      appBar: appBar,
      builder: (context) {
        final theme = Theme.of(context);

        if (controller.status == CareItemsStatus.error) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.careErrorGeneric,
                    key: const Key('care-items-load-error'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('care-items-retry-button'),
                    onPressed: () => controller.load(_idToken),
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final grouped = <CareCategory, List<CareItem>>{
          for (final category in _categoryOrder)
            category: controller.items
                .where((item) => item.category == category)
                .toList(),
        };

        return Scaffold(
          appBar: appBar,
          floatingActionButton: FloatingActionButton(
            key: const Key('care-items-add-fab'),
            onPressed: () => _openForm(),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (controller.mutationError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          loc.careErrorGeneric,
                          key: const Key('care-items-mutation-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    PushOffBanner(health: widget.pushHealthController.health),
                    if (controller.items.isEmpty)
                      _EmptyState(onAdd: () => _openForm())
                    else
                      for (final category in _categoryOrder)
                        if (grouped[category]!.isNotEmpty)
                          _CategoryGroup(
                            category: category,
                            items: grouped[category]!,
                            mutating: controller.mutating,
                            onTap: (item) => _openForm(existing: item),
                            onDelete: _confirmDelete,
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final CareCategory category;
  final List<CareItem> items;
  final bool mutating;
  final ValueChanged<CareItem> onTap;
  final ValueChanged<CareItem> onDelete;

  const _CategoryGroup({
    required this.category,
    required this.items,
    required this.mutating,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(category), size: 18),
              const SizedBox(width: 6),
              Text(
                _categoryLabel(loc, category),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgeCard(
                child: ListTile(
                  key: Key('care-item-row-${item.id}'),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.note != null && item.note!.isNotEmpty)
                        Text(
                          item.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      for (final schedule in item.schedules)
                        Text(_scheduleSummary(context, loc, schedule)),
                      if (item.category == CareCategory.medication &&
                          item.stock != null)
                        Text(loc.careStockLabel(_formatStock(item.stock!))),
                    ],
                  ),
                  onTap: mutating ? null : () => onTap(item),
                  trailing: IconButton(
                    key: Key('care-item-delete-${item.id}'),
                    onPressed: mutating ? null : () => onDelete(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return LedgeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        key: const Key('care-items-empty-state'),
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(loc.careRemindersEmptyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            loc.careRemindersEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('care-items-empty-add-button'),
            onPressed: onAdd,
            child: Text(loc.careRemindersAddButton),
          ),
        ],
      ),
    );
  }
}
