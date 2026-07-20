import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/food_item.dart';
import 'dictionary_controller.dart';
import 'portion_pills.dart';

/// Which list the dictionary screen is currently showing (D1 in design.md):
/// an explicit tab replacing the old implicit "empty query -> favorites"
/// switch. The controller's `query`/`results`/`favorites` state is
/// untouched — this only selects which existing list to display.
enum _DictionaryTab { all, favorites }

/// Dictionary section: search the food dictionary, view/toggle favorites,
/// and pick an item to log via [onSelectItem].
class DictionaryScreen extends StatefulWidget {
  final DictionaryController controller;
  final ValueChanged<FoodItem>? onSelectItem;

  /// Called when the user taps the "can't find it? log manually"
  /// affordance at the bottom of the screen (D1 in design.md).
  final VoidCallback? onManualEntry;

  /// Browse-without-logging mode (D3 in design.md): a row tap does NOT call
  /// [onSelectItem] (there is no food-detail view to open either — search +
  /// list + favorites only). The favorite toggle is unaffected, since it's
  /// a separate trailing control from the row's own `onTap`.
  final bool browseOnly;

  /// Compact mode for when vertical space is tight (the add-food sheet with the
  /// on-screen keyboard open): hides the all/favorites tab selector and shows
  /// the search results directly, so the search field + results get the room.
  final bool compact;

  const DictionaryScreen({
    super.key,
    required this.controller,
    this.onSelectItem,
    this.onManualEntry,
    this.browseOnly = false,
    this.compact = false,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  // Default landing tab is Favorites, so the initial screen isn't empty.
  _DictionaryTab _tab = _DictionaryTab.favorites;

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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (controller.status == DictionaryStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(body: SafeArea(child: _buildList(loc, theme, controller)));
  }

  Widget _buildList(
    AppLocalizations loc,
    ThemeData theme,
    DictionaryController controller,
  ) {
    // In compact mode (keyboard open, tight sheet) the tab selector is hidden
    // and we always show the search results, so typing surfaces matches
    // without the favorites tab eating the little vertical space there is.
    final showingFavorites =
        !widget.compact && _tab == _DictionaryTab.favorites;
    final items = showingFavorites ? controller.favorites : controller.results;
    final showAllPrompt = !showingFavorites && controller.query.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<_DictionaryTab>(
              key: const Key('dictionary-tab-selector'),
              segments: [
                ButtonSegment(
                  value: _DictionaryTab.all,
                  label: Text(loc.dietTabAll),
                ),
                ButtonSegment(
                  value: _DictionaryTab.favorites,
                  icon: const Icon(Icons.favorite),
                  label: Text(loc.dietFavoritesTitle),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('dictionary-search-field'),
            decoration: InputDecoration(hintText: loc.dietSearchFoodHint),
            onChanged: controller.search,
          ),
        ),
        if (showAllPrompt)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  loc.dietSearchAllPrompt,
                  key: const Key('dictionary-search-prompt'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isFavorite = controller.favorites.any(
                  (f) => f.id == item.id,
                );
                return ListTile(
                  title: Text(item.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: PortionPills(
                      staple: item.staple,
                      meat: item.meat,
                      fruit: item.fruit,
                      veg: item.veg,
                    ),
                  ),
                  onTap: widget.browseOnly
                      ? null
                      : () => widget.onSelectItem?.call(item),
                  trailing: IconButton(
                    tooltip: isFavorite
                        ? loc.dietUnfavoriteTooltip
                        : loc.dietFavoriteTooltip,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    onPressed: () => controller.toggleFavorite(
                      item,
                      isFavorite: isFavorite,
                    ),
                  ),
                );
              },
            ),
          ),
        if (widget.onManualEntry != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              key: const Key('dictionary-manual-entry-button'),
              onPressed: widget.onManualEntry,
              child: Text(loc.dietManualEntryAffordance),
            ),
          ),
      ],
    );
  }
}
