import '../../contexts/body_profile/domain/weight_goal.dart';
import '../../contexts/bowel/domain/bowel_day.dart';
import '../../contexts/exercise/domain/exercise_day.dart';
import '../../contexts/exercise/infrastructure/http_exercise_repository.dart';
import '../../contexts/health/domain/daily_target.dart';
import '../../contexts/health/domain/day_meals_log.dart';
import '../../contexts/health/domain/food_item.dart';
import '../../contexts/health/infrastructure/http_food_dictionary_repository.dart';
import '../../contexts/health_calendar/domain/health_calendar.dart';
import '../../contexts/hydration/domain/water_day.dart';
import '../../contexts/menstrual/domain/menstrual_period.dart';
import '../../contexts/notifications/domain/care_history.dart';
import '../../contexts/notifications/domain/care_today.dart';
import '../../contexts/notifications/infrastructure/http_care_history_repository.dart';
import '../../contexts/notifications/infrastructure/http_care_today_repository.dart';
import '../../contexts/vitals/domain/vitals_day.dart';
import '../../contexts/vitals/domain/vitals_series.dart';
import 'section_outcome.dart';

/// The fourteen sections of `GET /api/health-overview`, each already decoded
/// into the domain value its card holds.
///
/// Every section's `data` is byte-for-byte the granular endpoint's body, so
/// each field below is decoded by the *same* decoder the granular repository
/// uses — a domain `fromJson` where one exists, and the public function
/// extracted from that repository where the decode used to be inline (design
/// D7). A section must never grow a second, parallel decoder here.
class HealthOverviewBatch {
  final SectionOutcome<WeightGoal> weightGoal;
  final SectionOutcome<VitalsRange> vitalsTrend;
  final SectionOutcome<HealthCalendar> healthCalendar;
  final SectionOutcome<DayMealsLog> meals;
  final SectionOutcome<DailyTargetWithRemaining> dailyTarget;
  final SectionOutcome<List<FoodItem>> favoriteFoodItems;
  final SectionOutcome<WaterDay> water;
  final SectionOutcome<BowelDay> bowel;
  final SectionOutcome<VitalsDay> vitals;
  final SectionOutcome<List<ExerciseActivity>> exerciseActivities;
  final SectionOutcome<ExerciseDay> exercise;
  final SectionOutcome<MenstrualOverview> menstrual;
  final SectionOutcome<CareToday> careToday;
  final SectionOutcome<List<CareHistoryDay>> careRange;

  const HealthOverviewBatch({
    required this.weightGoal,
    required this.vitalsTrend,
    required this.healthCalendar,
    required this.meals,
    required this.dailyTarget,
    required this.favoriteFoodItems,
    required this.water,
    required this.bowel,
    required this.vitals,
    required this.exerciseActivities,
    required this.exercise,
    required this.menstrual,
    required this.careToday,
    required this.careRange,
  });

  factory HealthOverviewBatch.fromJson(Map<String, dynamic> json) =>
      HealthOverviewBatch(
        weightGoal: decodeSection(
          json['weight_goal'],
          (data) => WeightGoal.fromJson(data as Map<String, dynamic>),
        ),
        vitalsTrend: decodeSection(
          json['vitals_trend'],
          (data) => VitalsRange.fromJson(data as Map<String, dynamic>),
        ),
        healthCalendar: decodeSection(
          json['health_calendar'],
          (data) => HealthCalendar.fromJson(data as Map<String, dynamic>),
        ),
        meals: decodeSection(
          json['meals'],
          (data) => DayMealsLog.fromJson(data as Map<String, dynamic>),
        ),
        dailyTarget: decodeSection(
          json['daily_target'],
          (data) =>
              DailyTargetWithRemaining.fromJson(data as Map<String, dynamic>),
        ),
        favoriteFoodItems: decodeSection(
          json['favorite_food_items'],
          (data) => foodItemsFromJson(data as List<dynamic>),
        ),
        water: decodeSection(
          json['water'],
          (data) => WaterDay.fromJson(data as Map<String, dynamic>),
        ),
        bowel: decodeSection(
          json['bowel'],
          (data) => BowelDay.fromJson(data as Map<String, dynamic>),
        ),
        vitals: decodeSection(
          json['vitals'],
          (data) => VitalsDay.fromJson(data as Map<String, dynamic>),
        ),
        exerciseActivities: decodeSection(
          json['exercise_activities'],
          (data) => exerciseActivitiesFromJson(data as Map<String, dynamic>),
        ),
        exercise: decodeSection(
          json['exercise'],
          (data) => ExerciseDay.fromJson(data as Map<String, dynamic>),
        ),
        menstrual: decodeSection(
          json['menstrual'],
          (data) => MenstrualOverview.fromJson(data as Map<String, dynamic>),
        ),
        careToday: decodeSection(
          json['care_today'],
          (data) => careTodayFromJson(data as Map<String, dynamic>),
        ),
        careRange: decodeSection(
          json['care_range'],
          (data) => careHistoryDaysFromJson(data as Map<String, dynamic>),
        ),
      );

  /// Every section carrying the outcome a *request-level* failure produces —
  /// re-auth for a `401`, unavailable for anything else — so the screen runs
  /// the one fan-out it always runs instead of a second failure path
  /// (design D5).
  factory HealthOverviewBatch.requestFailed({required bool reauth}) =>
      HealthOverviewBatch(
        weightGoal: requestFailureOutcome(reauth: reauth),
        vitalsTrend: requestFailureOutcome(reauth: reauth),
        healthCalendar: requestFailureOutcome(reauth: reauth),
        meals: requestFailureOutcome(reauth: reauth),
        dailyTarget: requestFailureOutcome(reauth: reauth),
        favoriteFoodItems: requestFailureOutcome(reauth: reauth),
        water: requestFailureOutcome(reauth: reauth),
        bowel: requestFailureOutcome(reauth: reauth),
        vitals: requestFailureOutcome(reauth: reauth),
        exerciseActivities: requestFailureOutcome(reauth: reauth),
        exercise: requestFailureOutcome(reauth: reauth),
        menstrual: requestFailureOutcome(reauth: reauth),
        careToday: requestFailureOutcome(reauth: reauth),
        careRange: requestFailureOutcome(reauth: reauth),
      );
}
