// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to Life OS';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get errorIncorrectCredentials => 'Incorrect email or password.';

  @override
  String get errorInvalidEmail => 'That email address is invalid.';

  @override
  String get errorAccountDisabled => 'This account has been disabled.';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get errorSignInFailed => 'Sign-in failed. Please try again.';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Get started with Life OS';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get registerButton => 'Register';

  @override
  String get signingUp => 'Signing up…';

  @override
  String get errorPasswordMismatch => 'Passwords don\'t match';

  @override
  String get errorEmailAlreadyInUse => 'This email is already in use';

  @override
  String get errorWeakPassword =>
      'Password is too weak (at least 6 characters)';

  @override
  String get noAccountLink => 'No account? Register';

  @override
  String get haveAccountLink => 'Have an account? Sign in';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get yourSpaces => 'Your spaces';

  @override
  String get spaceHealth => 'Health';

  @override
  String get spaceFinance => 'Finance';

  @override
  String get spaceTasks => 'Tasks';

  @override
  String get spaceJournal => 'Journal';

  @override
  String get signedIn => 'Signed in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get pleaseSignInAgain => 'Please sign in again.';

  @override
  String get errorProfileLoadFailed =>
      'Unable to load your profile. Please try again.';

  @override
  String get errorSomethingWentWrong =>
      'Something went wrong. Please try again.';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get cardRefreshFailed => 'Couldn\'t refresh';

  @override
  String get switchLanguage => 'Switch language';

  @override
  String get followSystemLanguage => 'Follow system';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsIconTooltip => 'Settings';

  @override
  String get themeSectionTitle => 'Theme';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get settingsInstallSectionTitle => 'Install app';

  @override
  String get settingsInstallButton => 'Install LifeOS';

  @override
  String get settingsInstallIosHint =>
      'Add to Home Screen: Share → Add to Home Screen';

  @override
  String get dietTabTarget => 'Target';

  @override
  String get dietCategoryStaple => 'Staple';

  @override
  String get dietCategoryMeat => 'Meat';

  @override
  String get dietCategoryFruit => 'Fruit';

  @override
  String get dietCategoryVeg => 'Vegetable';

  @override
  String get dietCategoryIconStaple => 'S';

  @override
  String get dietCategoryIconMeat => 'M';

  @override
  String get dietCategoryIconFruit => 'F';

  @override
  String get dietCategoryIconVeg => 'V';

  @override
  String dietProgressOfTarget(double logged, double target) {
    final intl.NumberFormat loggedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String loggedString = loggedNumberFormat.format(logged);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$loggedString of $targetString';
  }

  @override
  String dietRemainingOfCategory(double remaining) {
    final intl.NumberFormat remainingNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);

    return '$remainingString remaining';
  }

  @override
  String get dietMealBreakfast => 'Breakfast';

  @override
  String get dietMealLunch => 'Lunch';

  @override
  String get dietMealDinner => 'Dinner';

  @override
  String get dietSnackBaseName => 'Snack';

  @override
  String get dietSearchFoodHint => 'Search food';

  @override
  String get dietQuantityLabel => 'Quantity';

  @override
  String get dietGramsLabel => 'Grams';

  @override
  String get dietPortionUnit => 'portion(s)';

  @override
  String dietAddToMealButton(String meal) {
    return 'Add to $meal';
  }

  @override
  String get dietSetTargetTitle => 'Set daily target';

  @override
  String get dietSaveTargetButton => 'Save';

  @override
  String get dietFavoriteTooltip => 'Favorite';

  @override
  String get dietUnfavoriteTooltip => 'Unfavorite';

  @override
  String get errorDietLoadFailed =>
      'Unable to load your diet data. Please try again.';

  @override
  String get dietBonusNote =>
      '✳️ Exercise adds bonus portions to the day\'s target (staple & meat).';

  @override
  String get dietTodayTitle => 'Today\'s Food';

  @override
  String get dietHistoryTitle => 'Food Log';

  @override
  String get dietDayToday => 'Today';

  @override
  String get dietDayYesterday => 'Yesterday';

  @override
  String get dietCalendarTitle => 'Calendar';

  @override
  String get dietCalendarCloseTooltip => 'Close';

  @override
  String get dietDayPrevTooltip => 'Previous day';

  @override
  String get dietDayNextTooltip => 'Next day';

  @override
  String get dietCalendarOpenTooltip => 'Open calendar';

  @override
  String get dietCalendarPrevMonth => 'Previous month';

  @override
  String get dietCalendarNextMonth => 'Next month';

  @override
  String dietAddToMealA11yLabel(String meal) {
    return 'Add to $meal';
  }

  @override
  String get dietMealEmptyLabel => 'No entries yet';

  @override
  String get dietAddSnackButton => 'Add snack';

  @override
  String dietSearchDoneButton(int count) {
    return 'Done ($count)';
  }

  @override
  String get dietDictionaryTitle => 'Food dictionary';

  @override
  String get dietOpenDictionaryTooltip => 'Look up a food';

  @override
  String get dietChooseMealSheetTitle => 'Add to which meal?';

  @override
  String get dietRemoveItemTooltip => 'Remove';

  @override
  String get dietMealTotalLabel => 'Total';

  @override
  String get dietSaveMealFailed => 'Failed to save. Please try again.';

  @override
  String get dietUnnamedItemLabel => 'Unnamed item';

  @override
  String get dietMeasureUnitMl => 'Milliliters';

  @override
  String get dietManualEntryLink => 'Not found? Enter manually';

  @override
  String get dietDictionaryFavoritesEmptyTitle => 'No usual foods yet';

  @override
  String get dietDictionaryFavoritesEmptyBody =>
      'Search for a food to see what it counts as, and tap the heart to keep it here.';

  @override
  String dietDictionaryNoResultsTitle(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get dietDictionaryNoResultsBody => 'Try another name for it.';

  @override
  String get dietDictionaryLoadFailed =>
      'Unable to load foods. Please try again.';

  @override
  String get dietManualEntryTitle => 'Manual entry';

  @override
  String get dietManualEntryNameLabel => 'Name';

  @override
  String get dietManualEntryAddButton => 'Add';

  @override
  String get dietDeleteItemTooltip => 'Delete';

  @override
  String get dietDeleteMealTooltip => 'Delete meal';

  @override
  String get dietDeleteMealConfirmTitle => 'Delete this meal?';

  @override
  String get dietDeleteMealConfirmMessage => 'This removes all of its items.';

  @override
  String get dietDeleteMealConfirmButton => 'Delete';

  @override
  String get dietChangeTimeTooltip => 'Change time';

  @override
  String get errorDietItemNotFound => 'This entry no longer exists.';

  @override
  String get dietSaveEditButton => 'Save';

  @override
  String get dietTabWater => 'Water';

  @override
  String get waterTitle => 'Today\'s water';

  @override
  String get waterHistoryTitle => 'Water log';

  @override
  String waterTotalOfTarget(int total, int target) {
    return '$total / $target ml';
  }

  @override
  String get waterAdd250 => '＋250 ml';

  @override
  String get waterAdd500 => '＋500 ml';

  @override
  String get waterCustomAmount => 'Custom';

  @override
  String get waterCorrect250 => '−250 ml';

  @override
  String get waterSetTargetButton => 'Set target';

  @override
  String get waterCustomAmountTitle => 'Add water (ml)';

  @override
  String get waterSetTargetTitle => 'Daily water target (ml)';

  @override
  String get errorWaterLoadFailed =>
      'Unable to load your water data. Please try again.';

  @override
  String get waterSaveFailed => 'Couldn\'t save — try again';

  @override
  String get waterGoalMet => 'Goal met';

  @override
  String get dietTabBowel => 'Bowel';

  @override
  String get bowelTitle => 'Today\'s bowel';

  @override
  String get bowelHistoryTitle => 'Bowel log';

  @override
  String get bowelCountLabel => 'Count';

  @override
  String get bowelNormalityLabel => 'Normal / abnormal';

  @override
  String get bowelNormalLabel => 'Normal';

  @override
  String get bowelAbnormalLabel => 'Abnormal';

  @override
  String get bowelNoteLabel => 'Note';

  @override
  String get bowelSaveButton => 'Save';

  @override
  String get bowelUnsavedChanges => 'Unsaved changes';

  @override
  String get bowelSaveFailed => 'Couldn\'t save — try again';

  @override
  String get errorBowelLoadFailed =>
      'Unable to load your bowel data. Please try again.';

  @override
  String get dietTabVitals => 'Vitals';

  @override
  String get vitalsTitle => 'Today\'s vitals';

  @override
  String get vitalsHistoryTitle => 'Vitals log';

  @override
  String get vitalsWeightLabel => 'Weight (kg)';

  @override
  String get vitalsBodyFatLabel => 'Body fat (%)';

  @override
  String get vitalsBloodPressureSection => 'Blood pressure (mmHg)';

  @override
  String get vitalsGlucoseSection => 'Blood glucose';

  @override
  String get vitalsSpo2Section => 'Blood oxygen';

  @override
  String get vitalsSystolicLabel => 'Systolic';

  @override
  String get vitalsDiastolicLabel => 'Diastolic';

  @override
  String get vitalsPulseLabel => 'Pulse';

  @override
  String get vitalsPulseUnit => 'bpm';

  @override
  String get vitalsGlucoseLabelField => 'Label';

  @override
  String get vitalsGlucoseValueLabel => 'mg/dL';

  @override
  String get vitalsSpo2Label => 'SpO₂ (%)';

  @override
  String get vitalsAddReading => 'Add';

  @override
  String get vitalsRemoveReading => 'Remove';

  @override
  String get vitalsSaveButton => 'Save';

  @override
  String get vitalsTimeLabel => 'Time';

  @override
  String get vitalsUnsavedChanges => 'Unsaved changes';

  @override
  String get vitalsSaveFailed => 'Couldn\'t save — try again';

  @override
  String get errorVitalsLoadFailed =>
      'Unable to load your vitals data. Please try again.';

  @override
  String get dietTabMore => 'More';

  @override
  String get dietTabExercise => 'Exercise';

  @override
  String get exerciseTitle => 'Today\'s exercise';

  @override
  String get exerciseHistoryTitle => 'Exercise log';

  @override
  String exerciseTotalMinutes(int minutes) {
    return '$minutes min total';
  }

  @override
  String exerciseEntryDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get exerciseEmptyLabel => 'No exercise logged yet';

  @override
  String get exerciseAddButton => 'Log exercise';

  @override
  String get exerciseAddDialogTitle => 'Log exercise';

  @override
  String get exerciseActivityLabel => 'Activity';

  @override
  String get exerciseDurationLabel => 'Minutes';

  @override
  String get exerciseNoteLabel => 'Note';

  @override
  String get exerciseCategoryAerobic => 'Aerobic';

  @override
  String get exerciseCategoryAnaerobic => 'Anaerobic';

  @override
  String get exerciseAddConfirmButton => 'Add';

  @override
  String get exerciseRemoveEntry => 'Remove';

  @override
  String get exerciseSaveFailed => 'Couldn\'t save — try again';

  @override
  String get exerciseEntryRemoved => 'Exercise removed';

  @override
  String get exerciseUndo => 'Undo';

  @override
  String get errorExerciseLoadFailed =>
      'Unable to load your exercise data. Please try again.';

  @override
  String get menstrualTitle => 'Period';

  @override
  String get menstrualAverageCycleLabel => 'Average cycle';

  @override
  String get menstrualAveragePeriodLabel => 'Average period';

  @override
  String get menstrualPredictedNextLabel => 'Predicted next';

  @override
  String menstrualDaysValue(int days) {
    return '$days days';
  }

  @override
  String get menstrualStatPlaceholder => '—';

  @override
  String get menstrualLastPeriodLabel => 'Last period';

  @override
  String get menstrualOngoingLabel => 'Ongoing';

  @override
  String get menstrualAddButton => 'Log period';

  @override
  String get menstrualAddDialogTitle => 'Log period';

  @override
  String get menstrualEditDialogTitle => 'Edit period';

  @override
  String get menstrualStartDateLabel => 'Start date';

  @override
  String get menstrualEndDateLabel => 'End date';

  @override
  String get menstrualSelectDate => 'Select';

  @override
  String get menstrualClearEndDate => 'Clear end date';

  @override
  String get menstrualEndBeforeStartError =>
      'The end date can\'t be before the start date.';

  @override
  String get menstrualSavePeriod => 'Save';

  @override
  String get menstrualDeletePeriod => 'Delete';

  @override
  String get menstrualPeriodDeleted => 'Period deleted';

  @override
  String get menstrualUndo => 'Undo';

  @override
  String get menstrualSaveFailed => 'Couldn\'t save — try again';

  @override
  String get menstrualPrevMonth => 'Previous month';

  @override
  String get menstrualNextMonth => 'Next month';

  @override
  String menstrualDaySemanticPeriod(String date) {
    return '$date, period day';
  }

  @override
  String menstrualDaySemanticPredicted(String date) {
    return '$date, predicted next period';
  }

  @override
  String menstrualDaySemanticToday(String date) {
    return '$date, today';
  }

  @override
  String get menstrualLegendPeriod => 'Period';

  @override
  String get menstrualLegendPredicted => 'Predicted next';

  @override
  String get menstrualEmptyHint =>
      'No periods recorded yet. Tap a day on the calendar or \'Log period\' to start tracking.';

  @override
  String get nextPeriodTitle => 'Next period';

  @override
  String nextPeriodUpcoming(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$date · in $_temp0';
  }

  @override
  String get nextPeriodToday => 'Expected today';

  @override
  String nextPeriodOverdue(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Expected $date · $_temp0 ago, nothing logged';
  }

  @override
  String nextPeriodOngoing(int day) {
    return 'Ongoing · day $day';
  }

  @override
  String nextPeriodOngoingNext(String date) {
    return 'Next expected $date';
  }

  @override
  String get nextPeriodNoRecords => 'No periods recorded yet';

  @override
  String get nextPeriodNeedsOneMore => 'Record one more to predict the next';

  @override
  String get errorMenstrualLoadFailed =>
      'Unable to load your period data. Please try again.';

  @override
  String get errorCareTodayLoadFailed =>
      'Unable to load today\'s care. Please try again.';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String get updateButton => 'Update';

  @override
  String get updateDismiss => 'Dismiss';

  @override
  String get dashboardTitle => 'Overview';

  @override
  String get healthTabRecord => 'Record';

  @override
  String get healthRecordDiet => 'Food';

  @override
  String get healthCalendarTitle => 'This month';

  @override
  String get healthCalendarLoggingRate => 'Logged';

  @override
  String get healthCalendarDietRate => 'Diet met';

  @override
  String get healthCalendarWeightRate => 'Weight';

  @override
  String get healthCalendarLoggedLegend => 'Logged';

  @override
  String get healthCalendarNoData => 'No data';

  @override
  String get healthCalendarLoadFailed =>
      'Unable to load this month. Please try again.';

  @override
  String get goalCardTitle => 'Weight goal';

  @override
  String get goalTargetLabel => 'Target';

  @override
  String get goalCurrentLabel => 'Current';

  @override
  String get goalRemainingLabel => 'Remaining';

  @override
  String get goalKgUnit => 'kg';

  @override
  String get goalCmUnit => 'cm';

  @override
  String get goalHeightShortLabel => 'Height';

  @override
  String get goalAchievementLabel => 'Achievement';

  @override
  String get goalAchievementHint =>
      'Log another day\'s weight to see progress.';

  @override
  String get goalBmiLabel => 'BMI';

  @override
  String get goalPlaceholder => '—';

  @override
  String get goalNoData => 'No data';

  @override
  String get goalUnsetPrompt =>
      'Set your height and target weight to start tracking your goal.';

  @override
  String get goalSetButton => 'Set your goal';

  @override
  String get goalEditTitle => 'Set your goal';

  @override
  String get goalHeightLabel => 'Height (cm)';

  @override
  String get goalTargetWeightLabel => 'Target weight (kg)';

  @override
  String get goalSaveButton => 'Save';

  @override
  String get errorWeightGoalLoadFailed =>
      'Unable to load your goal. Please try again.';

  @override
  String get trendCardTitle => 'Trends';

  @override
  String get trendMetricWeight => 'Weight';

  @override
  String get trendMetricBodyFat => 'Body fat';

  @override
  String get trendMetricSystolic => 'Systolic';

  @override
  String get trendMetricDiastolic => 'Diastolic';

  @override
  String get trendMetricPulse => 'Pulse';

  @override
  String get trendMetricGlucose => 'Glucose';

  @override
  String get trendMetricSpo2 => 'Blood oxygen';

  @override
  String get trendMetricBloodPressurePulse => 'BP & pulse';

  @override
  String get glucoseContextFasting => 'Fasting';

  @override
  String get glucoseContextPreMeal => 'Before meal';

  @override
  String get glucoseContextPostMeal => 'After meal';

  @override
  String get glucoseContextUnspecified => 'Unspecified';

  @override
  String get trendRange7 => '7 days';

  @override
  String get trendRange30 => '30 days';

  @override
  String get trendRange90 => '90 days';

  @override
  String get trendEmpty => 'No data yet';

  @override
  String get trendNormalRangeLabel => 'Normal range';

  @override
  String get trendLoadFailed => 'Unable to load your trends. Please try again.';

  @override
  String get trendUnitKg => 'kg';

  @override
  String get trendUnitPercent => '%';

  @override
  String get trendUnitMmhg => 'mmHg';

  @override
  String get trendUnitBpm => 'bpm';

  @override
  String get trendUnitMgdl => 'mg/dL';

  @override
  String trendChartSemantics(
    String metric,
    int days,
    double value,
    String unit,
  ) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String valueString = valueNumberFormat.format(value);

    return '$metric trend, last $days days, latest $valueString $unit';
  }

  @override
  String trendChartSemanticsEmpty(String metric, int days) {
    return '$metric trend, last $days days, no data';
  }

  @override
  String trendChartSemanticsMulti(String metric, int days) {
    return '$metric trend, last $days days';
  }

  @override
  String get importTitle => 'Import from chaodays';

  @override
  String get importAccountLabel => 'chaodays account';

  @override
  String get importPasswordLabel => 'chaodays password';

  @override
  String get importStartDateLabel => 'Start date';

  @override
  String get importEndDateLabel => 'End date';

  @override
  String get importSelectDateLabel => 'Select';

  @override
  String get importSubmitButton => 'Start import';

  @override
  String get importDoneMessage => 'Import complete.';

  @override
  String get importCredentialsNote =>
      'Your chaodays credentials are used only for this import and are never stored.';

  @override
  String get importTypesTitle => 'What to import';

  @override
  String get importTypeWeight => 'Weight & body fat';

  @override
  String get importTypeDiet => 'Diet & glucose';

  @override
  String get importTypeWater => 'Water';

  @override
  String get importTypeBowel => 'Bowel';

  @override
  String get importTypeDietTarget => 'Diet target';

  @override
  String get importTypeMenstrual => 'Periods';

  @override
  String get importMenstrualOpenPeriodHint =>
      'An ongoing period is skipped — import again after it ends.';

  @override
  String importResultSummary(int imported, int skipped) {
    return 'Imported $imported · Skipped $skipped';
  }

  @override
  String importResultGlucoseSuffix(int count) {
    return ' · Glucose $count';
  }

  @override
  String importResultWaterTargetSuffix(int count) {
    return ' · Water target $count';
  }

  @override
  String get importTypeFailed => 'Failed';

  @override
  String get importStatusImporting => 'Importing';

  @override
  String get importStatusSuccess => 'Imported successfully';

  @override
  String get importStatusFailed => 'Import failed';

  @override
  String get importStatusNotAttempted => 'Not attempted';

  @override
  String get importErrorAuthFailed =>
      'Wrong chaodays account or password. Please correct and try again.';

  @override
  String get importErrorUnavailable =>
      'chaodays is temporarily unavailable. Please try again later.';

  @override
  String get reminderTitle => 'Reminders';

  @override
  String get reminderStatusUnsupported =>
      'Notifications aren\'t supported on this browser or device.';

  @override
  String get reminderStatusIosNeedsInstall =>
      'To get notifications on iOS, tap the Share icon in Safari, choose \"Add to Home Screen\", then open LifeOS from your Home Screen and come back here.';

  @override
  String get reminderStatusPermissionDenied =>
      'Notifications are blocked for this site. Enable them in your browser settings, then come back here.';

  @override
  String get reminderEnabledStatus => 'Notifications are on for this device.';

  @override
  String get reminderErrorGeneric =>
      'Something went wrong turning on notifications. Please try again.';

  @override
  String get reminderEnableButton => 'Enable notifications';

  @override
  String get reminderTestButton => 'Send test push';

  @override
  String reminderTestResult(int sent, int failed) {
    return 'Sent $sent · Failed $failed';
  }

  @override
  String get reminderTestErrorGeneric =>
      'Couldn\'t send the test push. Please try again.';

  @override
  String get reminderTestSent =>
      'Test push sent — check your device for the notification.';

  @override
  String get reminderTestNoDevice =>
      'No enabled device received it — try turning notifications on again.';

  @override
  String get reminderRecheck => 'Check again';

  @override
  String get reminderStillBlocked =>
      'Notifications are still blocked — enable them in your browser settings, then check again.';

  @override
  String get careRemindersTitle => 'Care management';

  @override
  String get careRemindersEmptyTitle => 'No care reminders yet';

  @override
  String get careRemindersEmptyBody =>
      'Add one for medication, rehab, radiotherapy care, or a custom reminder.';

  @override
  String get careRemindersAddButton => 'Add reminder';

  @override
  String get careCategoryMedication => 'Medication';

  @override
  String get careCategoryRehab => 'Rehab';

  @override
  String get careCategoryRadiotherapyCare => 'Radiotherapy care';

  @override
  String get careCategoryCustom => 'Custom';

  @override
  String get careEveryDay => 'Every day';

  @override
  String careWeekIntervalSuffix(int n) {
    return '· every $n weeks';
  }

  @override
  String careScheduleUntil(String date) {
    return 'until $date';
  }

  @override
  String careScheduleFrom(String date) {
    return 'from $date';
  }

  @override
  String careStockLabel(String n) {
    return 'Stock: $n';
  }

  @override
  String get careDeleteConfirmTitle => 'Delete this reminder?';

  @override
  String get careDeleteConfirmMessage => 'This reminder will stop firing.';

  @override
  String get careDeleteConfirmButton => 'Delete';

  @override
  String get careCancelButton => 'Cancel';

  @override
  String get careErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get careFormTitleAdd => 'Add care reminder';

  @override
  String get careFormTitleEdit => 'Edit care reminder';

  @override
  String get careCategoryLabel => 'Category';

  @override
  String get careTitleField => 'Title';

  @override
  String get careNoteField => 'Note';

  @override
  String get careDoseField => 'Dose';

  @override
  String get careStockField => 'Stock';

  @override
  String get careStockAlertField => 'Low-stock alert';

  @override
  String get careSchedulesLabel => 'Schedules';

  @override
  String get careAddScheduleButton => 'Add schedule';

  @override
  String get careRemoveScheduleTooltip => 'Remove schedule';

  @override
  String get careChangeTimeTooltip => 'Change time';

  @override
  String get careTimeLabel => 'Time';

  @override
  String get careWeekdaysLabel => 'Repeat on';

  @override
  String get careWeekdaysEmptyHint => 'Leave all unselected for every day.';

  @override
  String careWeekIntervalValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String get careStartDateLabel => 'Starting';

  @override
  String get careEndDateLabel => 'Ends';

  @override
  String get careAddEndDateButton => 'Add end date';

  @override
  String get careRemoveEndDateTooltip => 'Remove end date';

  @override
  String get careDoseQuantityLabel => 'Quantity per dose';

  @override
  String get careNagIntervalLabel => 'Reminder repeat';

  @override
  String get careNagOnceLabel => 'Remind once';

  @override
  String careNagEveryNMinutes(int n) {
    return 'Every $n min';
  }

  @override
  String get careIncompleteHint =>
      'Add a title and at least one schedule to save.';

  @override
  String get careSaveButton => 'Save';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get careTodayTitle => 'Today care';

  @override
  String get careTodayOverdueSection => 'Overdue';

  @override
  String get careTodayLaterSection => 'Later';

  @override
  String careTodayDoneSection(int n) {
    return 'Done ($n)';
  }

  @override
  String get careTodayMarkDoneButton => 'Done';

  @override
  String get careTodaySkipButton => 'Skip';

  @override
  String careTodayDoneAtLabel(String time) {
    return 'Done at $time';
  }

  @override
  String get careTodayEmptyTitle => 'No schedules today';

  @override
  String get careTodayEmptyBody => 'Add a care reminder to see it here.';

  @override
  String get careTodayCelebrationTitle => 'All done for today!';

  @override
  String get careTodayCelebrationBody => 'Nice work — see you tomorrow.';

  @override
  String get careTodayUpNext => 'Up next';

  @override
  String get careTodayStatusSkipped => 'Skipped';

  @override
  String get careTodayStatusMissed => 'Missed';

  @override
  String get careTodayEditSheetTitle => 'Update this record';

  @override
  String get careTodayEditTimeLabel => 'Completion time';

  @override
  String get careTodayEditSubmitButton => 'Save';

  @override
  String careTodaySummaryProgress(int done, int total) {
    return '$done/$total done';
  }

  @override
  String careTodaySummaryMoreCount(int n) {
    return '$n more';
  }

  @override
  String get careTodaySummarySeeAll => 'See all';

  @override
  String get careTodaySummaryManage => 'Manage';

  @override
  String get careTodaySummarySetupTitle => 'No care reminders yet';

  @override
  String get careTodaySummarySetupCta => 'Set up';

  @override
  String get careRemindersPushOffBanner =>
      'Notifications aren\'t turned on yet — reminders won\'t be delivered';

  @override
  String get careRemindersPushOffAction => 'Turn on notifications';

  @override
  String get careRemindersPushDeniedBanner =>
      'Notifications are blocked — reminders won\'t be delivered';

  @override
  String get careHistoryTitle => 'Care history';

  @override
  String get careHistoryEntryTooltip => 'History';

  @override
  String get careHistoryEmptyTitle => 'No care records';

  @override
  String get careHistoryEmptyBody => 'Nothing was scheduled in this period.';

  @override
  String get careHistoryWidenPeriodButton => 'See a longer period';

  @override
  String get careHistoryEmptyManageButton => 'Go to care management';

  @override
  String get careHistoryAdherenceRateLabel => 'Adherence rate';

  @override
  String get careHistoryDaysWithDoseLabel => 'Days with care done';

  @override
  String get careHistoryMissedCountLabel => 'Missed slots';

  @override
  String get careHistoryLegendFull => 'Complete';

  @override
  String get careHistoryLegendPartial => 'Partial';

  @override
  String get careHistoryLegendMissed => 'Missed';

  @override
  String get careHistoryLegendNoSchedule => 'No schedule';

  @override
  String get careHistoryEditSheetTitle => 'Update this record';

  @override
  String get careHistoryStatusDone => 'Done';

  @override
  String get careHistoryStatusPending => 'Pending';

  @override
  String get careHistoryStatusOverdue => 'Overdue';

  @override
  String get careHistoryLegendUpcoming => 'Not yet due';

  @override
  String get careHistoryEditSuccessMessage => 'Saved.';

  @override
  String get careHistoryEditRefreshErrorMessage =>
      'Saved, but couldn\'t refresh the list.';

  @override
  String get careHistoryPastReadOnlyHint => 'Only today can be edited here.';

  @override
  String get careAdherenceCardTitle => 'Care adherence';

  @override
  String careAdherenceHeatmapCellLabel(String date, String state) {
    return '$date · $state';
  }

  @override
  String get careAdherenceOpenHistory => 'View records';

  @override
  String careAdherenceLegendWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String careAdherenceHeatmapRangeCaption(String from, String to) {
    return '$from – $to';
  }

  @override
  String careAdherenceHeatmapSummaryLabel(String details) {
    return 'Adherence by day: $details';
  }

  @override
  String get careAdherenceHeatmapSummarySeparator => ', ';

  @override
  String get careEditActionLabel => 'Edit';

  @override
  String careErrorForPeriod(int days) {
    return 'Couldn\'t load the last $days days. Please try again.';
  }

  @override
  String get careHistoryEditNotAppliedMessage =>
      'Not applied — nothing was changed. Please try again.';

  @override
  String get careHistoryNoCareItemsTitle => 'No care items yet';

  @override
  String get careHistoryNoCareItemsBody =>
      'You haven\'t set up any care items yet. Add one to start tracking.';

  @override
  String lastUpdatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get refreshDiscardTitle => 'Discard unsaved changes?';

  @override
  String get refreshDiscardMessage =>
      'Refreshing will discard your unsaved changes.';

  @override
  String get discard => 'Discard';

  @override
  String get cancel => 'Cancel';

  @override
  String get sharedFoodItemCreateTitle => 'New shared item';

  @override
  String get sharedFoodItemEditTitle => 'Edit shared item';

  @override
  String get sharedFoodItemNameLabel => 'Name';

  @override
  String get sharedFoodItemCarbLabel => 'Carbs (g)';

  @override
  String get sharedFoodItemProteinLabel => 'Protein (g)';

  @override
  String get sharedFoodItemFatLabel => 'Fat (g)';

  @override
  String get sharedFoodItemSugarLabel => 'Sugar (g)';

  @override
  String get sharedFoodItemFiberLabel => 'Fiber (g)';

  @override
  String get sharedFoodItemKcalLabel => 'Calories (kcal)';

  @override
  String get sharedFoodItemMeasureAmountLabel => 'Measure amount';

  @override
  String get sharedFoodItemMeasureUnitLabel => 'Measure unit';

  @override
  String get sharedFoodItemSubmitButton => 'Save';

  @override
  String get sharedFoodItemMeasurePairError =>
      'Give both the measure amount and unit, or leave them both empty.';

  @override
  String get sharedFoodItemMeasureAmountPositiveError =>
      'The measure amount must be greater than zero.';

  @override
  String sharedFoodItemNumberFieldError(String field) {
    return '$field must be zero or a positive number.';
  }

  @override
  String get sharedFoodItemNameRequiredError => 'Name is required.';

  @override
  String get sharedFoodItemCreateSuccess => 'Shared item created.';

  @override
  String get sharedFoodItemEditSuccess => 'Shared item updated.';

  @override
  String get sharedFoodItemForbiddenError =>
      'You don\'t have permission to do this.';

  @override
  String get sharedFoodItemSaveFailed => 'Couldn\'t save. Please try again.';

  @override
  String get sharedFoodItemNeedsReauthError =>
      'Please sign in again to save this.';

  @override
  String get createSharedItemTooltip => 'New shared item';

  @override
  String get editSharedItemTooltip => 'Edit shared item';

  @override
  String get editSharedItemMenuLabel => 'Edit';

  @override
  String get sharedFoodItemPortionsHeading => 'Portions';

  @override
  String get sharedFoodItemNutrientsHeading => 'Nutrients';

  @override
  String get financeTabOverview => 'Overview';

  @override
  String get financeTabTransactions => 'Transactions';

  @override
  String get financeFabTooltip => 'Record a transaction';

  @override
  String get financeAddTitle => 'Record a transaction';

  @override
  String get financeEditTitle => 'Edit transaction';

  @override
  String get financeAmountLabel => 'Amount';

  @override
  String get financeTypeExpense => 'Expense';

  @override
  String get financeTypeIncome => 'Income';

  @override
  String get financeCategoryLabel => 'Category';

  @override
  String get financeDateLabel => 'Date';

  @override
  String get financeCurrencyLabel => 'Currency';

  @override
  String get financeNoteLabel => 'Note';

  @override
  String get financeSaveButton => 'Save';

  @override
  String get financeDeleteButton => 'Delete';

  @override
  String get financeDeleteConfirmTitle => 'Delete this transaction?';

  @override
  String get financeDeleteConfirmMessage => 'This can\'t be undone.';

  @override
  String get financeDeleteConfirmButton => 'Delete';

  @override
  String get financeCancelButton => 'Cancel';

  @override
  String get financeSaveFailed =>
      'Couldn\'t save. Please check your connection and try again.';

  @override
  String get financeLoadFailed => 'Couldn\'t load your finance data.';

  @override
  String get financeEmptyTitle => 'No transactions yet this month';

  @override
  String get financeEmptyCta => 'Record your first one';

  @override
  String get financeExpenseTotal => 'Expense';

  @override
  String get financeIncomeTotal => 'Income';

  @override
  String get financeNetTotal => 'Net';

  @override
  String get financeRecentTransactions => 'Recent transactions';

  @override
  String get financeCategoryBreakdown => 'By category';

  @override
  String get financeBudgetCardTitle => 'Budget';

  @override
  String get financeBudgetOverallLabel => 'Overall';

  @override
  String get financeBudgetEmptyTitle => 'No budgets set yet';

  @override
  String get financeBudgetEmptyCta => 'Set a budget';

  @override
  String get financeBudgetOverLabel => 'Over budget';

  @override
  String get financeBudgetSheetTitle => 'Budgets';

  @override
  String get financeBudgetSheetHint =>
      'Budgets are recurring monthly settings and apply to every month.';

  @override
  String get financeBudgetArchivedLabel => 'Archived — can only be cleared';

  @override
  String get financeBudgetClearButton => 'Clear';

  @override
  String get financeBudgetClearedLabel => 'Will be cleared';

  @override
  String get financeBudgetInvalidAmount => 'Enter a valid amount';

  @override
  String get financeTabNetWorth => 'Net worth';

  @override
  String get networthNetWorthLabel => 'Net worth';

  @override
  String get networthGrowthUp => 'Up';

  @override
  String get networthGrowthDown => 'Down';

  @override
  String get networthGrowthFlat => 'Flat';

  @override
  String get networthArchivedSubtotal => 'Archived accounts';

  @override
  String get networthAssetsTitle => 'Assets';

  @override
  String get networthLiabilitiesTitle => 'Liabilities';

  @override
  String get networthTotalAssets => 'Total assets';

  @override
  String get networthTotalLiabilities => 'Total liabilities';

  @override
  String get networthTrendTitle => 'Net worth trend';

  @override
  String get networthTrendInsufficient =>
      'Not enough data yet — keep recording to see your trend.';

  @override
  String get networthTrendSummary => 'Net worth trend over the last months.';

  @override
  String get networthEmptyTitle => 'No values recorded for this month yet';

  @override
  String get networthEmptyCta => 'Record your first value';

  @override
  String get networthManageAccounts => 'Manage accounts';

  @override
  String get networthAddAccount => 'Add account';

  @override
  String get networthAccountNameLabel => 'Account name';

  @override
  String get networthKindAsset => 'Asset';

  @override
  String get networthKindLiability => 'Liability';

  @override
  String get networthArchiveButton => 'Archive';

  @override
  String get networthRestoreButton => 'Restore';

  @override
  String get networthArchivedLabel => 'Archived';

  @override
  String get networthMoveUpTooltip => 'Move up';

  @override
  String get networthValueLabel => 'Value (TWD)';

  @override
  String get networthNotRecorded => 'Not recorded';

  @override
  String get networthInvalidValue => 'Enter a whole number of 0 or more';

  @override
  String get networthSnapshotSheetTitle => 'Update value';

  @override
  String get networthAccountNameRequired => 'Enter an account name';

  @override
  String get networthSaveNameTooltip => 'Save name';

  @override
  String get monthNavPreviousTooltip => 'Previous month';

  @override
  String get monthNavNextTooltip => 'Next month';

  @override
  String get monthPickerTitle => 'Select month';

  @override
  String get monthPickerPreviousYearTooltip => 'Previous year';

  @override
  String get monthPickerNextYearTooltip => 'Next year';

  @override
  String get monthPickerYearTooltip => 'Select year';

  @override
  String get monthPickerOpenTooltip => 'Select month';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsEmptyTitle => 'No friends yet';

  @override
  String get friendsEmptyMessage =>
      'Invite someone using a link to add your first friend.';

  @override
  String get friendsInviteButton => 'Invite a friend';

  @override
  String get friendsInviteAnotherButton => 'Create another link';

  @override
  String get friendsCreateAnotherConfirmTitle => 'Create another link?';

  @override
  String get friendsCreateAnotherConfirmMessage =>
      'The link above hasn\'t been copied yet. A new link replaces it, and it can\'t be shown again.';

  @override
  String get friendsCreateAnotherConfirmButton => 'Replace it';

  @override
  String get friendsLoadErrorMessage => 'Couldn\'t load your friends.';

  @override
  String get friendsSectionFriends => 'Friends';

  @override
  String get friendsSectionInvites => 'Outstanding invites';

  @override
  String get friendsRemoveTooltip => 'Remove';

  @override
  String friendsRemoveConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String friendsRemoveConfirmMessage(String name) {
    return 'You and $name will no longer be friends.';
  }

  @override
  String get friendsRemoveConfirmButton => 'Remove';

  @override
  String get friendsRemoveNotFoundMessage =>
      'That friendship no longer exists.';

  @override
  String get friendsRemoveFailedMessage =>
      'Couldn\'t remove that friend. Try again.';

  @override
  String get friendsInviteLinkTitle => 'Your invite link';

  @override
  String get friendsCopyButton => 'Copy';

  @override
  String get friendsCopiedMessage => 'Link copied';

  @override
  String get friendsCopyFailedMessage =>
      'Couldn\'t copy. Select the link above to copy it manually.';

  @override
  String get friendsCreateInviteFailedMessage =>
      'Couldn\'t create an invite link. Try again.';

  @override
  String get friendsCreateInviteRefreshFailedMessage =>
      'Invite link created, but the list couldn\'t be refreshed.';

  @override
  String get friendsInviteLinkOnceWarning =>
      'Copy it now — this link is shown only once and can\'t be retrieved later.';

  @override
  String friendsInviteCreatedLabel(String date) {
    return 'Created $date';
  }

  @override
  String friendsInviteExpiresLabel(String date) {
    return 'Expires $date';
  }

  @override
  String get friendsRevokeButton => 'Revoke';

  @override
  String get friendsRevokeConfirmTitle => 'Revoke this invite?';

  @override
  String get friendsRevokeConfirmMessage =>
      'The link you already shared will stop working, and whoever has it won\'t be able to accept.';

  @override
  String get friendsRevokeConfirmButton => 'Revoke';

  @override
  String get friendsRevokeNotFoundMessage => 'That invite no longer exists.';

  @override
  String get friendsRevokeFailedMessage =>
      'Couldn\'t revoke that invite. Try again.';

  @override
  String get inviteTitle => 'Invite';

  @override
  String inviteFromMessage(String name) {
    return '$name invited you to be friends';
  }

  @override
  String get inviteAcceptButton => 'Accept';

  @override
  String inviteAlreadyFriendsMessage(String name) {
    return 'You\'re already friends with $name.';
  }

  @override
  String get inviteBackToFriendsButton => 'Back to friends';

  @override
  String get inviteExpiredMessage =>
      'This invite has expired. Ask for a new link.';

  @override
  String get inviteAlreadyUsedMessage => 'This invite has already been used.';

  @override
  String get inviteRevokedMessage => 'This invite was revoked.';

  @override
  String get inviteInvalidMessage =>
      'This link is invalid. Check that it was copied in full.';

  @override
  String get inviteFetchFailedMessage =>
      'Couldn\'t load this invite. Check your connection and try again.';

  @override
  String get inviteOwnInviteMessage => 'This is your own invite link.';

  @override
  String get settingsFriendsSectionTitle => 'Friends';

  @override
  String get settingsFriendsRowLabel => 'Friends';

  @override
  String get financeTabSplit => 'Split';

  @override
  String get splitFabTooltip => 'Record a split expense';

  @override
  String get splitEmptyTitle => 'No split expenses yet';

  @override
  String get splitEmptyCta => 'Record a split expense';

  @override
  String get splitLoadFailedMessage =>
      'Couldn\'t load your split expenses. Check your connection and try again.';

  @override
  String get splitProfileFailedMessage =>
      'Couldn\'t load your profile. Try again.';

  @override
  String get splitSectionOwedToMe => 'Owed to you';

  @override
  String splitOwedToMeRow(String name, String amount) {
    return '$name owes you $amount';
  }

  @override
  String get splitSectionOwedByMe => 'You owe';

  @override
  String splitOwedByMeRow(String name, String amount) {
    return 'You owe $name $amount';
  }

  @override
  String get splitSectionGroups => 'Groups';

  @override
  String get splitNoGroupsYet => 'No groups yet';

  @override
  String get splitAddGroupButton => 'New group';

  @override
  String get splitSectionRecentExpenses => 'Recent expenses';

  @override
  String get splitNoExpensesYet => 'No expenses yet';

  @override
  String splitExpensePaidBy(String name, String date) {
    return 'Paid by $name · $date';
  }

  @override
  String splitYourShare(String amount) {
    return 'Your share $amount';
  }

  @override
  String get splitAllSettledUp => 'Everyone is settled up';

  @override
  String get splitYouLabel => 'You';

  @override
  String get splitUnknownMember => 'Someone';

  @override
  String get splitCreateGroupTitle => 'New group';

  @override
  String get splitGroupNameLabel => 'Group name';

  @override
  String get splitGroupNameRequired => 'Enter a group name';

  @override
  String get splitCreateButton => 'Create';

  @override
  String get splitExpenseAddTitle => 'Record a split expense';

  @override
  String get splitExpenseEditTitle => 'Edit split expense';

  @override
  String get splitGroupFieldLabel => 'Group';

  @override
  String get splitGroupNoneOption => 'No group (one-off)';

  @override
  String get splitPayerLabel => 'Paid by';

  @override
  String get splitDescriptionLabel => 'Description';

  @override
  String get splitDescriptionRequired => 'Enter a description';

  @override
  String get splitDayLabel => 'Day';

  @override
  String get splitParticipantsLabel => 'Participants';

  @override
  String get splitSplitModeLabel => 'Split';

  @override
  String get splitModeEqual => 'Equal';

  @override
  String get splitModeExact => 'Exact';

  @override
  String splitEqualShareRow(String name, String amount) {
    return '$name: $amount';
  }

  @override
  String splitExactShareLabel(String name) {
    return '$name\'s share';
  }

  @override
  String splitExactRemaining(String amount) {
    return 'Remaining to assign: $amount';
  }

  @override
  String splitExactOverAssigned(String amount) {
    return 'Over by $amount';
  }

  @override
  String get splitExactAssignedInFull => 'Assigned in full';

  @override
  String get splitStakeWarning =>
      'You must be the payer, or hold a share above zero, to record this expense.';

  @override
  String get splitAmountTooLarge => 'This amount is too large.';

  @override
  String get splitAmountRequired => 'Enter an amount greater than zero.';

  @override
  String get splitPayerRequired => 'Choose who paid.';

  @override
  String get splitParticipantsRequired => 'Choose at least one participant.';

  @override
  String get splitTooFewPeople =>
      'A split needs at least two people — add someone besides the payer.';

  @override
  String get splitNoFriendsYet =>
      'You have no friends yet — add a friend first, then you can split with them.';

  @override
  String get splitAddFriendAction => 'Add a friend';

  @override
  String splitAmountBelowParticipants(int count) {
    return 'This amount is too small to split equally between $count people.';
  }

  @override
  String get splitExactMustSumToAmount =>
      'The shares must add up to the amount.';

  @override
  String splitDeleteConfirmTitle(String description) {
    return 'Delete \"$description\"?';
  }

  @override
  String get splitDeleteConfirmMessage =>
      'This removes the expense and its split for everyone involved. This can\'t be undone.';

  @override
  String get splitDeleteConfirmButton => 'Delete';

  @override
  String get splitSaveFailedMessage => 'Couldn\'t save. Try again.';

  @override
  String get splitErrorNotFriends =>
      'This person isn\'t your friend yet — add them as a friend first.';

  @override
  String get splitErrorNotAGroupMember =>
      'That person isn\'t a member of this group.';

  @override
  String get splitErrorGroupArchived =>
      'This group is archived, so no expense can be added to it.';

  @override
  String splitErrorSharesMismatch(String message) {
    return 'The shares don\'t add up to the amount: $message';
  }

  @override
  String get splitErrorTooSmall => 'This amount is too small to split.';

  @override
  String get splitErrorDuplicateParticipant =>
      'The same person can\'t be listed twice.';

  @override
  String get splitErrorAlreadyMember =>
      'That person is already a member of this group.';

  @override
  String get splitErrorNotAParticipant =>
      'You need a share in this expense to do that.';

  @override
  String splitErrorInvalidInput(String message) {
    return 'This split couldn\'t be accepted: $message';
  }

  @override
  String splitErrorBadRequest(String message) {
    return 'This entry was rejected: $message';
  }

  @override
  String get splitErrorNotFound =>
      'This couldn\'t be found. It may have been deleted.';

  @override
  String get splitErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get splitGroupArchivedBadge => 'Archived';

  @override
  String get splitGroupMembersTitle => 'Members';

  @override
  String get splitGroupBalancesTitle => 'Balances';

  @override
  String splitGroupBalanceShouldCollect(String name, String amount) {
    return '$name should collect $amount';
  }

  @override
  String splitGroupBalanceShouldPay(String name, String amount) {
    return '$name should pay $amount';
  }

  @override
  String get splitGroupExpensesTitle => 'Expenses';

  @override
  String get splitGroupNoExpensesYet => 'No expenses in this group yet';

  @override
  String get splitAddMemberButton => 'Add member';

  @override
  String get splitAddMemberTitle => 'Add a friend to this group';

  @override
  String get splitAddMemberEmpty =>
      'All your friends are already in this group.';

  @override
  String get splitArchiveButton => 'Archive group';

  @override
  String splitArchiveConfirmTitle(String groupName) {
    return 'Archive \"$groupName\"?';
  }

  @override
  String get splitArchiveConfirmMessage =>
      'The group becomes read-only: no new expenses or members can be added, though its existing expenses can still be edited by their creator or payer.';

  @override
  String get splitArchiveConfirmButton => 'Archive';

  @override
  String get splitAddExpenseTooltip => 'Record a split expense';

  @override
  String get splitEditExpenseTooltip => 'Edit';

  @override
  String get splitDeleteExpenseTooltip => 'Delete';

  @override
  String get splitGroupLoadFailedMessage =>
      'Couldn\'t load this group. Check your connection and try again.';
}
