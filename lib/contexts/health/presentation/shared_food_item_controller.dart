import 'package:flutter/foundation.dart';

import '../application/create_shared_food_item.dart';
import '../application/update_shared_food_item.dart';
import '../domain/diet_exceptions.dart';
import '../domain/food_item.dart';
import '../domain/shared_food_item_input.dart';
import '../domain/shared_food_item_patch.dart';

enum SharedFoodItemControllerStatus { idle, submitting }

/// Reasons a create/update submission can fail, as understood by
/// [SharedFoodItemSheet] (which has no [BuildContext]-free way to localize a
/// message here). [forbidden] is kept distinct from [saveFailed] so the
/// sheet can say "no permission" instead of a generic retryable message.
enum SharedFoodItemError { forbidden, saveFailed }

/// Drives [SharedFoodItemSheet]'s submit state (idle/submitting/typed
/// error) for both creating and editing a shared dictionary item.
class SharedFoodItemController extends ChangeNotifier {
  final CreateSharedFoodItem _createSharedFoodItem;
  final UpdateSharedFoodItem _updateSharedFoodItem;

  SharedFoodItemController(this._createSharedFoodItem, this._updateSharedFoodItem);

  SharedFoodItemControllerStatus status = SharedFoodItemControllerStatus.idle;
  SharedFoodItemError? error;

  Future<FoodItem?> create(String idToken, SharedFoodItemInput input) {
    return _submit(() => _createSharedFoodItem(idToken, input));
  }

  Future<FoodItem?> update(String idToken, String id, SharedFoodItemPatch patch) {
    return _submit(() => _updateSharedFoodItem(idToken, id, patch));
  }

  Future<FoodItem?> _submit(Future<FoodItem> Function() request) async {
    if (status == SharedFoodItemControllerStatus.submitting) return null;
    status = SharedFoodItemControllerStatus.submitting;
    error = null;
    notifyListeners();

    FoodItem? result;
    try {
      result = await request();
    } on DietForbidden {
      error = SharedFoodItemError.forbidden;
    } catch (_) {
      error = SharedFoodItemError.saveFailed;
    }
    status = SharedFoodItemControllerStatus.idle;
    notifyListeners();
    return result;
  }
}
