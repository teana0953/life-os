import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/body_profile/infrastructure/http_body_profile_repository.dart';
import 'package:life_os/contexts/bowel/infrastructure/http_bowel_repository.dart';
import 'package:life_os/contexts/exercise/infrastructure/http_exercise_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_daily_target_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_food_dictionary_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_meal_repository.dart';
import 'package:life_os/contexts/health_calendar/infrastructure/http_health_calendar_repository.dart';
import 'package:life_os/contexts/hydration/infrastructure/http_water_repository.dart';
import 'package:life_os/contexts/menstrual/infrastructure/http_menstrual_repository.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_history_repository.dart';
import 'package:life_os/contexts/notifications/infrastructure/http_care_today_repository.dart';
import 'package:life_os/contexts/vitals/infrastructure/http_vitals_repository.dart';
import 'package:life_os/shared/screen_batch/health_overview_batch.dart';
import 'package:life_os/shared/screen_batch/section_outcome.dart';

import 'batch_fixtures.dart';

/// The batch section's `data` IS the granular endpoint's body, so every
/// section must decode to what that endpoint's own repository produces from
/// the identical payload (design D7). These are the guards that catch a
/// second, parallel decoder growing in the batch module: they feed one
/// fixture to both paths and compare the results.
void main() {
  const day = '2026-08-20';
  final body = healthOverviewBody();
  final batch = HealthOverviewBatch.fromJson(body);

  T okValue<T>(SectionOutcome<T> outcome) => (outcome as SectionOk<T>).value;

  http.Client serving(Object payload) =>
      MockClient((_) async => http.Response(jsonEncode(payload), 200));

  test('weight_goal matches the granular /api/weight-goal decode', () async {
    final granular = await HttpBodyProfileRepository(
      baseUrl: 'https://api.test',
      client: serving(weightGoalPayload),
    ).getWeightGoal('t');
    final section = okValue(batch.weightGoal);

    expect(section.heightCm, granular.heightCm);
    expect(section.targetWeightKg, granular.targetWeightKg);
    expect(section.currentWeightKg, granular.currentWeightKg);
    expect(section.remainingKg, granular.remainingKg);
    expect(section.achievementRate, granular.achievementRate);
    expect(section.bmi, granular.bmi);
  });

  test('vitals_trend matches the granular /api/vitals/range decode', () async {
    final payload = vitalsRangePayload(from: '2026-07-22', to: day);
    final granular = await HttpVitalsRepository(
      baseUrl: 'https://api.test',
      client: serving(payload),
    ).getRange('t', DateTime(2026, 7, 22), DateTime(2026, 8, 20));
    final section = okValue(batch.vitalsTrend);

    expect(section.from, granular.from);
    expect(section.to, granular.to);
    expect(
      section.series.systolic.map((p) => p.value).toList(),
      granular.series.systolic.map((p) => p.value).toList(),
    );
    expect(
      section.series.diastolic.map((p) => p.time).toList(),
      granular.series.diastolic.map((p) => p.time).toList(),
    );
  });

  test('health_calendar matches the granular decode', () async {
    final granular = await HttpHealthCalendarRepository(
      baseUrl: 'https://api.test',
      client: serving(healthCalendarPayload()),
    ).getCalendar('t', year: 2026, month: 8, today: day);
    final section = okValue(batch.healthCalendar);

    expect(section.year, granular.year);
    expect(section.month, granular.month);
    expect(section.loggedDays, granular.loggedDays);
    expect(section.daysElapsed, granular.daysElapsed);
    expect(section.loggingRate, granular.loggingRate);
    expect(section.dietAdherenceRate, granular.dietAdherenceRate);
  });

  test('meals matches the granular /api/meals decode', () async {
    final granular = await HttpMealRepository(
      baseUrl: 'https://api.test',
      client: serving(mealsPayload(day)),
    ).getDayMeals('t', day);
    final section = okValue(batch.meals);

    expect(section.day, granular.day);
    expect(section.meals.length, granular.meals.length);
    expect(section.totals.staple, granular.totals.staple);
    expect(section.totals.veg, granular.totals.veg);
  });

  test('daily_target matches the granular /api/daily-target decode', () async {
    final granular = await HttpDailyTargetRepository(
      baseUrl: 'https://api.test',
      client: serving(dailyTargetPayload(day)),
    ).getTarget('t', day);
    final section = okValue(batch.dailyTarget);

    expect(section.day, granular.day);
    expect(section.base.staple, granular.base.staple);
    expect(section.bonus.staple, granular.bonus.staple);
    expect(section.effective.staple, granular.effective.staple);
    expect(section.logged.meat, granular.logged.meat);
    expect(section.remaining.veg, granular.remaining.veg);
  });

  test('favorite_food_items matches the granular favorites decode', () async {
    final granular = await HttpFoodDictionaryRepository(
      baseUrl: 'https://api.test',
      client: serving(favoriteFoodItemsPayload),
    ).listFavorites('t');
    final section = okValue(batch.favoriteFoodItems);

    expect(section.map((f) => f.id).toList(), granular.map((f) => f.id).toList());
    expect(section.single.name, granular.single.name);
    expect(section.single.kcal, granular.single.kcal);
  });

  test('water matches the granular /api/water decode', () async {
    final granular = await HttpWaterRepository(
      baseUrl: 'https://api.test',
      client: serving(waterPayload(day)),
    ).getDay('t', day);
    final section = okValue(batch.water);

    expect(section.day, granular.day);
    expect(section.totalMl, granular.totalMl);
    expect(section.targetMl, granular.targetMl);
    expect(section.remainingMl, granular.remainingMl);
  });

  test('bowel matches the granular /api/bowel decode', () async {
    final granular = await HttpBowelRepository(
      baseUrl: 'https://api.test',
      client: serving(bowelPayload(day)),
    ).getDay('t', day);
    final section = okValue(batch.bowel);

    expect(section.day, granular.day);
    expect(section.count, granular.count);
    expect(section.isNormal, granular.isNormal);
    expect(section.note, granular.note);
  });

  test('vitals matches the granular /api/vitals decode', () async {
    final granular = await HttpVitalsRepository(
      baseUrl: 'https://api.test',
      client: serving(vitalsDayPayload(day)),
    ).getDay('t', day);
    final section = okValue(batch.vitals);

    expect(section.day, granular.day);
    expect(section.weightKg, granular.weightKg);
    expect(section.waistCm, granular.waistCm);
    expect(section.bpReadings, granular.bpReadings);
  });

  test('exercise_activities matches the granular decode', () async {
    final granular = await HttpExerciseRepository(
      baseUrl: 'https://api.test',
      client: serving(exerciseActivitiesPayload),
    ).listActivities('t');
    final section = okValue(batch.exerciseActivities);

    expect(section.map((a) => a.id).toList(), granular.map((a) => a.id).toList());
    expect(section.single.name, granular.single.name);
    expect(section.single.intensity, granular.single.intensity);
  });

  test('exercise matches the granular /api/exercise decode', () async {
    final granular = await HttpExerciseRepository(
      baseUrl: 'https://api.test',
      client: serving(exercisePayload(day)),
    ).getDay('t', day);
    final section = okValue(batch.exercise);

    expect(section.day, granular.day);
    expect(section.totalMinutes, granular.totalMinutes);
    expect(
      section.entries.map((e) => e.id).toList(),
      granular.entries.map((e) => e.id).toList(),
    );
    expect(section.entries.single.createdAt, granular.entries.single.createdAt);
  });

  test('menstrual matches the granular /api/menstrual decode', () async {
    final granular = await HttpMenstrualRepository(
      baseUrl: 'https://api.test',
      client: serving(menstrualPayload),
    ).getOverview('t');
    final section = okValue(batch.menstrual);

    expect(
      section.periods.map((p) => p.startDate).toList(),
      granular.periods.map((p) => p.startDate).toList(),
    );
    expect(section.stats.averageCycleDays, granular.stats.averageCycleDays);
    expect(section.stats.predictedNextStart, granular.stats.predictedNextStart);
    expect(section.lastPeriod?.id, granular.lastPeriod?.id);
  });

  test('care_today matches the granular /api/care/today decode', () async {
    final granular = await HttpCareTodayRepository(
      baseUrl: 'https://api.test',
      client: serving(careTodayPayload(day)),
    ).getToday('t');
    final section = okValue(batch.careToday);

    expect(section.date, granular.date);
    expect(section.slots.single.careScheduleId, granular.slots.single.careScheduleId);
    expect(section.slots.single.status, granular.slots.single.status);
    expect(section.slots.single.doseQuantity, granular.slots.single.doseQuantity);
  });

  test('care_range matches the granular /api/care/range decode', () async {
    final granular = await HttpCareHistoryRepository(
      baseUrl: 'https://api.test',
      client: serving(careRangePayload(from: '2026-07-22', to: day)),
    ).getRange('t', '2026-07-22', day);
    final section = okValue(batch.careRange);

    expect(section.map((d) => d.date).toList(), granular.map((d) => d.date).toList());
    expect(section.single.slots.single.status, granular.single.slots.single.status);
    expect(section.single.slots.single.title, granular.single.slots.single.title);
  });

  test('care_range preserves orphan records through the shared decoder', () {
    final orphanBody = healthOverviewBody();
    final section = orphanBody['care_range'] as Map<String, dynamic>;
    final data = section['data'] as Map<String, dynamic>;
    final days = data['days'] as List<dynamic>;
    final day = days.single as Map<String, dynamic>;
    final items = day['items'] as List<dynamic>;
    final item = items.single as Map<String, dynamic>;
    item['care_item_id'] = null;
    item['care_schedule_id'] = null;
    item['item_deleted'] = true;
    item['title'] = 'Deleted snapshot';

    final slot = okValue(
      HealthOverviewBatch.fromJson(orphanBody).careRange,
    ).single.slots.single;

    expect(slot.careItemId, isNull);
    expect(slot.careScheduleId, isNull);
    expect(slot.itemDeleted, isTrue);
    expect(slot.title, 'Deleted snapshot');
  });
}
