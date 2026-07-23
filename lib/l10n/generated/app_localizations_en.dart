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
  String get dietTabToday => 'Today';

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
      '✳️ Bonus portions from exercise can be added later (exercise module integration coming soon).';

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
  String get dietGoHomeTooltip => 'Home';

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
  String get vitalsGlucoseBeforeMeal => 'Before meal';

  @override
  String get vitalsGlucoseAfterMeal => 'After meal';

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
  String get dietMoreTitle => 'More trackers';

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
  String get errorMenstrualLoadFailed =>
      'Unable to load your period data. Please try again.';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String get updateButton => 'Update';

  @override
  String get updateDismiss => 'Dismiss';

  @override
  String get dashboardTitle => 'Overview';

  @override
  String get dashboardRecordEntryTitle => 'Today\'s log';

  @override
  String get dashboardRecordEntrySubtitle => 'Record food, water, and more';

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
      'Record your weight on another day to see progress toward your goal.';

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
  String get trendRange7 => '7 days';

  @override
  String get trendRange30 => '30 days';

  @override
  String get trendRange90 => '90 days';

  @override
  String get trendEmpty => 'No data yet';

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
}
