import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_month.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/split/domain/split_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/shared/date/day_format.dart';
import 'package:life_os/shared/screen_batch/health_overview_batch.dart';
import 'package:life_os/shared/screen_batch/screen_batch_exceptions.dart';
import 'package:life_os/shared/screen_batch/home_summary_batch.dart';
import 'package:life_os/shared/screen_batch/screen_batch_repository.dart';
import 'package:life_os/shared/screen_batch/section_outcome.dart';

/// A [ScreenBatchRepository] that answers each section from the *same*
/// repository fake the granular path would have used.
///
/// This is what the real endpoints do — the backend's own spec requires each
/// section's `data` to be the granular endpoint's body, computed by the same
/// use case — so a widget test wired with it observes exactly the reads the
/// fifteen-request version made, one per section, and keeps counting them the
/// way it always did.
///
/// Sections run concurrently and each records its own outcome, like the
/// server's fan-out: one repository that throws fails one section, and one
/// repository that blocks holds the whole response (there is only one
/// response now).
class RepositoryBackedScreenBatchRepository implements ScreenBatchRepository {
  final BodyProfileRepository bodyProfile;
  final VitalsRepository vitals;
  final HealthCalendarRepository healthCalendar;
  final MealRepository meals;
  final DailyTargetRepository dailyTarget;
  final FoodDictionaryRepository foodDictionary;
  final WaterRepository water;
  final BowelRepository bowel;
  final ExerciseRepository exercise;
  final MenstrualRepository menstrual;
  final CareTodayRepository careToday;
  final CareHistoryRepository careHistory;
  /// Only the home round reads these two; a rig that never asks for a home
  /// summary can leave them out.
  final FinanceRepository? finance;
  final SplitRepository? split;

  /// Every `getHealthOverview` this fake served, in order — the recorded
  /// request list a "one request" guard needs.
  final List<({String day, int trendDays, int careDays})> healthCalls = [];
  final List<({String day, int trendDays})> homeCalls = [];

  RepositoryBackedScreenBatchRepository({
    required this.bodyProfile,
    required this.vitals,
    required this.healthCalendar,
    required this.meals,
    required this.dailyTarget,
    required this.foodDictionary,
    required this.water,
    required this.bowel,
    required this.exercise,
    required this.menstrual,
    required this.careToday,
    required this.careHistory,
    this.finance,
    this.split,
  });

  static Future<SectionOutcome<T>> _section<T>(Future<T> Function() run) =>
      HomeSummaryFromRepositories.section(run);

  @override
  Future<HealthOverviewBatch> getHealthOverview(
    String idToken, {
    required String day,
    required int trendDays,
    required int careDays,
  }) async {
    healthCalls.add((day: day, trendDays: trendDays, careDays: careDays));
    final trendRange = dayRangeEndingOn(trendDays, parseDayString(day));
    final careRangeDays = dayRangeEndingOn(careDays, parseDayString(day));
    final month = parseDayString(day);

    final weightGoal = _section(() => bodyProfile.getWeightGoal(idToken));
    final vitalsTrend = _section(
      () => vitals.getRange(
        idToken,
        parseDayString(trendRange.from),
        parseDayString(trendRange.to),
      ),
    );
    final calendar = _section(
      () => healthCalendar.getCalendar(
        idToken,
        year: month.year,
        month: month.month,
        today: day,
      ),
    );
    final dayMeals = _section(() => meals.getDayMeals(idToken, day));
    final target = _section(() => dailyTarget.getTarget(idToken, day));
    final favorites = _section(() => foodDictionary.listFavorites(idToken));
    final waterDay = _section(() => water.getDay(idToken, day));
    final bowelDay = _section(() => bowel.getDay(idToken, day));
    final vitalsDay = _section(() => vitals.getDay(idToken, day));
    final activities = _section(() => exercise.listActivities(idToken));
    final exerciseDay = _section(() => exercise.getDay(idToken, day));
    final overview = _section(() => menstrual.getOverview(idToken));
    final today = _section(() => careToday.getToday(idToken));
    final range = _section(
      () =>
          careHistory.getRange(idToken, careRangeDays.from, careRangeDays.to),
    );

    return HealthOverviewBatch(
      weightGoal: await weightGoal,
      vitalsTrend: await vitalsTrend,
      healthCalendar: await calendar,
      meals: await dayMeals,
      dailyTarget: await target,
      favoriteFoodItems: await favorites,
      water: await waterDay,
      bowel: await bowelDay,
      vitals: await vitalsDay,
      exerciseActivities: await activities,
      exercise: await exerciseDay,
      menstrual: await overview,
      careToday: await today,
      careRange: await range,
    );
  }

  @override
  Future<HomeSummaryBatch> getHomeSummary(
    String idToken, {
    required String day,
    required int trendDays,
  }) {
    homeCalls.add((day: day, trendDays: trendDays));
    return HomeSummaryFromRepositories(
      bodyProfile: bodyProfile,
      vitals: vitals,
      menstrual: menstrual,
      finance: finance!,
      split: split!,
      dailyTarget: dailyTarget,
    ).getHomeSummary(idToken, day: day, trendDays: trendDays);
  }
}

/// The home half on its own, for the dashboard tests whose one fake
/// implements the six repositories the home round reads and nothing else.
class HomeSummaryFromRepositories implements ScreenBatchRepository {
  final BodyProfileRepository bodyProfile;
  final VitalsRepository vitals;
  final MenstrualRepository menstrual;
  final FinanceRepository finance;
  final SplitRepository split;
  final DailyTargetRepository dailyTarget;

  /// Every `getHomeSummary` this fake served, in order.
  final List<({String day, int trendDays})> homeCalls = [];

  HomeSummaryFromRepositories({
    required this.bodyProfile,
    required this.vitals,
    required this.menstrual,
    required this.finance,
    required this.split,
    required this.dailyTarget,
  });

  /// One object implementing all six — the shape every home-dashboard fake in
  /// this repo already has.
  factory HomeSummaryFromRepositories.combined(Object repositories) =>
      HomeSummaryFromRepositories(
        bodyProfile: repositories as BodyProfileRepository,
        vitals: repositories as VitalsRepository,
        menstrual: repositories as MenstrualRepository,
        finance: repositories as FinanceRepository,
        split: repositories as SplitRepository,
        dailyTarget: repositories as DailyTargetRepository,
      );

  static Future<SectionOutcome<T>> section<T>(Future<T> Function() run) async {
    try {
      return SectionOk<T>(await run());
    } catch (_) {
      return SectionUnavailable<T>();
    }
  }

  @override
  Future<HealthOverviewBatch> getHealthOverview(
    String idToken, {
    required String day,
    required int trendDays,
    required int careDays,
  }) => throw UnsupportedError('home-only batch fake');

  @override
  Future<HomeSummaryBatch> getHomeSummary(
    String idToken, {
    required String day,
    required int trendDays,
  }) async {
    homeCalls.add((day: day, trendDays: trendDays));
    final date = parseDayString(day);
    final trendRange = dayRangeEndingOn(trendDays, date);
    final month = monthStringOf(date);

    final weightGoal = section(() => bodyProfile.getWeightGoal(idToken));
    final vitalsTrend = section(
      () => vitals.getRange(
        idToken,
        parseDayString(trendRange.from),
        parseDayString(trendRange.to),
      ),
    );
    final overview = section(() => menstrual.getOverview(idToken));
    final budget = section<FinanceBudget?>(
      () async => (await finance.listBudgets(idToken, month))
          .where((budget) => budget.categoryId == null)
          .firstOrNull,
    );
    final netWorth = section(() => finance.getMonthlyNetWorth(idToken, month));
    final balances = section(() => split.getBalances(idToken));
    final target = section(() => dailyTarget.getTarget(idToken, day));

    return HomeSummaryBatch(
      weightGoal: await weightGoal,
      vitalsTrend: await vitalsTrend,
      menstrual: await overview,
      overallBudget: await budget,
      netWorth: await netWorth,
      splitBalances: await balances,
      dailyTarget: await target,
    );
  }
}


/// Fails every batch read as a whole — the shape a `401` (or a network
/// failure) now has, since a batch request is answered for the whole screen
/// rather than per section.
class FailingScreenBatchRepository implements ScreenBatchRepository {
  final Object failure;

  FailingScreenBatchRepository(this.failure);

  FailingScreenBatchRepository.reauth()
    : failure = const ScreenBatchReauthRequired();

  FailingScreenBatchRepository.unavailable()
    : failure = const ScreenBatchFetchFailure();

  @override
  Future<HealthOverviewBatch> getHealthOverview(
    String idToken, {
    required String day,
    required int trendDays,
    required int careDays,
  }) async => throw failure;

  @override
  Future<HomeSummaryBatch> getHomeSummary(
    String idToken, {
    required String day,
    required int trendDays,
  }) async => throw failure;
}
