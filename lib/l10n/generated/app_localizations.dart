import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// Heading shown on the sign-in card.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Subtitle shown under the sign-in heading.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Life OS'**
  String get signInSubtitle;

  /// Label for the email text field on the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for the password text field on the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Label for the sign-in submit button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// Accessible label announced while a sign-in request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// Shown when sign-in is rejected for invalid/unknown credentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorIncorrectCredentials;

  /// Shown when the entered email address is malformed.
  ///
  /// In en, this message translates to:
  /// **'That email address is invalid.'**
  String get errorInvalidEmail;

  /// Shown when sign-in is rejected because the account is disabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errorAccountDisabled;

  /// Shown when sign-in is rate-limited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyRequests;

  /// Generic sign-in failure message for unrecognized errors.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get errorSignInFailed;

  /// Heading shown on the register card.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// Subtitle shown under the register heading.
  ///
  /// In en, this message translates to:
  /// **'Get started with Life OS'**
  String get registerSubtitle;

  /// Label for the confirm-password text field on the register screen.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// Label for the register submit button.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// Accessible label announced while a sign-up request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Signing up…'**
  String get signingUp;

  /// Shown when the password and confirm-password fields don't match.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get errorPasswordMismatch;

  /// Shown when registering with an email that already has an account.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use'**
  String get errorEmailAlreadyInUse;

  /// Shown when the auth service rejects the password as too weak.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak (at least 6 characters)'**
  String get errorWeakPassword;

  /// Link on the sign-in screen that navigates to the register screen.
  ///
  /// In en, this message translates to:
  /// **'No account? Register'**
  String get noAccountLink;

  /// Link on the register screen that navigates back to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Have an account? Sign in'**
  String get haveAccountLink;

  /// Home screen greeting shown before noon.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// Home screen greeting shown from noon until evening.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// Home screen greeting shown in the evening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// Heading above the home screen's grid of space previews.
  ///
  /// In en, this message translates to:
  /// **'Your spaces'**
  String get yourSpaces;

  /// Illustrative placeholder name for a future module preview tile.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get spaceHealth;

  /// Illustrative placeholder name for a future module preview tile.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get spaceFinance;

  /// Illustrative placeholder name for a future module preview tile.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get spaceTasks;

  /// Illustrative placeholder name for a future module preview tile.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get spaceJournal;

  /// Badge shown next to the signed-in user's profile summary.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// Label for the sign-out button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Label for the button shown when re-authentication is required.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// Message shown when the backend requires re-authentication (HTTP 401).
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get pleaseSignInAgain;

  /// Shown when the profile fails to load.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your profile. Please try again.'**
  String get errorProfileLoadFailed;

  /// Generic failure message for unrecognized errors.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorSomethingWentWrong;

  /// Shown when the authentication state stream itself fails.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// Label for the retry button shown after an auth stream error.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Tooltip/accessible label for the language switcher control.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get switchLanguage;

  /// Language switcher menu option that reverts to following the device's system language.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystemLanguage;

  /// Language switcher menu option label for English; also shown as the current-language indicator when English is active.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language switcher menu option label for Traditional Chinese; also shown as the current-language indicator when Traditional Chinese is active.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageTraditionalChinese;

  /// Title of the settings page.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Tooltip/accessible label for the gear icon on the home screen that opens the settings page.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsIconTooltip;

  /// Heading for the theme section of the settings page.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSectionTitle;

  /// Theme option that follows the operating system's light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// Theme option for the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option for the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Heading for the language section of the settings page.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// Heading for the install-app section of the settings page (shown only in the web PWA when the app can be installed or an iOS add-to-home hint applies).
  ///
  /// In en, this message translates to:
  /// **'Install app'**
  String get settingsInstallSectionTitle;

  /// Label for the button in settings that triggers the browser's PWA install prompt.
  ///
  /// In en, this message translates to:
  /// **'Install LifeOS'**
  String get settingsInstallButton;

  /// Instruction shown in settings on iOS Safari (which has no install prompt) explaining how to add the app to the home screen via the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Add to Home Screen: Share → Add to Home Screen'**
  String get settingsInstallIosHint;

  /// Diet shell bottom navigation label and screen title for the Today section.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dietTabToday;

  /// Diet shell bottom navigation label and screen title for the daily target section.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get dietTabTarget;

  /// Food group category label for staple foods.
  ///
  /// In en, this message translates to:
  /// **'Staple'**
  String get dietCategoryStaple;

  /// Food group category label for meat/protein foods.
  ///
  /// In en, this message translates to:
  /// **'Meat'**
  String get dietCategoryMeat;

  /// Food group category label for fruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit'**
  String get dietCategoryFruit;

  /// Food group category label for vegetables.
  ///
  /// In en, this message translates to:
  /// **'Vegetable'**
  String get dietCategoryVeg;

  /// One-glyph icon label for the staple food group (shown on the target stepper).
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get dietCategoryIconStaple;

  /// One-glyph icon label for the meat/protein food group.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get dietCategoryIconMeat;

  /// One-glyph icon label for the fruit food group.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get dietCategoryIconFruit;

  /// One-glyph icon label for the vegetable food group.
  ///
  /// In en, this message translates to:
  /// **'V'**
  String get dietCategoryIconVeg;

  /// Shows portions logged against a category's target, e.g. '9 of 12'.
  ///
  /// In en, this message translates to:
  /// **'{logged} of {target}'**
  String dietProgressOfTarget(double logged, double target);

  /// Shows portions remaining for a category against its target.
  ///
  /// In en, this message translates to:
  /// **'{remaining} remaining'**
  String dietRemainingOfCategory(double remaining);

  /// Meal chip label for breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get dietMealBreakfast;

  /// Meal chip label for lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get dietMealLunch;

  /// Meal chip label for dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dietMealDinner;

  /// The base snack word used for the logging bar's snack segment and for auto-numbering a day's snack sessions (e.g. 'Snack', 'Snack2'). Distinct from dietAddSnack, which is chip copy ('Add snack') and would otherwise produce a nonsensical numbered name.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get dietSnackBaseName;

  /// Hint text for the food dictionary search field.
  ///
  /// In en, this message translates to:
  /// **'Search food'**
  String get dietSearchFoodHint;

  /// Label for the quantity amount text field on the log-entry card.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get dietQuantityLabel;

  /// Label for the gram amount text field on the log-entry card.
  ///
  /// In en, this message translates to:
  /// **'Grams'**
  String get dietGramsLabel;

  /// Generic unit word shown after the number in the amount control's portion mode, and in the consumed-amount label for foods with no base measure (e.g. "1 portion(s)").
  ///
  /// In en, this message translates to:
  /// **'portion(s)'**
  String get dietPortionUnit;

  /// Label for the button that adds a dictionary item to the current session's meal, naming that meal.
  ///
  /// In en, this message translates to:
  /// **'Add to {meal}'**
  String dietAddToMealButton(String meal);

  /// Heading above the daily target editing fields.
  ///
  /// In en, this message translates to:
  /// **'Set daily target'**
  String get dietSetTargetTitle;

  /// Label for the button that saves the daily target.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dietSaveTargetButton;

  /// Tooltip/accessible label for the button that marks a dictionary item as a favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get dietFavoriteTooltip;

  /// Tooltip/accessible label for the button that unmarks a dictionary item as a favorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get dietUnfavoriteTooltip;

  /// Shown when diet data (today's log, dictionary, or target) fails to load.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your diet data. Please try again.'**
  String get errorDietLoadFailed;

  /// Muted, non-editable note on the daily target screen about a future exercise-based bonus.
  ///
  /// In en, this message translates to:
  /// **'✳️ Bonus portions from exercise can be added later (exercise module integration coming soon).'**
  String get dietBonusNote;

  /// Header title shown above the day-navigation row when the viewed day is today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Food'**
  String get dietTodayTitle;

  /// Header title shown above the day-navigation row when viewing a past day.
  ///
  /// In en, this message translates to:
  /// **'Food Log'**
  String get dietHistoryTitle;

  /// Day-navigation header label when the viewed day is today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dietDayToday;

  /// Day-navigation header label when the viewed day is yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dietDayYesterday;

  /// Title of the dialog showing the month calendar for picking a day to view.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get dietCalendarTitle;

  /// Tooltip/accessible label for the button that closes the calendar dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get dietCalendarCloseTooltip;

  /// Tooltip/accessible label for the day-navigation button that moves to the previous day.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get dietDayPrevTooltip;

  /// Tooltip/accessible label for the day-navigation button that moves to the next day.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get dietDayNextTooltip;

  /// Tooltip/accessible label for the day-navigation button that opens the calendar dialog.
  ///
  /// In en, this message translates to:
  /// **'Open calendar'**
  String get dietCalendarOpenTooltip;

  /// Tooltip/accessible label for the button in the diet module's Today header that returns to the home "your spaces" screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dietGoHomeTooltip;

  /// Tooltip/accessible label for the calendar dialog's previous-month button.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get dietCalendarPrevMonth;

  /// Tooltip/accessible label for the calendar dialog's next-month button.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get dietCalendarNextMonth;

  /// Accessible label for a Today add control, naming the meal (or the snack area) it adds into so screen readers can distinguish the breakfast/lunch/dinner cards and the snack area's add control from one another.
  ///
  /// In en, this message translates to:
  /// **'Add to {meal}'**
  String dietAddToMealA11yLabel(String meal);

  /// Shown on a Today meal card that has no logged entries yet.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get dietMealEmptyLabel;

  /// Label on the Today snack area's control that starts a new snack-logging session. Paired with a leading add icon, so the text itself carries no plus sign.
  ///
  /// In en, this message translates to:
  /// **'Add snack'**
  String get dietAddSnackButton;

  /// Label for the full-screen food search's complete action, naming how many items are currently in the tray.
  ///
  /// In en, this message translates to:
  /// **'Done ({count})'**
  String dietSearchDoneButton(int count);

  /// Tooltip/accessible label for a tray row's remove control on the full-screen food search.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get dietRemoveItemTooltip;

  /// Label preceding the aggregated portion pills shown for a meal card's total and the food search tray's running total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get dietMealTotalLabel;

  /// Error message shown on the full-screen food search when completing the tray fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get dietSaveMealFailed;

  /// Fallback title shown on a Today meal item row for a dictionary item that has no name.
  ///
  /// In en, this message translates to:
  /// **'Unnamed item'**
  String get dietUnnamedItemLabel;

  /// Label for the measure segment of the portion/measure toggle when the food's measure unit is millilitres (never a bare "ml").
  ///
  /// In en, this message translates to:
  /// **'Milliliters'**
  String get dietMeasureUnitMl;

  /// Link/button on the full-screen food search that opens the manual-entry form for a food not in the dictionary.
  ///
  /// In en, this message translates to:
  /// **'Not found? Enter manually'**
  String get dietManualEntryLink;

  /// Title of the manual food-entry form.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get dietManualEntryTitle;

  /// Label/hint for the manual-entry form's food name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dietManualEntryNameLabel;

  /// Label for the manual-entry form's button that adds the entered food to the current-meal tray.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get dietManualEntryAddButton;

  /// Tooltip/accessible label for a Today meal item row's delete control.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dietDeleteItemTooltip;

  /// Tooltip/accessible label for a Today meal card's delete-meal control.
  ///
  /// In en, this message translates to:
  /// **'Delete meal'**
  String get dietDeleteMealTooltip;

  /// Title of the confirmation dialog shown before deleting a whole meal.
  ///
  /// In en, this message translates to:
  /// **'Delete this meal?'**
  String get dietDeleteMealConfirmTitle;

  /// Body text of the confirmation dialog shown before deleting a whole meal.
  ///
  /// In en, this message translates to:
  /// **'This removes all of its items.'**
  String get dietDeleteMealConfirmMessage;

  /// Label for the confirm button on the delete-meal confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dietDeleteMealConfirmButton;

  /// Tooltip/accessible label for a Today meal card's change-time control.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get dietChangeTimeTooltip;

  /// Shown when editing/deleting a meal or item fails because it no longer exists (or isn't owned by the caller).
  ///
  /// In en, this message translates to:
  /// **'This entry no longer exists.'**
  String get errorDietItemNotFound;

  /// Label for the inline item editor's save/commit control on Today.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dietSaveEditButton;

  /// Label for the Water destination in the daily-log shell's bottom navigation, alongside Today and Target.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get dietTabWater;

  /// Heading on the water screen, above the intake progress, when the viewed day is today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s water'**
  String get waterTitle;

  /// Heading on the water screen, above the intake progress, when viewing a past day.
  ///
  /// In en, this message translates to:
  /// **'Water log'**
  String get waterHistoryTitle;

  /// Water intake readout: the day's total against its target in millilitres, e.g. '1200 / 2000 ml'.
  ///
  /// In en, this message translates to:
  /// **'{total} / {target} ml'**
  String waterTotalOfTarget(int total, int target);

  /// Quick-add control that adds 250 millilitres of water.
  ///
  /// In en, this message translates to:
  /// **'＋250 ml'**
  String get waterAdd250;

  /// Quick-add control that adds 500 millilitres of water.
  ///
  /// In en, this message translates to:
  /// **'＋500 ml'**
  String get waterAdd500;

  /// Control that opens a dialog to add a custom amount of water.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get waterCustomAmount;

  /// Correction control that reduces the day's water total by 250 millilitres (the backend never lets the total go below zero).
  ///
  /// In en, this message translates to:
  /// **'−250 ml'**
  String get waterCorrect250;

  /// Control that opens a dialog to set the day's water target.
  ///
  /// In en, this message translates to:
  /// **'Set target'**
  String get waterSetTargetButton;

  /// Title of the dialog for entering a custom amount of water in millilitres.
  ///
  /// In en, this message translates to:
  /// **'Add water (ml)'**
  String get waterCustomAmountTitle;

  /// Title of the dialog for setting the day's water target in millilitres.
  ///
  /// In en, this message translates to:
  /// **'Daily water target (ml)'**
  String get waterSetTargetTitle;

  /// Shown on the water screen when loading the day's water intake fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your water data. Please try again.'**
  String get errorWaterLoadFailed;

  /// Transient SnackBar shown on the water screen when a quick-add/custom-add/correction/set-target mutation fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again'**
  String get waterSaveFailed;

  /// Small badge shown near the water intake readout when the day's total has reached or exceeded its target.
  ///
  /// In en, this message translates to:
  /// **'Goal met'**
  String get waterGoalMet;

  /// Label for the Bowel destination in the daily-log shell's bottom navigation, alongside Today, Target, and Water.
  ///
  /// In en, this message translates to:
  /// **'Bowel'**
  String get dietTabBowel;

  /// Heading on the bowel screen, above the record form, when the viewed day is today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s bowel'**
  String get bowelTitle;

  /// Heading on the bowel screen, above the record form, when viewing a past day.
  ///
  /// In en, this message translates to:
  /// **'Bowel log'**
  String get bowelHistoryTitle;

  /// Label for the bowel-movement count stepper on the bowel screen.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get bowelCountLabel;

  /// Caption above the bowel screen's normal/abnormal toggle, naming the section (its empty state means 'not recorded yet').
  ///
  /// In en, this message translates to:
  /// **'Normal / abnormal'**
  String get bowelNormalityLabel;

  /// Label for the 'normal' option of the bowel screen's normal/abnormal toggle.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get bowelNormalLabel;

  /// Label for the 'abnormal' option of the bowel screen's normal/abnormal toggle.
  ///
  /// In en, this message translates to:
  /// **'Abnormal'**
  String get bowelAbnormalLabel;

  /// Label/hint for the free-text note field on the bowel screen.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get bowelNoteLabel;

  /// Label for the button that saves (upserts) the day's whole bowel record.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bowelSaveButton;

  /// Cue shown above the Save button when the bowel draft has edits not yet saved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get bowelUnsavedChanges;

  /// Transient SnackBar shown on the bowel screen when saving the day's record fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again'**
  String get bowelSaveFailed;

  /// Shown on the bowel screen when loading the day's record fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your bowel data. Please try again.'**
  String get errorBowelLoadFailed;

  /// Label for the Vitals destination in the daily-log shell's bottom navigation, alongside Today, Target, Water, and Bowel.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get dietTabVitals;

  /// Heading on the vitals screen, above the record form, when the viewed day is today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s vitals'**
  String get vitalsTitle;

  /// Heading on the vitals screen, above the record form, when viewing a past day.
  ///
  /// In en, this message translates to:
  /// **'Vitals log'**
  String get vitalsHistoryTitle;

  /// Label for the optional weight field (kilograms) on the vitals screen; empty means not recorded.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get vitalsWeightLabel;

  /// Label for the optional body-fat percentage field on the vitals screen; empty means not recorded.
  ///
  /// In en, this message translates to:
  /// **'Body fat (%)'**
  String get vitalsBodyFatLabel;

  /// Section title for the blood-pressure reading list on the vitals screen; carries the mmHg unit for the systolic/diastolic fields.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure (mmHg)'**
  String get vitalsBloodPressureSection;

  /// Section title for the blood-glucose reading list on the vitals screen.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get vitalsGlucoseSection;

  /// Section title for the blood-oxygen (SpO2) reading list on the vitals screen.
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen'**
  String get vitalsSpo2Section;

  /// Label for the systolic value field of a blood-pressure reading row.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get vitalsSystolicLabel;

  /// Label for the diastolic value field of a blood-pressure reading row.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get vitalsDiastolicLabel;

  /// Label for the optional pulse field of a blood-pressure or blood-oxygen reading row; empty means not recorded.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get vitalsPulseLabel;

  /// Compact unit suffix (beats per minute) shown inside the pulse field on both the blood-pressure and blood-oxygen reading rows.
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get vitalsPulseUnit;

  /// Label for the free-text label field of a blood-glucose reading row (e.g. before/after a meal).
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get vitalsGlucoseLabelField;

  /// Label for the numeric value field (milligrams per deciliter) of a blood-glucose reading row.
  ///
  /// In en, this message translates to:
  /// **'mg/dL'**
  String get vitalsGlucoseValueLabel;

  /// Label for the SpO2 percentage field of a blood-oxygen reading row.
  ///
  /// In en, this message translates to:
  /// **'SpO₂ (%)'**
  String get vitalsSpo2Label;

  /// Quick-pick label setting a glucose reading's label to 'before meal'.
  ///
  /// In en, this message translates to:
  /// **'Before meal'**
  String get vitalsGlucoseBeforeMeal;

  /// Quick-pick label setting a glucose reading's label to 'after meal'.
  ///
  /// In en, this message translates to:
  /// **'After meal'**
  String get vitalsGlucoseAfterMeal;

  /// Label for the control that appends a new reading row to a vitals list (blood pressure, glucose, or blood oxygen).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get vitalsAddReading;

  /// Tooltip for the control that removes a reading row from a vitals list.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get vitalsRemoveReading;

  /// Label for the button that saves (upserts) the day's whole vitals record.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vitalsSaveButton;

  /// Tooltip/accessible label for the per-reading time control on the vitals screen; the reading's time is shown as HH:mm.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get vitalsTimeLabel;

  /// Cue shown above the Save button when the vitals draft has edits not yet saved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get vitalsUnsavedChanges;

  /// Transient SnackBar shown on the vitals screen when saving the day's record fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again'**
  String get vitalsSaveFailed;

  /// Shown on the vitals screen when loading the day's record fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your vitals data. Please try again.'**
  String get errorVitalsLoadFailed;

  /// Label for the More (overflow) destination in the daily-log shell's bottom navigation, alongside Today, Target, and Water; it opens a menu of the lower-frequency trackers.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get dietTabMore;

  /// Heading shown above the list of overflow tracker tiles on the daily-log shell's More menu.
  ///
  /// In en, this message translates to:
  /// **'More trackers'**
  String get dietMoreTitle;

  /// Label for the Exercise tracker tile in the daily-log shell's More menu, and the base name of the exercise tracker.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get dietTabExercise;

  /// Heading on the exercise screen, above the entry list, when the viewed day is today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s exercise'**
  String get exerciseTitle;

  /// Heading on the exercise screen, above the entry list, when viewing a past day.
  ///
  /// In en, this message translates to:
  /// **'Exercise log'**
  String get exerciseHistoryTitle;

  /// The day's total exercise duration shown at the top of the exercise screen, e.g. '50 min total'.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min total'**
  String exerciseTotalMinutes(int minutes);

  /// A single exercise entry's duration in whole minutes, shown on its row, e.g. '30 min'.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String exerciseEntryDuration(int minutes);

  /// Shown on the exercise screen for a day that has no entries yet.
  ///
  /// In en, this message translates to:
  /// **'No exercise logged yet'**
  String get exerciseEmptyLabel;

  /// Label for the control on the exercise screen that opens the add-entry dialog.
  ///
  /// In en, this message translates to:
  /// **'Log exercise'**
  String get exerciseAddButton;

  /// Title of the dialog for adding an exercise entry (choose an activity, enter minutes, optional note).
  ///
  /// In en, this message translates to:
  /// **'Log exercise'**
  String get exerciseAddDialogTitle;

  /// Caption above the activity picker in the add-exercise dialog.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get exerciseActivityLabel;

  /// Label for the whole-minutes duration field in the add-exercise dialog (empty means zero, via the numeric empty-zero convention).
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get exerciseDurationLabel;

  /// Label/hint for the optional free-text note field in the add-exercise dialog.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get exerciseNoteLabel;

  /// Group heading for aerobic activities in the add-exercise dialog's activity picker.
  ///
  /// In en, this message translates to:
  /// **'Aerobic'**
  String get exerciseCategoryAerobic;

  /// Group heading for anaerobic activities in the add-exercise dialog's activity picker.
  ///
  /// In en, this message translates to:
  /// **'Anaerobic'**
  String get exerciseCategoryAnaerobic;

  /// Label for the confirm button in the add-exercise dialog that appends the entry.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get exerciseAddConfirmButton;

  /// Tooltip/accessible label for the control that removes an exercise entry from the day's list.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get exerciseRemoveEntry;

  /// Transient SnackBar shown on the exercise screen when appending or removing an entry fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again'**
  String get exerciseSaveFailed;

  /// Transient SnackBar shown on the exercise screen after an entry is removed, paired with an Undo action.
  ///
  /// In en, this message translates to:
  /// **'Exercise removed'**
  String get exerciseEntryRemoved;

  /// Action label on the exercise 'removed' SnackBar that re-adds the just-removed entry.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get exerciseUndo;

  /// Shown on the exercise screen when loading the day's entries fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your exercise data. Please try again.'**
  String get errorExerciseLoadFailed;

  /// Title of the app-wide top banner shown when a newer version of the PWA has been downloaded in the background and is ready to load on reload.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get updateAvailableTitle;

  /// Label for the button in the update banner that reloads the app onto the new version.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// Tooltip/accessible label for the update banner's dismiss (X) control, which hides the banner for this session.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get updateDismiss;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
