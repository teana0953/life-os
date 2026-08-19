import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../domain/care_history_filter.dart';
import '../domain/care_item.dart';
import '../domain/care_today.dart';

String _categoryLabel(AppLocalizations loc, CareCategory category) =>
    switch (category) {
      CareCategory.medication => loc.careCategoryMedication,
      CareCategory.rehab => loc.careCategoryRehab,
      CareCategory.radiotherapyCare => loc.careCategoryRadiotherapyCare,
      CareCategory.custom => loc.careCategoryCustom,
    };

Set<T> _toggled<T>(Set<T> values, T value, bool selected) =>
    selected ? {...values, value} : ({...values}..remove(value));

String _statusLabel(AppLocalizations loc, CareTodayStatus status) =>
    switch (status) {
      CareTodayStatus.pending => loc.careHistoryStatusPending,
      CareTodayStatus.overdue => loc.careHistoryStatusOverdue,
      CareTodayStatus.done => loc.careHistoryStatusDone,
      CareTodayStatus.skipped => loc.careTodayStatusSkipped,
      CareTodayStatus.missed => loc.careTodayStatusMissed,
    };

/// The toolbar button that opens the filter sheet, badged with how many
/// selections are active — the sheet's contents are otherwise invisible once
/// it is closed.
class CareHistoryFilterButton extends StatelessWidget {
  final CareHistoryFilter filter;

  /// `null` disables the button (the screen gates it the same way it gates
  /// the period selector).
  final VoidCallback? onPressed;

  const CareHistoryFilterButton({
    super.key,
    required this.filter,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final count = filter.appliedCount;
    return IconButton(
      key: const Key('care-history-filter-button'),
      tooltip: loc.careHistoryFilterTitle,
      onPressed: onPressed,
      icon: Badge(
        key: const Key('care-history-filter-badge'),
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.filter_list),
      ),
    );
  }
}

/// The row of currently applied filters, each removable on its own, ending
/// in a clear-all action. Renders nothing at all when no filter is active,
/// so an unfiltered screen spends no height on it.
///
/// Horizontally scrollable rather than wrapped: at 320dp with a large text
/// scale a wrapped row of chips grows tall enough to squeeze the record list
/// out of the viewport, which is the thing this screen exists to show.
class CareHistoryAppliedFilters extends StatelessWidget {
  final CareHistoryFilter filter;
  final List<({String id, String title})> itemOptions;
  final ValueChanged<CareHistoryFilter> onChanged;

  const CareHistoryAppliedFilters({
    super.key,
    required this.filter,
    required this.itemOptions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (filter.isEmpty) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final itemId = filter.careItemId;
    return SizedBox(
      key: const Key('care-history-applied-filters'),
      // Scaled with the text, not a bare 48: at a large text scale the
      // chips' own label text needs more height than that, and a fixed
      // `SizedBox` clipped it.
      height: MediaQuery.textScalerOf(context).scale(48),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (itemId != null)
            _AppliedChip(
              chipKey: const Key('care-history-applied-item'),
              label: _itemTitle(loc, itemId),
              onRemoved: () => onChanged(filter.copyWith(clearCareItem: true)),
            ),
          for (final category in filter.categories)
            _AppliedChip(
              chipKey: Key('care-history-applied-category-${category.name}'),
              label: _categoryLabel(loc, category),
              onRemoved: () => onChanged(
                filter.copyWith(
                  categories: {...filter.categories}..remove(category),
                ),
              ),
            ),
          for (final status in filter.statuses)
            _AppliedChip(
              chipKey: Key('care-history-applied-status-${status.name}'),
              label: _statusLabel(loc, status),
              onRemoved: () => onChanged(
                filter.copyWith(statuses: {...filter.statuses}..remove(status)),
              ),
            ),
          Center(
            child: TextButton(
              key: const Key('care-history-applied-clear'),
              onPressed: () => onChanged(const CareHistoryFilter()),
              child: Text(loc.careHistoryFilterClearButton),
            ),
          ),
        ],
      ),
    );
  }

  /// The selected item's title. A period switch reloads a different range,
  /// which need not contain the filtered item at all — the chip then falls
  /// back to the generic group name rather than rendering a chip with no
  /// text (the user still has its ✕ and the clear-all to get out).
  String _itemTitle(AppLocalizations loc, String itemId) {
    for (final option in itemOptions) {
      if (option.id == itemId) return option.title;
    }
    return loc.careHistoryFilterItemLabel;
  }
}

class _AppliedChip extends StatelessWidget {
  final Key chipKey;
  final String label;
  final VoidCallback onRemoved;

  const _AppliedChip({
    required this.chipKey,
    required this.label,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Center(
      child: InputChip(
        key: chipKey,
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: onRemoved,
      ),
    ),
  );
}

/// Opens the filter sheet. Selections apply as they are made (the list
/// behind the sheet updates live via [onChanged]), so the sheet needs no
/// apply button — only the drag handle to dismiss.
///
/// A bottom sheet rather than a dialog: this repo has already hit mobile
/// dialogs being covered by the keyboard, and a sheet is the established
/// shape here.
Future<void> showCareHistoryFilterSheet(
  BuildContext context, {
  required CareHistoryFilter filter,
  required List<({String id, String title})> itemOptions,
  required ValueChanged<CareHistoryFilter> onChanged,
}) => showAppSheet<void>(
  context,
  builder: (_) => _FilterSheet(
    initialFilter: filter,
    itemOptions: itemOptions,
    onChanged: onChanged,
  ),
);

class _FilterSheet extends StatefulWidget {
  final CareHistoryFilter initialFilter;
  final List<({String id, String title})> itemOptions;
  final ValueChanged<CareHistoryFilter> onChanged;

  const _FilterSheet({
    required this.initialFilter,
    required this.itemOptions,
    required this.onChanged,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CareHistoryFilter _filter = widget.initialFilter;

  void _update(CareHistoryFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // No wrapping `SafeArea` here: `showAppSheet`'s `useSafeArea: true`
    // already applies `SafeArea(bottom: false)` (see its doc), leaving the
    // bottom inset to the sheet's own content — this repo's convention
    // (`care_today_screen.dart`) is to add the inset as padding directly,
    // not wrap a second `SafeArea` around it, which would apply the same
    // inset twice.
    return SingleChildScrollView(
      key: const Key('care-history-filter-sheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.careHistoryFilterTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('care-history-filter-clear'),
                onPressed: _filter.isEmpty
                    ? null
                    : () => _update(const CareHistoryFilter()),
                child: Text(loc.careHistoryFilterClearButton),
              ),
            ],
          ),
          if (widget.itemOptions.isNotEmpty) ...[
            _GroupLabel(loc.careHistoryFilterItemLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('care-history-filter-item-all'),
                  label: Text(loc.careHistoryFilterAllItems),
                  selected: _filter.careItemId == null,
                  onSelected: (_) =>
                      _update(_filter.copyWith(clearCareItem: true)),
                ),
                for (final option in widget.itemOptions)
                  ChoiceChip(
                    key: Key('care-history-filter-item-${option.id}'),
                    label: Text(option.title),
                    selected: _filter.careItemId == option.id,
                    // Re-tapping the selected item clears it, so the
                    // single-select group is escapable without hunting for
                    // the "all items" chip.
                    onSelected: (selected) => _update(
                      selected
                          ? _filter.copyWith(careItemId: option.id)
                          : _filter.copyWith(clearCareItem: true),
                    ),
                  ),
              ],
            ),
          ],
          _GroupLabel(loc.careCategoryLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in CareCategory.values)
                FilterChip(
                  key: Key('care-history-filter-category-${category.name}'),
                  label: Text(_categoryLabel(loc, category)),
                  selected: _filter.categories.contains(category),
                  onSelected: (selected) => _update(
                    _filter.copyWith(
                      categories: _toggled(
                        _filter.categories,
                        category,
                        selected,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _GroupLabel(loc.careHistoryFilterStatusLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in CareTodayStatus.values)
                FilterChip(
                  key: Key('care-history-filter-status-${status.name}'),
                  label: Text(_statusLabel(loc, status)),
                  selected: _filter.statuses.contains(status),
                  onSelected: (selected) => _update(
                    _filter.copyWith(
                      statuses: _toggled(_filter.statuses, status, selected),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
