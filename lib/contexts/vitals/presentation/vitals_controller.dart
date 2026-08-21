import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../../../shared/screen_batch/section_outcome.dart';
import '../application/get_vitals_day.dart';
import '../application/save_vitals_day.dart';
import '../domain/vitals_day.dart';
import '../domain/vitals_exceptions.dart';

enum VitalsStatus { loading, loaded, saving, error, needsReauth }

/// Reasons loading/saving the day's vitals record can fail, as understood by
/// `VitalsScreen`.
enum VitalsError { fetchFailed, unknown }

/// Drives the vitals screen: loads a day's record into an editable draft (two
/// nullable scalars — [weightKg]/[bodyFatPct] — plus three mutable reading
/// lists) that the screen mutates locally, then upserts the whole draft on
/// [save]. Loading a (different) day resets the draft to that day's saved
/// state; a save failure leaves the draft untouched so entered values survive.
class VitalsController extends ChangeNotifier {
  final GetVitalsDay _getDay;
  final SaveVitalsDay _saveDay;

  /// Injectable clock used to default a newly added reading's time to "now".
  /// Defaults to [TimeOfDay.now]; tests pin it so "defaults to now" is
  /// deterministic.
  final TimeOfDay Function() _clock;

  /// Injectable wall-clock used to stamp [lastLoadedAt] on a successful load.
  /// Separate from [_clock] (a [TimeOfDay] for reading defaults); defaults to
  /// [DateTime.now]; tests pin it so the stamp is deterministic.
  final DateTime Function() _loadClock;

  VitalsController(
    this._getDay,
    this._saveDay, {
    TimeOfDay Function() clock = TimeOfDay.now,
    DateTime Function() loadClock = DateTime.now,
  }) : _clock = clock,
       _loadClock = loadClock;

  /// The current time as a strict ASCII "HH:mm" — manual zero-pad (NOT
  /// `formatTimeOfDay`, which can localize digits/separators) so the wire
  /// format the backend requires stays exact.
  String _nowHHmm() {
    final t = _clock();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  VitalsStatus status = VitalsStatus.loading;
  VitalsError? error;

  /// When the day was last loaded successfully, or `null` before the first
  /// success — updated only on a successful [load], left unchanged on failure
  /// so it always reflects the data currently shown.
  DateTime? lastLoadedAt;

  /// The last successfully loaded/saved record, or `null` before the first
  /// successful load — the screen's "have data yet" signal.
  VitalsDay? day;

  // Editable draft, populated on load/save and mutated by the screen.
  num? weightKg;
  num? bodyFatPct;
  num? waistCm;
  List<BpReading> bpReadings = [];
  List<GlucoseReading> glucoseReadings = [];
  List<Spo2Reading> spo2Readings = [];

  /// Whether the draft differs from the last loaded/saved record — i.e. there
  /// are edits not yet persisted. The reading lists are separate instances from
  /// the loaded [day]'s lists, so they are compared ELEMENT-WISE with
  /// [listEquals] (over the readings' value equality), never by identity.
  bool get hasUnsavedChanges =>
      day != null &&
      (weightKg != day!.weightKg ||
          bodyFatPct != day!.bodyFatPct ||
          waistCm != day!.waistCm ||
          !listEquals(bpReadings, day!.bpReadings) ||
          !listEquals(glucoseReadings, day!.glucoseReadings) ||
          !listEquals(spo2Readings, day!.spo2Readings));

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
    status = VitalsStatus.loading;
    error = null;
    notifyListeners();

    try {
      _applyRecord(await _getDay(idToken, day));
      status = VitalsStatus.loaded;
      lastLoadedAt = _loadClock();
    } on VitalsReauthenticationRequired {
      status = VitalsStatus.needsReauth;
    } on VitalsFetchFailure {
      status = VitalsStatus.error;
      error = VitalsError.fetchFailed;
    } catch (_) {
      status = VitalsStatus.error;
      error = VitalsError.unknown;
    }
    notifyListeners();
  }

  /// Applies the health screen's batched `vitals` section, leaving this
  /// controller in the state [load] would have left it in for the same
  /// payload — including resetting the editable draft to the fetched record.
  void applyBatchSection(SectionOutcome<VitalsDay> section) {
    if (_claimedGeneration != _generation) return;
    error = null;
    switch (section) {
      case SectionOk<VitalsDay>(:final value):
        _applyRecord(value);
        status = VitalsStatus.loaded;
        lastLoadedAt = _loadClock();
      case SectionUnavailable<VitalsDay>():
        status = VitalsStatus.error;
        error = VitalsError.fetchFailed;
      case SectionReauth<VitalsDay>():
        status = VitalsStatus.needsReauth;
    }
    notifyListeners();
  }

  void setWeight(num? value) {
    weightKg = value;
    notifyListeners();
  }

  void setBodyFat(num? value) {
    bodyFatPct = value;
    notifyListeners();
  }

  void setWaist(num? value) {
    waistCm = value;
    notifyListeners();
  }

  void addBpReading() {
    bpReadings = [
      ...bpReadings,
      BpReading(systolic: 0, diastolic: 0, pulse: null, time: _nowHHmm()),
    ];
    notifyListeners();
  }

  void updateBpReading(int index, BpReading reading) {
    bpReadings = [...bpReadings]..[index] = reading;
    notifyListeners();
  }

  void removeBpReading(int index) {
    bpReadings = [...bpReadings]..removeAt(index);
    notifyListeners();
  }

  void addGlucoseReading() {
    glucoseReadings = [
      ...glucoseReadings,
      GlucoseReading(label: '', value: 0, mealContext: null, time: _nowHHmm()),
    ];
    notifyListeners();
  }

  void updateGlucoseReading(int index, GlucoseReading reading) {
    glucoseReadings = [...glucoseReadings]..[index] = reading;
    notifyListeners();
  }

  void removeGlucoseReading(int index) {
    glucoseReadings = [...glucoseReadings]..removeAt(index);
    notifyListeners();
  }

  void addSpo2Reading() {
    spo2Readings = [
      ...spo2Readings,
      Spo2Reading(spo2: 0, pulse: null, time: _nowHHmm()),
    ];
    notifyListeners();
  }

  void updateSpo2Reading(int index, Spo2Reading reading) {
    spo2Readings = [...spo2Readings]..[index] = reading;
    notifyListeners();
  }

  void removeSpo2Reading(int index) {
    spo2Readings = [...spo2Readings]..removeAt(index);
    notifyListeners();
  }

  /// Upserts the whole draft, then reflects the saved state. On failure the
  /// draft is left as-is (only a day change resets it) so entered values
  /// survive; a 401 surfaces [VitalsStatus.needsReauth].
  Future<void> save(String idToken, String day) async {
    status = VitalsStatus.saving;
    error = null;
    notifyListeners();

    try {
      _applyRecord(
        await _saveDay(
          idToken,
          VitalsDay(
            day: day,
            weightKg: weightKg,
            bodyFatPct: bodyFatPct,
            waistCm: waistCm,
            bpReadings: bpReadings
                .where((r) => !_isEmptyBp(r))
                .map((r) => r.time.isEmpty ? r.copyWith(time: _nowHHmm()) : r)
                .toList(),
            glucoseReadings: glucoseReadings
                .where((r) => !_isEmptyGlucose(r))
                .map((r) => r.time.isEmpty ? r.copyWith(time: _nowHHmm()) : r)
                .toList(),
            spo2Readings: spo2Readings
                .where((r) => !_isEmptySpo2(r))
                .map((r) => r.time.isEmpty ? r.copyWith(time: _nowHHmm()) : r)
                .toList(),
          ),
        ),
      );
      status = VitalsStatus.loaded;
    } on VitalsReauthenticationRequired {
      status = VitalsStatus.needsReauth;
    } on VitalsFetchFailure {
      status = VitalsStatus.error;
      error = VitalsError.fetchFailed;
    } catch (_) {
      status = VitalsStatus.error;
      error = VitalsError.unknown;
    }
    notifyListeners();
  }

  /// An untouched, all-empty reading — dropped from the save payload so an
  /// accidental "Add" that was never filled in doesn't persist as a 0/0
  /// reading (the draft lists themselves are left untouched mid-edit).
  static bool _isEmptyBp(BpReading r) =>
      r.systolic == 0 && r.diastolic == 0 && r.pulse == null;
  static bool _isEmptyGlucose(GlucoseReading r) =>
      r.value == 0 && r.label.trim() == '';
  static bool _isEmptySpo2(Spo2Reading r) => r.spo2 == 0 && r.pulse == null;

  void _applyRecord(VitalsDay record) {
    day = record;
    weightKg = record.weightKg;
    bodyFatPct = record.bodyFatPct;
    waistCm = record.waistCm;
    bpReadings = [...record.bpReadings];
    glucoseReadings = [...record.glucoseReadings];
    spo2Readings = [...record.spo2Readings];
  }
}
