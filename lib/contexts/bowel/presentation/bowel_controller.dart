import 'package:flutter/foundation.dart';

import '../../../shared/screen_batch/section_outcome.dart';
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

  /// Injectable clock used to stamp [lastLoadedAt] on a successful load.
  /// Defaults to [DateTime.now]; tests pin it so the stamp is deterministic
  /// (mirrors the home greeting / reminders-throttle clocks).
  final DateTime Function() _clock;

  BowelController(
    this._getDay,
    this._saveDay, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  BowelStatus status = BowelStatus.loading;
  BowelError? error;

  /// When the day was last loaded successfully, or `null` before the first
  /// success — updated only on a successful [load], left unchanged on failure
  /// so it always reflects the data currently shown.
  DateTime? lastLoadedAt;

  /// The last successfully loaded/saved record, or `null` before the first
  /// successful load — the screen's "have data yet" signal (mirrors water).
  BowelDay? day;

  // Editable draft, populated on load/save and mutated by the screen.
  int count = 0;
  bool? isNormal;
  String note = '';

  /// Whether the draft differs from the last loaded/saved record — i.e. there
  /// are edits not yet persisted. False before the first load and right after a
  /// successful save. Drives the screen's unsaved-changes cue and Save button.
  bool get hasUnsavedChanges =>
      day != null &&
      (count != day!.count || isNormal != day!.isNormal || note != day!.note);

  /// Bumped by every [load] call, synchronously before its first `await` —
  /// an explicit-navigation generation counter [applyBatchSection] checks
  /// against [_claimedGeneration], not against the day itself.
  ///
  /// A day comparison (`this.day.day == day`) is what this replaced, and it
  /// over-corrected: comparing days strands the controller on whatever day
  /// it already happens to hold whenever a round's day differs from it —
  /// including the ordinary cases where nothing has navigated at all, e.g.
  /// the day rolling over at midnight, or a round catching a browsed-away
  /// tracker back up to today once the screen showing it is gone. The
  /// generation only moves on an explicit [load], so a round claimed after
  /// the last one is authoritative for whatever day it computed, whatever
  /// this controller currently holds — and a round claimed BEFORE a [load]
  /// that has since started or already landed is correctly refused, which is
  /// the case [applyBatchSection]'s tests guard.
  int _generation = 0;

  /// The generation a whole-screen batch round has claimed, via
  /// [claimBatchRound]. `null` (no round has claimed one yet) reads as "not
  /// claimed" in [applyBatchSection], so an unclaimed section is refused
  /// rather than accepted by accident.
  int? _claimedGeneration;

  /// Records the generation a whole-screen batch round is about to fetch
  /// for. Call synchronously, before the round's request goes out — mirrors
  /// [HealthCalendarController.claimBatchMonth].
  void claimBatchRound() => _claimedGeneration = _generation;

  Future<void> load(String idToken, String day) async {
    _generation++;
    status = BowelStatus.loading;
    error = null;
    notifyListeners();

    try {
      _applyRecord(await _getDay(idToken, day));
      status = BowelStatus.loaded;
      lastLoadedAt = _clock();
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

  /// Applies the health screen's batched `bowel` section, leaving this
  /// controller in the state [load] would have left it in for the same
  /// payload — including resetting the editable draft to the fetched record.
  void applyBatchSection(SectionOutcome<BowelDay> section) {
    if (_claimedGeneration != _generation) return;
    error = null;
    switch (section) {
      case SectionOk<BowelDay>(:final value):
        _applyRecord(value);
        status = BowelStatus.loaded;
        lastLoadedAt = _clock();
      case SectionUnavailable<BowelDay>():
        status = BowelStatus.error;
        error = BowelError.fetchFailed;
      case SectionReauth<BowelDay>():
        status = BowelStatus.needsReauth;
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
