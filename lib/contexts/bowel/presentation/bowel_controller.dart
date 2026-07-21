import 'package:flutter/foundation.dart';

import '../application/get_bowel_day.dart';
import '../application/save_bowel_day.dart';
import '../domain/bowel_day.dart';
import '../domain/bowel_exceptions.dart';

enum BowelStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the day's bowel record can fail, as understood by
/// [BowelScreen].
enum BowelError { fetchFailed, unknown }

/// Drives the bowel screen: loads a day's record into an editable draft
/// ([count]/[isNormal]/[note]) that the screen mutates locally, then upserts
/// the whole draft on [save]. Loading a (different) day resets the draft to
/// that day's saved state; a save failure leaves the draft untouched so the
/// user's entered values survive.
class BowelController extends ChangeNotifier {
  final GetBowelDay _getDay;
  final SaveBowelDay _saveDay;

  BowelController(this._getDay, this._saveDay);

  BowelStatus status = BowelStatus.loading;
  BowelError? error;

  /// The last successfully loaded/saved record, or `null` before the first
  /// successful load — the screen's "have data yet" signal (mirrors water).
  BowelDay? day;

  // Editable draft, populated on load/save and mutated by the screen.
  int count = 0;
  bool? isNormal;
  String note = '';

  Future<void> load(String idToken, String day) async {
    status = BowelStatus.loading;
    error = null;
    notifyListeners();

    try {
      _applyRecord(await _getDay(idToken, day));
      status = BowelStatus.loaded;
    } on BowelReauthenticationRequired {
      status = BowelStatus.needsReauth;
    } on BowelFetchFailure {
      status = BowelStatus.error;
      error = BowelError.fetchFailed;
    } catch (_) {
      status = BowelStatus.error;
      error = BowelError.unknown;
    }
    notifyListeners();
  }

  void setCount(int value) {
    count = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setIsNormal(bool? value) {
    isNormal = value;
    notifyListeners();
  }

  void setNote(String value) {
    note = value;
    notifyListeners();
  }

  /// Upserts the whole draft, then reflects the saved state. On failure the
  /// draft is left as-is (only a day change resets it) so entered values
  /// survive; a 401 surfaces [BowelStatus.needsReauth].
  Future<void> save(String idToken, String day) async {
    status = BowelStatus.saving;
    error = null;
    notifyListeners();

    try {
      _applyRecord(
        await _saveDay(
          idToken,
          day: day,
          count: count,
          isNormal: isNormal,
          note: note,
        ),
      );
      status = BowelStatus.loaded;
    } on BowelReauthenticationRequired {
      status = BowelStatus.needsReauth;
    } on BowelFetchFailure {
      status = BowelStatus.error;
      error = BowelError.fetchFailed;
    } catch (_) {
      status = BowelStatus.error;
      error = BowelError.unknown;
    }
    notifyListeners();
  }

  void _applyRecord(BowelDay record) {
    day = record;
    count = record.count;
    isNormal = record.isNormal;
    note = record.note;
  }
}
