import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

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

  VitalsController(
    this._getDay,
    this._saveDay, {
    TimeOfDay Function() clock = TimeOfDay.now,
  }) : _clock = clock;

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

  /// The last successfully loaded/saved record, or `null` before the first
  /// successful load — the screen's "have data yet" signal.
  VitalsDay? day;

  // Editable draft, populated on load/save and mutated by the screen.
  num? weightKg;
  num? bodyFatPct;
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
          !listEquals(bpReadings, day!.bpReadings) ||
          !listEquals(glucoseReadings, day!.glucoseReadings) ||
          !listEquals(spo2Readings, day!.spo2Readings));

  Future<void> load(String idToken, String day) async {
    status = VitalsStatus.loading;
    error = null;
    notifyListeners();

    try {
      _applyRecord(await _getDay(idToken, day));
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

  void setWeight(num? value) {
    weightKg = value;
    notifyListeners();
  }

  void setBodyFat(num? value) {
    bodyFatPct = value;
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
    bpReadings = [...record.bpReadings];
    glucoseReadings = [...record.glucoseReadings];
    spo2Readings = [...record.spo2Readings];
  }
}
