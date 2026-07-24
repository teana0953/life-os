import 'package:flutter/foundation.dart';

import '../application/care_items.dart';
import '../domain/care_item.dart';

enum CareItemsStatus { loading, loaded, error, reauth }

/// Drives [CareItemsScreen]: [load] fetches the list; [create], [update],
/// and [delete] each call their endpoint then reload the list (design D4)
/// so the screen always reflects server truth. A mutation failure keeps the
/// existing [items] and surfaces the typed error via [mutationError] without
/// changing [status] away from `loaded`; a 401 from any call (load or
/// mutation) routes [status] to [CareItemsStatus.reauth]. Holds typed
/// errors, not text — the owning screen maps them to localized copy.
class CareItemsController extends ChangeNotifier {
  final ListCareItems _list;
  final CreateCareItem _create;
  final UpdateCareItem _update;
  final DeleteCareItem _delete;

  CareItemsController(this._list, this._create, this._update, this._delete);

  CareItemsStatus status = CareItemsStatus.loading;
  List<CareItem> items = const [];
  Object? error;

  bool mutating = false;
  Object? mutationError;

  Future<void> _fetchList(String idToken) async {
    try {
      items = await _list(idToken);
      status = CareItemsStatus.loaded;
      error = null;
    } catch (e) {
      if (e is CareReauthRequired) {
        status = CareItemsStatus.reauth;
      } else {
        error = e;
        status = CareItemsStatus.error;
      }
    }
  }

  Future<void> load(String idToken) async {
    status = CareItemsStatus.loading;
    mutationError = null;
    notifyListeners();
    await _fetchList(idToken);
    notifyListeners();
  }

  /// Runs [action] (create/update/delete), then reloads the list (design
  /// D4). Guarded against re-entrancy — a second call while one is already
  /// in flight is ignored.
  Future<void> _mutate(String idToken, Future<void> Function() action) async {
    if (mutating) return;
    mutating = true;
    mutationError = null;
    notifyListeners();

    try {
      await action();
      await _fetchList(idToken);
    } catch (e) {
      if (e is CareReauthRequired) {
        status = CareItemsStatus.reauth;
      } else {
        // Keep the existing list — a mutation failure doesn't lose it.
        mutationError = e;
      }
    }
    mutating = false;
    notifyListeners();
  }

  Future<void> create(String idToken, CareItemDraft draft) =>
      _mutate(idToken, () => _create(idToken, draft));

  Future<void> update(String idToken, String id, CareItemUpdate changes) =>
      _mutate(idToken, () => _update(idToken, id, changes));

  Future<void> delete(String idToken, String id) =>
      _mutate(idToken, () => _delete(idToken, id));

  /// Clears a stale [mutationError] from a previous failed mutation so it
  /// doesn't linger and show up as soon as the form is reopened.
  void clearMutationError() {
    mutationError = null;
    notifyListeners();
  }
}
