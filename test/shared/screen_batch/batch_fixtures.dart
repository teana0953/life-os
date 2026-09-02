/// Section payloads for the two batch endpoints.
///
/// Every value here is the body the *granular* endpoint returns, because that
/// is what the contract says a section's `data` is (backend
/// `screen-batch-reads` spec, "Section payloads match the granular
/// endpoints"). The decode tests feed the identical map to both paths, so a
/// fixture invented to suit the batch decoder would make those tests prove
/// nothing.
library;

Map<String, dynamic> okSection(Object? data) => {'ok': true, 'data': data};

Map<String, dynamic> failedSection() => {'ok': false, 'error': 'unavailable'};

const weightGoalPayload = {
  'height_cm': 170,
  'target_weight_kg': 62,
  'current_weight_kg': 68.4,
  'remaining_kg': 6.4,
  'achievement_rate': 40,
  'bmi': 23.7,
};

Map<String, dynamic> vitalsRangePayload({
  required String from,
  required String to,
}) => {
  'from': from,
  'to': to,
  'series': {
    'weight': [
      {'day': '2026-08-19', 'time': '', 'value': 68.4},
    ],
    'systolic': [
      {'day': '2026-08-18', 'time': '08:00', 'value': 118},
      {'day': '2026-08-19', 'time': '21:30', 'value': 124},
    ],
    'diastolic': [
      {'day': '2026-08-18', 'time': '08:00', 'value': 74},
      {'day': '2026-08-19', 'time': '21:30', 'value': 81},
    ],
  },
};

Map<String, dynamic> healthCalendarPayload({int year = 2026, int month = 8}) =>
    {
      'year': year,
      'month': month,
      'logged_days': ['$year-${month.toString().padLeft(2, '0')}-19'],
      'days_elapsed': 20,
      'logging_rate': 55,
      'diet_adherence_rate': 30,
    };

Map<String, dynamic> mealsPayload(String day) => {
  'day': day,
  'meals': const [],
  'totals': const {'staple': 1.5, 'meat': 2, 'fruit': 0.5, 'veg': 3},
};

Map<String, dynamic> dailyTargetPayload(String day) => {
  'day': day,
  'base': const {'staple': 3, 'meat': 4, 'fruit': 2, 'veg': 4},
  'bonus': const {'staple': 1, 'meat': 0, 'fruit': 0, 'veg': 0},
  'effective': const {'staple': 4, 'meat': 4, 'fruit': 2, 'veg': 4},
  'logged': const {'staple': 1.5, 'meat': 2, 'fruit': 0.5, 'veg': 3},
  'remaining': const {'staple': 2.5, 'meat': 2, 'fruit': 1.5, 'veg': 1},
};

const favoriteFoodItemsPayload = [
  {
    'id': 'food-1',
    'owner_user_id': null,
    'name': 'Rice',
    'carb_g': 40.0,
    'protein_g': 4.0,
    'fat_g': 0.5,
    'sugar_g': 0.0,
    'fiber_g': 1.0,
    'kcal': 180.0,
    'staple': 1.0,
    'meat': 0.0,
    'fruit': 0.0,
    'veg': 0.0,
  },
];

Map<String, dynamic> waterPayload(String day) => {
  'day': day,
  'total_ml': 900,
  'target_ml': 2000,
  'remaining_ml': 1100,
};

Map<String, dynamic> bowelPayload(String day) => {
  'day': day,
  'count': 2,
  'is_normal': true,
  'note': 'fine',
};

Map<String, dynamic> vitalsDayPayload(String day) => {
  'day': day,
  'weight_kg': 68.4,
  'body_fat_pct': 22,
  'waist_cm': 80,
  'bp_readings': const [
    {'systolic': 124, 'diastolic': 81, 'pulse': 66, 'time': '21:30'},
  ],
  'glucose_readings': const [],
  'spo2_readings': const [],
};

const exerciseActivitiesPayload = {
  'activities': [
    {
      'id': 'walk',
      'name': 'Walking',
      'category': 'aerobic',
      'intensity': 'light',
    },
  ],
};

Map<String, dynamic> exercisePayload(String day) => {
  'day': day,
  'entries': [
    {
      'id': 'entry-1',
      'activity_id': 'walk',
      'activity_name': 'Walking',
      'category': 'aerobic',
      'duration_minutes': 30,
      'note': '',
      'created_at': '2026-08-20T01:00:00.000Z',
    },
  ],
  'total_minutes': 30,
};

const menstrualPayload = {
  'periods': [
    {'id': 'p-1', 'start_date': '2026-07-28', 'end_date': '2026-08-02'},
  ],
  'stats': {
    'average_cycle_days': 29,
    'average_period_days': 5,
    'predicted_next_start': '2026-08-26',
  },
  'last_period': {
    'id': 'p-1',
    'start_date': '2026-07-28',
    'end_date': '2026-08-02',
  },
};

Map<String, dynamic> careSlotPayload({
  String timeOfDay = '08:00',
  String localDate = '2026-08-20',
  String status = 'pending',
}) => {
  'care_item_id': 'item-1',
  'care_schedule_id': 'sched-1',
  'item_deleted': false,
  'category': 'medication',
  'title': 'Vitamin D',
  'note': null,
  'dose': '1 tablet',
  'time_of_day': timeOfDay,
  'local_date': localDate,
  'status': status,
  'done_time': null,
  'dose_quantity': 1.0,
};

Map<String, dynamic> careTodayPayload(String day) => {
  'date': day,
  'items': [careSlotPayload(localDate: day)],
};

Map<String, dynamic> careRangePayload({
  required String from,
  required String to,
}) => {
  'from': from,
  'to': to,
  'days': [
    {
      'date': to,
      'items': [careSlotPayload(localDate: to, status: 'done')],
    },
  ],
};

Map<String, dynamic> budgetsPayload(String month) => {
  'month': month,
  'budgets': const [
    {
      'id': 'b-cat',
      'category_id': 'cat-1',
      'amount': 5000,
      'spent': 1000,
      'remaining': 4000,
      'percent': 20,
    },
    {
      'id': 'b-all',
      'category_id': null,
      'amount': 30000,
      'spent': 12000,
      'remaining': 18000,
      'percent': 40,
    },
  ],
};

Map<String, dynamic> netWorthPayload(String month) => {
  'month': month,
  'accounts': const [],
  'total_asset': 100000,
  'total_liability': 20000,
  'net_worth': 80000,
  'prev_net_worth': 75000,
  'growth_rate': 6.7,
};

const splitBalancesPayload = {
  'balances': [
    {
      'user_id': 'friend-1',
      'display_name': 'Friend',
      'balances': [
        {'currency': 'TWD', 'amount': 250, 'schedules': []},
      ],
    },
  ],
};

/// A `200` health-overview body with every section `ok`.
Map<String, dynamic> healthOverviewBody({
  String day = '2026-08-20',
  String trendFrom = '2026-07-22',
  String careFrom = '2026-07-22',
  int calendarYear = 2026,
  int calendarMonth = 8,
}) => {
  'weight_goal': okSection(weightGoalPayload),
  'vitals_trend': okSection(vitalsRangePayload(from: trendFrom, to: day)),
  'health_calendar': okSection(
    healthCalendarPayload(year: calendarYear, month: calendarMonth),
  ),
  'meals': okSection(mealsPayload(day)),
  'daily_target': okSection(dailyTargetPayload(day)),
  'favorite_food_items': okSection(favoriteFoodItemsPayload),
  'water': okSection(waterPayload(day)),
  'bowel': okSection(bowelPayload(day)),
  'vitals': okSection(vitalsDayPayload(day)),
  'exercise_activities': okSection(exerciseActivitiesPayload),
  'exercise': okSection(exercisePayload(day)),
  'menstrual': okSection(menstrualPayload),
  'care_today': okSection(careTodayPayload(day)),
  'care_range': okSection(careRangePayload(from: careFrom, to: day)),
};

/// A `200` health-overview body with every section failed — the case the
/// backend answers `200` for, which must still not be a whole-screen error.
Map<String, dynamic> healthOverviewAllFailedBody() => {
  for (final key in const [
    'weight_goal',
    'vitals_trend',
    'health_calendar',
    'meals',
    'daily_target',
    'favorite_food_items',
    'water',
    'bowel',
    'vitals',
    'exercise_activities',
    'exercise',
    'menstrual',
    'care_today',
    'care_range',
  ])
    key: failedSection(),
};

Map<String, dynamic> homeSummaryBody({
  String day = '2026-08-20',
  String trendFrom = '2025-08-20',
  String month = '2026-08',
}) => {
  'weight_goal': okSection(weightGoalPayload),
  'vitals_trend': okSection(vitalsRangePayload(from: trendFrom, to: day)),
  'menstrual': okSection(menstrualPayload),
  'budgets': okSection(budgetsPayload(month)),
  'net_worth': okSection(netWorthPayload(month)),
  'split_balances': okSection(splitBalancesPayload),
  'daily_target': okSection(dailyTargetPayload(day)),
};
