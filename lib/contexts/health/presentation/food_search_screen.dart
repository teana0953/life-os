import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/numeric_amount_field.dart';
import '../../auth/application/sign_out.dart';
import '../domain/food_item.dart';
import '../domain/portion_preview.dart';
import '../domain/portions.dart';
import 'amount_stepper.dart';
import 'create_meal_controller.dart';
import 'dictionary_controller.dart';
import 'meal_label.dart';
import 'portion_pills.dart';
import 'shared_food_item_controller.dart';
import 'shared_food_item_sheet.dart';
import 'snack_naming.dart';
import '../../../shared/auth/id_token_provider.dart';

/// The effective quantity previewed for a dictionary tray row: the entered
/// unit quantity, or (in measure mode) the measure-derived quantity via the
/// item's base amount — `null` when a measure amount can't yet be
/// converted.
double? _effectiveQuantity(TrayItem trayItem) {
  if (!trayItem.measureMode) return trayItem.amount;
  return quantityFromMeasure(trayItem.amount, trayItem.item.baseAmount);
}

/// A tray row's previewed portions: a dictionary row's per-unit × effective
/// quantity (`null` when the quantity can't be resolved yet — measure mode
/// with no valid conversion), or a manual row's entered portions directly.
Portions? _previewFor(TrayEntry entry) {
  switch (entry) {
    case TrayItem():
      final quantity = _effectiveQuantity(entry);
      if (quantity == null) return null;
      return previewPortionsForQuantity(entry.item, quantity);
    case ManualTrayItem():
      return entry.portions;
  }
}

/// Sums every tray entry's preview (treating an unresolved measure preview
/// as a zero contribution, rather than excluding the row) into a running
/// total.
Portions _trayTotal(List<TrayEntry> tray) {
  var staple = 0.0, meat = 0.0, fruit = 0.0, veg = 0.0;
  for (final entry in tray) {
    final preview = _previewFor(entry);
    if (preview == null) continue;
    staple += preview.staple;
    meat += preview.meat;
    fruit += preview.fruit;
    veg += preview.veg;
  }
  return Portions(staple: staple, meat: meat, fruit: fruit, veg: veg);
}

/// Full-screen food search + current-meal tray, pushed over the diet shell
/// either for a target [meal] (a standard meal code, an existing snack's
/// name, or the next snack name) or — when [meal] is null — as the food
/// dictionary, where the meal is asked for once at completion instead.
/// Replaces the old dictionary bottom sheet. Search results and favorites
/// come from the shared [DictionaryController]; the tray and submission are
/// owned by [CreateMealController], which the caller must have already reset
/// via `start(meal)` before pushing this screen.
class FoodSearchScreen extends StatefulWidget {
  final String? meal;

  /// The viewed day's existing meal group names, used only in dictionary
  /// mode to name the meal sheet's snack option — a snapshot taken by the
  /// caller at push time.
  final List<String> mealNames;

  final DictionaryController dictionaryController;
  final CreateMealController createMealController;
  final IdTokenProvider idToken;
  final String day;

  /// Signs the user out; wired to the needsReauth banner's "sign in again"
  /// control, mirroring `TodayScreen`/`HomeScreen`'s recovery exit.
  final SignOut signOut;

  /// Whether the current user is an administrator (design.md D2) — a plain
  /// bool, not a controller: this screen doesn't know or care how admin
  /// status is determined. Defaults to `false` so "unknown" never means
  /// "admin", and so every pre-existing construction of this screen (which
  /// predates admin entry points) keeps compiling.
  final bool isAdmin;

  /// Drives the create/edit shared-item bottom sheet's submit state.
  /// `null` when [isAdmin] is (and will stay) `false` for this screen's
  /// lifetime — the entry points that would need it aren't shown.
  final SharedFoodItemController? sharedFoodItemController;

  /// Requests that the caller ensure the profile (and so [isAdmin]) is
  /// loaded — called once, post-frame, from [initState] (design.md D2).
  /// The screen stays ignorant of `HomeController`; the wiring in app.dart
  /// supplies this.
  final VoidCallback? onNeedProfile;

  const FoodSearchScreen({
    super.key,
    required this.meal,
    this.mealNames = const <String>[],
    required this.dictionaryController,
    required this.createMealController,
    required this.idToken,
    required this.day,
    required this.signOut,
    this.isAdmin = false,
    this.sharedFoodItemController,
    this.onNeedProfile,
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  /// Owns the search field's text so a successful create can set it to the
  /// new item's name (design.md D7) — without this the field was a bare
  /// `TextField` with nothing able to set its text programmatically.
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.dictionaryController.addListener(_onChanged);
    widget.createMealController.addListener(_onChanged);
    widget.sharedFoodItemController?.addListener(_onChanged);
    // Post-frame: `HomeController.load` (behind `onNeedProfile`) notifies
    // synchronously before its first await, and this screen can be reached
    // mid router-stack-rebuild (e.g. the PWA-shortcut deep link), where a
    // synchronous notify during that build would throw.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onNeedProfile?.call());
  }

  @override
  void dispose() {
    widget.dictionaryController.removeListener(_onChanged);
    widget.createMealController.removeListener(_onChanged);
    widget.sharedFoodItemController?.removeListener(_onChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _openSharedFoodItemSheet({FoodItem? item}) async {
    final controller = widget.sharedFoodItemController;
    if (controller == null) return;
    final loc = AppLocalizations.of(context)!;
    final wasCreate = item == null;
    // Note on dismissal during an in-flight submit: the sheet's `PopScope`
    // blocks the barrier tap and the system back gesture (both route through
    // `Navigator.maybePop`), but NOT the drag handle, whose `onClosing` calls
    // `Navigator.pop` directly (Flutter's bottom_sheet.dart) and which stays
    // live for accessibility even with `enableDrag: false`. That is fine here:
    // `onSuccess` below is the *screen's* callback and survives the sheet, so
    // a drag-dismissed submit still reports its result.
    await showAppSheet<void>(
      context,
      builder: (sheetContext) => SharedFoodItemSheet(
        controller: controller,
        idToken: widget.idToken,
        item: item,
        onSuccess: (result) {
          // The sheet is usually still up; but a drag-dismiss during an
          // in-flight submit closes it early (its `onClosing` calls
          // `Navigator.pop` directly, bypassing the sheet's `PopScope`), so
          // this callback can arrive with the sheet's route already gone.
          // `sheetContext` is unusable by then (its element is deactivated,
          // so even `Navigator.maybeOf` throws), hence the mounted check on
          // THIS screen first: it outlives the sheet either way, and its own
          // navigator pops the sheet route when one is still there.
          if (!mounted) return;
          final navigator = Navigator.of(context);
          if (navigator.canPop()) navigator.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                wasCreate ? loc.sharedFoodItemCreateSuccess : loc.sharedFoodItemEditSuccess,
              ),
            ),
          );
          if (wasCreate) {
            _searchController.text = result.name;
            widget.dictionaryController.search(result.name);
          } else if (widget.dictionaryController.query.isEmpty) {
            widget.dictionaryController.load();
          } else {
            widget.dictionaryController.search(widget.dictionaryController.query);
          }
        },
      ),
    );
  }

  /// Asks which meal the tray belongs to (dictionary mode only), returning
  /// the chosen meal — or null if the sheet was dismissed without choosing,
  /// in which case nothing is saved.
  Future<String?> _askForMeal() {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // The snack option is named from the day's existing groups, so it
    // continues that day's series rather than colliding with it.
    final snack = nextSnackName(widget.mealNames, loc.dietSnackBaseName);
    return showModalBottomSheet<String>(
      context: context,
      // Not `showAppSheet`: none of its three options are set here. Opting
      // in would change three things — the picker keeps the default 9/16
      // cap, handles the overflow with its own `SafeArea` +
      // `SingleChildScrollView` below, and shows no drag handle (unlike
      // `care_history_screen.dart`'s picker, this one's options are the
      // whole content and a mis-grab would dismiss it).
      // A modal sheet is capped at 9/16 of the screen, which the title plus
      // four options can exceed on a short screen or at a large text scale —
      // and what gets cut off is the last option, the snack. Scrolling keeps
      // every meal reachable instead.
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  loc.dietChooseMealSheetTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final meal in standardMeals)
                ListTile(
                  key: Key('choose-meal-$meal'),
                  title: Text(mealDisplayLabel(loc, meal)),
                  onTap: () => Navigator.of(sheetContext).pop(meal),
                ),
              ListTile(
                key: const Key('choose-meal-snack'),
                title: Text(snack),
                onTap: () => Navigator.of(sheetContext).pop(snack),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// True from the moment a submit starts until it settles. Set
  /// **synchronously**, before the `await widget.idToken()`: the controller
  /// only flips to `submitting` once the token has resolved, so without this
  /// flag the done button stays enabled and silent for the whole token round
  /// trip and a second tap creates a second meal.
  bool _submitting = false;

  /// Submits the tray as one meal. Re-entrant calls (a second tap while one is
  /// in flight) are dropped.
  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // Opened as the dictionary, the meal isn't known until now — ask once,
      // for the whole tray, and save nothing if the user doesn't choose.
      if (widget.meal == null) {
        final chosen = await _askForMeal();
        // The screen (or its ancestor) can be disposed while the sheet is open
        // — e.g. sign-out flipping the app to the login screen, or the route
        // being popped — and a choice that comes back after that must not still
        // be saved.
        if (!mounted) return;
        if (chosen == null) return;
        widget.createMealController.bindMeal(chosen);
      }
      final success = await widget.createMealController.submit(
        await widget.idToken(),
        widget.day,
      );
      if (success && mounted && context.canPop()) context.pop(true);
    } finally {
      _submitting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openManualEntry() async {
    final result = await showDialog<(String, Portions)>(
      context: context,
      builder: (_) => const _ManualEntryDialog(),
    );
    if (result != null) {
      widget.createMealController.addManual(result.$1, result.$2);
    }
  }

  /// What fills the page below the search field. It always says what it is
  /// showing rather than going blank, because in dictionary mode the list is
  /// the whole page: a failure (with its recovery exit), the load still in
  /// flight, "you have no usual foods yet", "that search found nothing" — or
  /// the results themselves. The two empty states are kept apart on purpose:
  /// only the second one is the user's own search coming back empty, and only
  /// it offers [offerManualEntry] as the next step.
  Widget _resultsArea(
    AppLocalizations loc,
    ThemeData theme,
    List<FoodItem> results, {
    required bool showingFavorites,
    required bool offerManualEntry,
  }) {
    final dictionary = widget.dictionaryController;
    switch (dictionary.status) {
      case DictionaryStatus.needsReauth:
        return _ResultsMessage(
          stateKey: const Key('food-search-dictionary-reauth'),
          icon: Icons.lock_outline,
          title: loc.pleaseSignInAgain,
          action: OutlinedButton(
            key: const Key('food-search-dictionary-sign-in-again-button'),
            onPressed: widget.signOut.call,
            child: Text(loc.signInAgain),
          ),
        );
      case DictionaryStatus.error:
        return _ResultsMessage(
          stateKey: const Key('food-search-dictionary-error'),
          icon: Icons.cloud_off_outlined,
          title: loc.dietDictionaryLoadFailed,
          titleColor: theme.colorScheme.error,
        );
      case DictionaryStatus.loading:
        return const Center(
          child: CircularProgressIndicator(
            key: Key('food-search-dictionary-loading'),
          ),
        );
      case DictionaryStatus.loaded:
        break;
    }

    if (results.isEmpty) {
      if (showingFavorites) {
        return _ResultsMessage(
          stateKey: const Key('food-search-empty-favorites'),
          icon: Icons.favorite_border,
          title: loc.dietDictionaryFavoritesEmptyTitle,
          body: loc.dietDictionaryFavoritesEmptyBody,
        );
      }
      return _ResultsMessage(
        stateKey: const Key('food-search-empty-no-results'),
        icon: Icons.search_off,
        title: loc.dietDictionaryNoResultsTitle(dictionary.query),
        body: loc.dietDictionaryNoResultsBody,
        action: offerManualEntry
            ? FilledButton(
                key: const Key('food-search-empty-manual-entry-button'),
                onPressed: _openManualEntry,
                child: Text(loc.dietManualEntryLink),
              )
            : null,
      );
    }

    return ListView.builder(
      key: const Key('food-search-results'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final isFavorite = dictionary.favorites.any((f) => f.id == item.id);
        return ListTile(
          key: Key('food-search-result-${item.id}'),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: isFavorite
                    ? loc.dietUnfavoriteTooltip
                    : loc.dietFavoriteTooltip,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () =>
                    dictionary.toggleFavorite(item, isFavorite: isFavorite),
              ),
              // Admin-only, and only on shared items (design.md D3): a custom
              // item belongs to some other user, and editing it isn't
              // something the backend allows (404).
              if (widget.isAdmin && item.ownerUserId == null)
                PopupMenuButton<void>(
                  key: Key('food-search-result-menu-${item.id}'),
                  tooltip: loc.editSharedItemTooltip,
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      key: const Key('food-search-result-edit-item'),
                      onTap: () => _openSharedFoodItemSheet(item: item),
                      child: Text(loc.editSharedItemMenuLabel),
                    ),
                  ],
                ),
            ],
          ),
          onTap: () => widget.createMealController.add(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dictionary = widget.dictionaryController;
    final createMeal = widget.createMealController;

    final showingFavorites = dictionary.query.isEmpty;
    final results = showingFavorites ? dictionary.favorites : dictionary.results;
    final meal = widget.meal;
    // Browsing the dictionary with nothing picked yet is a lookup, not the
    // start of a recording, so the complete action and the manual-entry link
    // are hidden outright rather than merely disabled — a disabled complete
    // button would still say "this page is for recording". They reappear as
    // soon as the user adds something, i.e. once the intent to record is the
    // user's own. Opened for a target meal, both always show (unchanged).
    final showRecordingControls = meal != null || createMeal.tray.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          meal == null
              ? loc.dietDictionaryTitle
              : loc.dietAddToMealButton(mealDisplayLabel(loc, meal)),
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              key: const Key('food-search-create-button'),
              tooltip: loc.createSharedItemTooltip,
              icon: const Icon(Icons.add),
              onPressed: () => _openSharedFoodItemSheet(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              key: const Key('food-search-field'),
              controller: _searchController,
              decoration: InputDecoration(hintText: loc.dietSearchFoodHint),
              onChanged: dictionary.search,
            ),
          ),
          if (showRecordingControls)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('manual-entry-link'),
                  onPressed: _openManualEntry,
                  child: Text(loc.dietManualEntryLink),
                ),
              ),
            ),
          Expanded(
            child: _resultsArea(
              loc,
              theme,
              results,
              showingFavorites: showingFavorites,
              // The manual-entry way out belongs in the no-results state only
              // when it isn't already standing above the list — otherwise the
              // same escape hatch would appear twice.
              offerManualEntry: !showRecordingControls,
            ),
          ),
          if (createMeal.tray.isNotEmpty)
            _TrayPanel(controller: createMeal, loc: loc, theme: theme),
        ],
      ),
      bottomNavigationBar: showRecordingControls
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (createMeal.status ==
                        CreateMealControllerStatus.needsReauth) ...[
                      Text(
                        loc.pleaseSignInAgain,
                        key: const Key('food-search-reauth-message'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const Key('food-search-sign-in-again-button'),
                        onPressed: widget.signOut.call,
                        child: Text(loc.signInAgain),
                      ),
                      const SizedBox(height: 8),
                    ] else if (createMeal.status ==
                        CreateMealControllerStatus.error) ...[
                      Text(
                        loc.dietSaveMealFailed,
                        key: const Key('food-search-error-message'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      key: const Key('food-search-done-button'),
                      onPressed:
                          createMeal.tray.isEmpty ||
                              _submitting ||
                              createMeal.status ==
                                  CreateMealControllerStatus.submitting
                          ? null
                          : _submit,
                      child: Text(
                        loc.dietSearchDoneButton(createMeal.tray.length),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// One of [FoodSearchScreen]'s result-area states — an icon, a title, an
/// optional supporting line and an optional next step — filling the space the
/// results list would occupy. Scrollable so it survives a short viewport (a
/// focused keyboard on a small phone) rather than overflowing.
class _ResultsMessage extends StatelessWidget {
  final Key stateKey;
  final IconData icon;
  final String title;
  final String? body;
  final Color? titleColor;
  final Widget? action;

  const _ResultsMessage({
    required this.stateKey,
    required this.icon,
    required this.title,
    this.body,
    this.titleColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        key: stateKey,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// The current-meal tray shown at the bottom of [FoodSearchScreen]: a
/// running total pill (sum of every row's preview) and one row per tray
/// entry (dictionary or manual).
class _TrayPanel extends StatefulWidget {
  final CreateMealController controller;
  final AppLocalizations loc;
  final ThemeData theme;

  const _TrayPanel({required this.controller, required this.loc, required this.theme});

  @override
  State<_TrayPanel> createState() => _TrayPanelState();
}

class _TrayPanelState extends State<_TrayPanel> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// The last add signal this panel has already scrolled for, so a rebuild
  /// caused by a remove/amount change (which don't bump `addTick`) doesn't
  /// re-scroll to the end.
  late int _lastAddTick;

  /// Panel-level driver for the just-added row's fade. Because the fade's
  /// time source lives on the panel (not the row), a rebuild that remounts
  /// the just-added row — e.g. removing a row above it shifts it into a
  /// different index slot mid-fade — reads the fade's CURRENT value rather
  /// than restarting a fresh per-row animation, so the "added" cue can never
  /// replay on a delete. Restarted only when a genuine new add bumps
  /// `addTick`. `_fade` applies an easeInOut curve so the highlight holds
  /// briefly at full then eases away — a gentle glow rather than an abrupt
  /// flash; the row reads `_fade.value` (0 → 1) and renders alpha
  /// `0.18 * (1 - value)`.
  late final AnimationController _highlightController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _highlightController,
    curve: Curves.easeInOut,
  );

  /// Whether the platform asks to minimize motion (the OS "reduce motion"
  /// accessibility setting). When true the add feedback avoids animating:
  /// the tray jumps (not animates) to the newest item and the highlight fade
  /// is skipped, leaving no lingering highlight.
  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Guards the one-time initial fade for the row already present when the
  /// panel first mounts. `MediaQuery` isn't readable in `initState`, so the
  /// initial play is deferred to `didChangeDependencies`.
  bool _initialHighlightDone = false;

  @override
  void initState() {
    super.initState();
    _lastAddTick = widget.controller.addTick;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The panel only mounts once the tray is non-empty (i.e. after an add),
    // so play the fade for that first added row — once.
    if (!_initialHighlightDone && _lastAddTick != 0) {
      _initialHighlightDone = true;
      _playHighlight();
    }
  }

  @override
  void didUpdateWidget(_TrayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.addTick != _lastAddTick) {
      _lastAddTick = widget.controller.addTick;
      _playHighlight();
      _scrollToNewestAfterFrame();
    }
  }

  /// Runs the highlight fade for a new add, or skips it (leaving no lingering
  /// highlight) when the user prefers reduced motion.
  void _playHighlight() {
    if (_reduceMotion) {
      _highlightController.value = 1; // alpha 0 — no highlight, no motion
    } else {
      _highlightController.forward(from: 0);
    }
  }

  /// After the added row lays out, bring it into view — animating normally,
  /// or jumping instantly under reduced motion.
  void _scrollToNewestAfterFrame() {
    final reduceMotion = _reduceMotion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (reduceMotion) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _highlightController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final loc = widget.loc;
    final theme = widget.theme;
    final total = _trayTotal(controller.tray);

    return Container(
      key: const Key('food-search-tray'),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(loc.dietMealTotalLabel, style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: PortionPills(
                    key: const Key('food-search-total-pill'),
                    staple: total.staple,
                    meat: total.meat,
                    fruit: total.fruit,
                    veg: total.veg,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              key: const Key('food-search-tray-list'),
              controller: _scrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.tray.length,
              itemBuilder: (context, index) {
                final entry = controller.tray[index];
                final preview = _previewFor(entry) ?? const Portions(staple: 0, meat: 0, fruit: 0, veg: 0);
                final name = switch (entry) {
                  TrayItem() => entry.item.name,
                  ManualTrayItem() => entry.name,
                };
                final justAdded = identical(entry, controller.lastAdded);
                return Padding(
                  key: Key('tray-item-$index'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Stacked rows, never one wide Row: name + close on top, the
                  // preview pills on their own full-width line, then (for a
                  // dictionary row) the full AmountStepper below. Squeezing the
                  // pills into a Flexible slot beside the name compresses a
                  // pill below its intrinsic width and wraps its label into a
                  // rounded blob on narrow phones — the pills need a full line.
                  child: _withHighlight(justAdded, index, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: loc.dietRemoveItemTooltip,
                            icon: const Icon(Icons.close),
                            onPressed: () => controller.remove(entry),
                          ),
                        ],
                      ),
                      if (preview.staple != 0 ||
                          preview.meat != 0 ||
                          preview.fruit != 0 ||
                          preview.veg != 0)
                        PortionPills(
                          staple: preview.staple,
                          meat: preview.meat,
                          fruit: preview.fruit,
                          veg: preview.veg,
                        ),
                      if (entry is TrayItem)
                        AmountStepper(
                          value: entry.amount,
                          onChanged: (value) => controller.setAmount(entry, value),
                          unitLabel: loc.dietPortionUnit,
                          allowMeasure: entry.item.baseAmount != null && entry.item.measureUnit?.isNotEmpty == true,
                          measureMode: entry.measureMode,
                          measureLabel: measureLabelFor(entry.item.measureUnit, loc),
                          onModeChanged: (measureMode) =>
                              controller.toggleMeasure(entry, measureMode),
                        ),
                    ],
                  )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps the just-added row in a soft, theme-derived highlight that fades
  /// to transparent once (~0.9s). The fade is driven by the panel-level
  /// [_highlightController] (restarted on each new [addTick]), so the row
  /// reads the fade's current value rather than owning it: an index shift or
  /// remount mid-fade — e.g. a deleted row above shifts this one into a
  /// different index slot — continues the fade from where it was instead of
  /// replaying the "added" cue on a delete. Other rows pass through unwrapped
  /// so only the just-added one is ever highlighted.
  Widget _withHighlight(bool justAdded, int index, Widget child) {
    if (!justAdded) return child;
    final primary = widget.theme.colorScheme.primary;
    return AnimatedBuilder(
      animation: _fade,
      child: child,
      builder: (context, wrapped) => DecoratedBox(
        key: Key('tray-item-highlight-$index'),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.18 * (1 - _fade.value)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: wrapped,
      ),
    );
  }
}

/// Manual food-entry dialog: a name field + the four category portion
/// inputs (staple/meat/fruit/veg), following the numeric empty-zero
/// convention. Pops `(name, Portions)` on submit, `null` on cancel.
class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog();

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _name = TextEditingController();
  final _staple = TextEditingController();
  final _meat = TextEditingController();
  final _fruit = TextEditingController();
  final _veg = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _staple.dispose();
    _meat.dispose();
    _fruit.dispose();
    _veg.dispose();
    super.dispose();
  }

  double _parse(TextEditingController controller) => double.tryParse(controller.text) ?? 0;

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((
      name,
      Portions(
        staple: _parse(_staple),
        meat: _parse(_meat),
        fruit: _parse(_fruit),
        veg: _parse(_veg),
      ),
    ));
  }

  Widget _portionField(Key key, TextEditingController controller, String label) {
    return NumericAmountField(fieldKey: key, controller: controller, label: label);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(loc.dietManualEntryTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('manual-entry-name-field'),
              controller: _name,
              decoration: InputDecoration(labelText: loc.dietManualEntryNameLabel),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _portionField(const Key('manual-entry-staple-field'), _staple, loc.dietCategoryStaple),
                _portionField(const Key('manual-entry-meat-field'), _meat, loc.dietCategoryMeat),
                _portionField(const Key('manual-entry-fruit-field'), _fruit, loc.dietCategoryFruit),
                _portionField(const Key('manual-entry-veg-field'), _veg, loc.dietCategoryVeg),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('manual-entry-add-button'),
          onPressed: _submit,
          child: Text(loc.dietManualEntryAddButton),
        ),
      ],
    );
  }
}
