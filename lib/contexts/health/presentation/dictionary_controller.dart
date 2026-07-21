import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/favorite_food.dart';
import '../application/list_favorites.dart';
import '../application/search_dictionary.dart';
import '../application/unfavorite_food.dart';
import '../domain/diet_exceptions.dart';
import '../domain/food_item.dart';

enum DictionaryStatus { loading, loaded, error, needsReauth }

/// Reasons loading the dictionary can fail, as understood by
/// [DictionaryScreen].
enum DictionaryError { fetchFailed, unknown }

/// Drives the Dictionary section: favorites (shown by default), search
/// results, and favoriting/unfavoriting. Search is debounced (D4 in
/// design.md): a keystroke resets a timer and the request only fires once
/// it settles, so typing no longer issues one request per keystroke.
class DictionaryController extends ChangeNotifier {
  final SearchDictionary _search;
  final ListFavorites _listFavorites;
  final FavoriteFood _favoriteFood;
  final UnfavoriteFood _unfavoriteFood;
  final Duration _searchDebounce;
  Timer? _debounceTimer;

  DictionaryController(
    this._search,
    this._listFavorites,
    this._favoriteFood,
    this._unfavoriteFood, {
    Duration searchDebounce = const Duration(milliseconds: 300),
  }) : _searchDebounce = searchDebounce;

  DictionaryStatus status = DictionaryStatus.loading;
  List<FoodItem> favorites = [];
  List<FoodItem> results = [];
  String query = '';
  DictionaryError? error;
  String? _idToken;

  Future<void> load(String idToken) async {
    _idToken = idToken;
    status = DictionaryStatus.loading;
    error = null;
    notifyListeners();

    try {
      favorites = await _listFavorites(idToken);
      status = DictionaryStatus.loaded;
    } on DietReauthenticationRequired {
      status = DictionaryStatus.needsReauth;
    } on DietFetchFailure {
      status = DictionaryStatus.error;
      error = DictionaryError.fetchFailed;
    } catch (_) {
      status = DictionaryStatus.error;
      error = DictionaryError.unknown;
    }
    notifyListeners();
  }

  /// Resets the search state (query + results) back to the favorites-only
  /// default, cancelling any pending debounced request. Called when a fresh
  /// food-search session opens so it never shows the previous session's
  /// leftover query and results. Favorites and status are left intact.
  void clearSearch() {
    _debounceTimer?.cancel();
    if (query.isEmpty && results.isEmpty) return;
    query = '';
    results = [];
    notifyListeners();
  }

  Future<void> search(String query) async {
    this.query = query;
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      results = [];
      notifyListeners();
      return;
    }
    final idToken = _idToken;
    if (idToken == null) return;

    final completer = Completer<void>();
    _debounceTimer = Timer(_searchDebounce, () async {
      try {
        results = await _search(idToken, query);
        status = DictionaryStatus.loaded;
        error = null;
      } on DietReauthenticationRequired {
        status = DictionaryStatus.needsReauth;
      } on DietFetchFailure {
        status = DictionaryStatus.error;
        error = DictionaryError.fetchFailed;
      } catch (_) {
        status = DictionaryStatus.error;
        error = DictionaryError.unknown;
      }
      notifyListeners();
      completer.complete();
    });
    return completer.future;
  }

  Future<void> toggleFavorite(FoodItem item, {required bool isFavorite}) async {
    final idToken = _idToken;
    if (idToken == null) return;
    try {
      if (isFavorite) {
        await _unfavoriteFood(idToken, item.id);
      } else {
        await _favoriteFood(idToken, item.id);
      }
      favorites = await _listFavorites(idToken);
      status = DictionaryStatus.loaded;
      error = null;
    } on DietReauthenticationRequired {
      status = DictionaryStatus.needsReauth;
    } on DietFetchFailure {
      status = DictionaryStatus.error;
      error = DictionaryError.fetchFailed;
    } catch (_) {
      status = DictionaryStatus.error;
      error = DictionaryError.unknown;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
