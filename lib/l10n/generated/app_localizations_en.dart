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
  String get dietAddSnack => 'Add snack';

  @override
  String get dietSnackLabelHint => 'Snack name';

  @override
  String get dietSnackBaseName => 'Snack';

  @override
  String dietLoggingToMeal(String meal) {
    return 'Logging to $meal';
  }

  @override
  String get dietLoggingDoneButton => 'Done';

  @override
  String dietAddedToMealSnackbar(String meal) {
    return 'Added to $meal';
  }

  @override
  String get dietSnackRenameTooltip => 'Name this snack';

  @override
  String get dietSnackRenameConfirmTooltip => 'Confirm name';

  @override
  String get dietSnackRenameCancelTooltip => 'Cancel rename';

  @override
  String get dietSearchFoodHint => 'Search food';

  @override
  String get dietFavoritesTitle => 'Favorites';

  @override
  String get dietQuantityLabel => 'Quantity';

  @override
  String get dietGramsLabel => 'Grams';

  @override
  String get dietUseGramsLabel => 'Use grams';

  @override
  String get dietEatenAtLabel => 'Eaten at';

  @override
  String get dietSaveEntryButton => 'Save';

  @override
  String dietAddToMealButton(String meal) {
    return 'Add to $meal';
  }

  @override
  String get dietPreviewTitle => 'Preview';

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
  String get dietManualEntryAffordance => 'Can\'t find it? Log manually';

  @override
  String get dietManualEntryTitle => 'Log food manually';

  @override
  String get dietManualEntryNameLabel => 'Name (optional)';

  @override
  String get dietManualEntryFallbackName => 'Manual entry';

  @override
  String get dietManualEntryAllZeroError =>
      'Enter at least one portion before saving.';

  @override
  String get dietTabAll => 'All';

  @override
  String get dietSearchAllPrompt => 'Search for a food to see results';

  @override
  String dietBasisEquals(String unit) {
    return '$unit ＝';
  }

  @override
  String dietPreviewMathLabel(double base, double quantity) {
    final intl.NumberFormat baseNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String baseString = baseNumberFormat.format(base);
    final intl.NumberFormat quantityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String quantityString = quantityNumberFormat.format(quantity);

    return '$baseString × $quantityString';
  }

  @override
  String get dietBonusNote =>
      '✳️ Bonus portions from exercise can be added later (exercise module integration coming soon).';

  @override
  String get dietEditEntryTitle => 'Edit entry';

  @override
  String get dietDeleteEntryButton => 'Delete';

  @override
  String get dietDeleteConfirmTitle => 'Delete entry?';

  @override
  String get dietDeleteConfirmMessage =>
      'This removes the entry and can\'t be undone.';

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
  String get dietAddToMeal => 'Add';

  @override
  String dietAddToMealA11yLabel(String meal) {
    return 'Add to $meal';
  }

  @override
  String get dietMealEmptyLabel => 'No entries yet';

  @override
  String get dietSnackAreaTitle => 'Snacks';

  @override
  String get dietAddSnackButton => 'Add snack';

  @override
  String get dietOpenDictionaryTooltip => 'Food dictionary';

  @override
  String get dietBrowseOnlyHint =>
      'Browsing only — tap ♥ to favorite. Log food from a meal\'s ＋.';
}
