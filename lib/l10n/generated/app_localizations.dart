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

  /// Muted, non-editable note on the daily target screen explaining that logging exercise raises the day's staple and meat portion target.
  ///
  /// In en, this message translates to:
  /// **'✳️ Exercise adds bonus portions to the day\'s target (staple & meat).'**
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

  /// Title of the full-screen food search when it is opened as the dictionary — with no target meal — instead of to add food to a specific meal.
  ///
  /// In en, this message translates to:
  /// **'Food dictionary'**
  String get dietDictionaryTitle;

  /// Tooltip/accessible label for the diet screen's icon-only action that opens the food dictionary without first choosing a meal.
  ///
  /// In en, this message translates to:
  /// **'Look up a food'**
  String get dietOpenDictionaryTooltip;

  /// Title of the bottom sheet that asks which meal the dictionary tray should be saved to, shown when completing a tray built in the dictionary.
  ///
  /// In en, this message translates to:
  /// **'Add to which meal?'**
  String get dietChooseMealSheetTitle;

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

  /// Label for the menstrual (period) tracker tile in the daily-log shell's More menu, and the title of the menstrual screen's app bar.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get menstrualTitle;

  /// Label on the menstrual screen's statistics card for the average number of days between period starts.
  ///
  /// In en, this message translates to:
  /// **'Average cycle'**
  String get menstrualAverageCycleLabel;

  /// Label on the menstrual screen's statistics card for the average length of a period in days.
  ///
  /// In en, this message translates to:
  /// **'Average period'**
  String get menstrualAveragePeriodLabel;

  /// Label on the menstrual screen's statistics card for the predicted start date of the next period.
  ///
  /// In en, this message translates to:
  /// **'Predicted next'**
  String get menstrualPredictedNextLabel;

  /// A statistic value expressed as a whole number of days, e.g. '28 days'.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String menstrualDaysValue(int days);

  /// Placeholder shown on the menstrual screen in place of a statistic that is not yet available (not enough data).
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get menstrualStatPlaceholder;

  /// Label on the menstrual screen for the most recent recorded period's date range.
  ///
  /// In en, this message translates to:
  /// **'Last period'**
  String get menstrualLastPeriodLabel;

  /// Shown in place of an end date for a period that is still open (no end date recorded yet).
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get menstrualOngoingLabel;

  /// Label for the control on the menstrual screen that opens the dialog to record a new period.
  ///
  /// In en, this message translates to:
  /// **'Log period'**
  String get menstrualAddButton;

  /// Title of the dialog for recording a new menstrual period.
  ///
  /// In en, this message translates to:
  /// **'Log period'**
  String get menstrualAddDialogTitle;

  /// Title of the dialog for editing an existing menstrual period.
  ///
  /// In en, this message translates to:
  /// **'Edit period'**
  String get menstrualEditDialogTitle;

  /// Label for the required start-date field in the menstrual add/edit dialog.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get menstrualStartDateLabel;

  /// Label for the optional end-date field in the menstrual add/edit dialog.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get menstrualEndDateLabel;

  /// Placeholder shown on a date-picker control in the menstrual dialog when no date has been chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get menstrualSelectDate;

  /// Tooltip/label for the control in the menstrual edit dialog that clears the end date, reopening a completed period.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get menstrualClearEndDate;

  /// Validation message shown in the menstrual dialog when the chosen end date is earlier than the start date.
  ///
  /// In en, this message translates to:
  /// **'The end date can\'t be before the start date.'**
  String get menstrualEndBeforeStartError;

  /// Label for the confirm button in the menstrual add/edit dialog that saves the period.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get menstrualSavePeriod;

  /// Label for the control in the menstrual edit dialog that deletes the period.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menstrualDeletePeriod;

  /// Transient SnackBar shown after a menstrual period is deleted, paired with an Undo action.
  ///
  /// In en, this message translates to:
  /// **'Period deleted'**
  String get menstrualPeriodDeleted;

  /// Action label on the menstrual 'deleted' SnackBar that re-adds the just-deleted period.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get menstrualUndo;

  /// Transient SnackBar shown on the menstrual screen when saving a period fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again'**
  String get menstrualSaveFailed;

  /// Tooltip for the control that moves the menstrual mini-calendar to the previous month.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get menstrualPrevMonth;

  /// Tooltip for the control that moves the menstrual mini-calendar to the next month.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get menstrualNextMonth;

  /// Screen-reader label for a menstrual calendar day cell that falls within a recorded period. {date} is the localized date.
  ///
  /// In en, this message translates to:
  /// **'{date}, period day'**
  String menstrualDaySemanticPeriod(String date);

  /// Screen-reader label for a menstrual calendar day cell that is the predicted next period start. {date} is the localized date.
  ///
  /// In en, this message translates to:
  /// **'{date}, predicted next period'**
  String menstrualDaySemanticPredicted(String date);

  /// Screen-reader label for the menstrual calendar day cell representing today (when it is neither a period day nor the predicted next start). {date} is the localized date.
  ///
  /// In en, this message translates to:
  /// **'{date}, today'**
  String menstrualDaySemanticToday(String date);

  /// Legend label under the menstrual calendar for the filled marker meaning a recorded period day.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get menstrualLegendPeriod;

  /// Legend label under the menstrual calendar for the outlined marker meaning the predicted next period start.
  ///
  /// In en, this message translates to:
  /// **'Predicted next'**
  String get menstrualLegendPredicted;

  /// First-run guidance shown on the menstrual screen when there are no recorded periods yet, so the empty statistics don't look broken.
  ///
  /// In en, this message translates to:
  /// **'No periods recorded yet. Tap a day on the calendar or \'Log period\' to start tracking.'**
  String get menstrualEmptyHint;

  /// Shown on the menstrual screen when loading the overview fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your period data. Please try again.'**
  String get errorMenstrualLoadFailed;

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

  /// App-bar title of the health module's overview dashboard (the landing screen), a scrollable stack of cards.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get dashboardTitle;

  /// Bottom-nav label for the health module's recording hub (all trackers).
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get healthTabRecord;

  /// Record-hub tile label for the diet / food log.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get healthRecordDiet;

  /// Title of the dashboard card showing the month's logged-days calendar and adherence rings.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get healthCalendarTitle;

  /// Ring label: share of the month's elapsed days with any tracker entry.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get healthCalendarLoggingRate;

  /// Ring label: share of the month's elapsed days that met the diet target.
  ///
  /// In en, this message translates to:
  /// **'Diet met'**
  String get healthCalendarDietRate;

  /// Ring label: the weight-goal achievement rate (reused from the goal card).
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get healthCalendarWeightRate;

  /// Legend for the calendar dot marking a day that has a tracker entry.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get healthCalendarLoggedLegend;

  /// Spoken (screen-reader) value for a ring with no percentage yet.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get healthCalendarNoData;

  /// Shown on the health-calendar card when loading the month summary fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load this month. Please try again.'**
  String get healthCalendarLoadFailed;

  /// Title of the goal card on the overview dashboard, showing target/current/remaining weight, an achievement ring, and BMI.
  ///
  /// In en, this message translates to:
  /// **'Weight goal'**
  String get goalCardTitle;

  /// Label for the target weight figure on the goal card.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalTargetLabel;

  /// Label for the current weight figure on the goal card.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get goalCurrentLabel;

  /// Label for the remaining-to-target weight figure on the goal card.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get goalRemainingLabel;

  /// Kilogram unit suffix shown after the weight figures on the goal card.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get goalKgUnit;

  /// Centimetre unit suffix shown after the height figure on the goal card.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get goalCmUnit;

  /// Short label for the height row on the goal card (the cm unit is shown separately).
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get goalHeightShortLabel;

  /// Label for the achievement-rate ring on the goal card.
  ///
  /// In en, this message translates to:
  /// **'Achievement'**
  String get goalAchievementLabel;

  /// Hint shown under the goal card's achievement ring when there isn't enough weight history (only one day) to compute progress.
  ///
  /// In en, this message translates to:
  /// **'Log another day\'s weight to see progress.'**
  String get goalAchievementHint;

  /// Label for the BMI figure on the goal card (body mass index).
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get goalBmiLabel;

  /// Placeholder shown in place of a weight or BMI figure on the goal card when the value is null / not yet known.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get goalPlaceholder;

  /// Screen-reader label for the achievement ring on the goal card when the achievement rate is not yet known, spoken instead of the visual dash placeholder.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get goalNoData;

  /// Prompt shown on the goal card when neither height nor target weight has been set, instead of a row of empty placeholders.
  ///
  /// In en, this message translates to:
  /// **'Set your height and target weight to start tracking your goal.'**
  String get goalUnsetPrompt;

  /// Button on the unset goal card that opens the edit sheet to set height and target weight.
  ///
  /// In en, this message translates to:
  /// **'Set your goal'**
  String get goalSetButton;

  /// Title of the goal edit bottom sheet where the user enters height and target weight.
  ///
  /// In en, this message translates to:
  /// **'Set your goal'**
  String get goalEditTitle;

  /// Label for the height (centimetres) number field in the goal edit sheet.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get goalHeightLabel;

  /// Label for the target weight (kilograms) number field in the goal edit sheet.
  ///
  /// In en, this message translates to:
  /// **'Target weight (kg)'**
  String get goalTargetWeightLabel;

  /// Label for the button that saves the entered height and target weight in the goal edit sheet.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get goalSaveButton;

  /// Shown on the goal card / dashboard when loading (or saving) the weight goal fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your goal. Please try again.'**
  String get errorWeightGoalLoadFailed;

  /// Title of the dashboard trend card showing a line chart of a vitals metric over time.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendCardTitle;

  /// Metric-picker label for the body-weight trend series.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get trendMetricWeight;

  /// Metric-picker label for the body-fat-percentage trend series.
  ///
  /// In en, this message translates to:
  /// **'Body fat'**
  String get trendMetricBodyFat;

  /// Metric-picker label for the systolic blood-pressure trend series.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get trendMetricSystolic;

  /// Metric-picker label for the diastolic blood-pressure trend series.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get trendMetricDiastolic;

  /// Metric-picker label for the pulse (heart-rate) trend series.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get trendMetricPulse;

  /// Metric-picker label for the blood-glucose trend series.
  ///
  /// In en, this message translates to:
  /// **'Glucose'**
  String get trendMetricGlucose;

  /// Metric-picker label for the blood-oxygen (SpO2) trend series.
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen'**
  String get trendMetricSpo2;

  /// Metric-picker label for the combined view plotting systolic, diastolic, and pulse on one chart.
  ///
  /// In en, this message translates to:
  /// **'BP & pulse'**
  String get trendMetricBloodPressurePulse;

  /// Glucose meal-context: a reading taken while fasting. Used by the glucose input picker and the trend legend.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get glucoseContextFasting;

  /// Glucose meal-context: a reading taken before a meal.
  ///
  /// In en, this message translates to:
  /// **'Before meal'**
  String get glucoseContextPreMeal;

  /// Glucose meal-context: a reading taken after a meal.
  ///
  /// In en, this message translates to:
  /// **'After meal'**
  String get glucoseContextPostMeal;

  /// Glucose meal-context: a reading with no meal context recorded (e.g. legacy data). Shown in the trend legend.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get glucoseContextUnspecified;

  /// Range-selector label for a 7-day trend window.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get trendRange7;

  /// Range-selector label for a 30-day trend window.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get trendRange30;

  /// Range-selector label for a 90-day trend window.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get trendRange90;

  /// Shown in the trend card's chart area when the selected metric has no recorded points in the range.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get trendEmpty;

  /// Legend label for the shaded band on the trend chart marking the metric's normal reference range.
  ///
  /// In en, this message translates to:
  /// **'Normal range'**
  String get trendNormalRangeLabel;

  /// Shown on the trend card when loading the trend range fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your trends. Please try again.'**
  String get trendLoadFailed;

  /// Unit suffix shown near the trend card title for the weight metric (kilograms).
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get trendUnitKg;

  /// Unit suffix shown near the trend card title for the body-fat and blood-oxygen metrics (percentage).
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get trendUnitPercent;

  /// Unit suffix shown near the trend card title for the systolic and diastolic blood-pressure metrics (millimetres of mercury).
  ///
  /// In en, this message translates to:
  /// **'mmHg'**
  String get trendUnitMmhg;

  /// Unit suffix shown near the trend card title for the pulse metric (beats per minute).
  ///
  /// In en, this message translates to:
  /// **'bpm'**
  String get trendUnitBpm;

  /// Unit suffix shown near the trend card title for the blood-glucose metric (milligrams per decilitre).
  ///
  /// In en, this message translates to:
  /// **'mg/dL'**
  String get trendUnitMgdl;

  /// Screen-reader summary of the trend chart: the selected metric, the range in days, and the latest value with its unit.
  ///
  /// In en, this message translates to:
  /// **'{metric} trend, last {days} days, latest {value} {unit}'**
  String trendChartSemantics(
    String metric,
    int days,
    double value,
    String unit,
  );

  /// Screen-reader summary of the trend chart when the selected metric has no data in the range.
  ///
  /// In en, this message translates to:
  /// **'{metric} trend, last {days} days, no data'**
  String trendChartSemanticsEmpty(String metric, int days);

  /// Screen-reader summary of the trend chart for a multi-line view (e.g. BP & pulse), which has several series and so no single latest value.
  ///
  /// In en, this message translates to:
  /// **'{metric} trend, last {days} days'**
  String trendChartSemanticsMulti(String metric, int days);

  /// Title of the chaodays import entry tile (health module's More tab) and the import screen's app bar.
  ///
  /// In en, this message translates to:
  /// **'Import from chaodays'**
  String get importTitle;

  /// Label for the chaodays account/username field on the import screen.
  ///
  /// In en, this message translates to:
  /// **'chaodays account'**
  String get importAccountLabel;

  /// Label for the chaodays password field on the import screen.
  ///
  /// In en, this message translates to:
  /// **'chaodays password'**
  String get importPasswordLabel;

  /// Label for the import date range's start date picker.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get importStartDateLabel;

  /// Label for the import date range's end date picker.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get importEndDateLabel;

  /// Placeholder shown on an unset date picker button on the import screen.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get importSelectDateLabel;

  /// Button that starts the chaodays import.
  ///
  /// In en, this message translates to:
  /// **'Start import'**
  String get importSubmitButton;

  /// Shown after the selected chaodays data types finished importing.
  ///
  /// In en, this message translates to:
  /// **'Import complete.'**
  String get importDoneMessage;

  /// Reassurance note shown on the import screen explaining the credentials aren't stored.
  ///
  /// In en, this message translates to:
  /// **'Your chaodays credentials are used only for this import and are never stored.'**
  String get importCredentialsNote;

  /// Heading above the list of chaodays data types the user can select for import.
  ///
  /// In en, this message translates to:
  /// **'What to import'**
  String get importTypesTitle;

  /// Label for the weight/body-fat row in the chaodays import results.
  ///
  /// In en, this message translates to:
  /// **'Weight & body fat'**
  String get importTypeWeight;

  /// Label for the diet/glucose row in the chaodays import results.
  ///
  /// In en, this message translates to:
  /// **'Diet & glucose'**
  String get importTypeDiet;

  /// Label for the water row in the chaodays import results.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get importTypeWater;

  /// Label for the bowel row in the chaodays import results.
  ///
  /// In en, this message translates to:
  /// **'Bowel'**
  String get importTypeBowel;

  /// Label for the diet-target row in the chaodays import results.
  ///
  /// In en, this message translates to:
  /// **'Diet target'**
  String get importTypeDietTarget;

  /// Per-type chaodays import result summary (counts of imported vs. already-present records).
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} · Skipped {skipped}'**
  String importResultSummary(int imported, int skipped);

  /// Appended to the diet row's result summary when glucose readings were also imported.
  ///
  /// In en, this message translates to:
  /// **' · Glucose {count}'**
  String importResultGlucoseSuffix(int count);

  /// Appended to the diet-target row's result summary when a water target was also imported.
  ///
  /// In en, this message translates to:
  /// **' · Water target {count}'**
  String importResultWaterTargetSuffix(int count);

  /// Shown on a per-type row when that type's import failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get importTypeFailed;

  /// Screen-reader description of the status indicator on an import row that is currently running.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get importStatusImporting;

  /// Screen-reader description of the status indicator on an import row that succeeded.
  ///
  /// In en, this message translates to:
  /// **'Imported successfully'**
  String get importStatusSuccess;

  /// Screen-reader description of the status indicator on an import row that failed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importStatusFailed;

  /// Screen-reader description of the status indicator on an import row the last run did not reach.
  ///
  /// In en, this message translates to:
  /// **'Not attempted'**
  String get importStatusNotAttempted;

  /// Error banner shown when chaodays rejects the provided credentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong chaodays account or password. Please correct and try again.'**
  String get importErrorAuthFailed;

  /// Error banner shown when chaodays can't be reached (backend 502, or any other unexpected import failure).
  ///
  /// In en, this message translates to:
  /// **'chaodays is temporarily unavailable. Please try again later.'**
  String get importErrorUnavailable;

  /// Title for the reminder/notification settings screen, and the label for its entry card in the More tab.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminderTitle;

  /// Shown when the device/browser doesn't support Web Push (no service worker / Push / Notification support).
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t supported on this browser or device.'**
  String get reminderStatusUnsupported;

  /// Guidance shown on iOS Safari before the app has been installed to the Home Screen, where Web Push isn't available yet.
  ///
  /// In en, this message translates to:
  /// **'To get notifications on iOS, tap the Share icon in Safari, choose \"Add to Home Screen\", then open LifeOS from your Home Screen and come back here.'**
  String get reminderStatusIosNeedsInstall;

  /// Shown after the user denies the browser's notification permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this site. Enable them in your browser settings, then come back here.'**
  String get reminderStatusPermissionDenied;

  /// Shown once the device is successfully subscribed to Web Push.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on for this device.'**
  String get reminderEnabledStatus;

  /// Shown when enabling notifications fails for a non-auth reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong turning on notifications. Please try again.'**
  String get reminderErrorGeneric;

  /// Label for the primary button that requests permission and subscribes to Web Push.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get reminderEnableButton;

  /// Label for the secondary button, shown once enabled, that requests a backend test push.
  ///
  /// In en, this message translates to:
  /// **'Send test push'**
  String get reminderTestButton;

  /// Snack bar message showing the outcome of a test push.
  ///
  /// In en, this message translates to:
  /// **'Sent {sent} · Failed {failed}'**
  String reminderTestResult(int sent, int failed);

  /// Snack bar message shown when a test push request fails for a non-auth reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the test push. Please try again.'**
  String get reminderTestErrorGeneric;

  /// Snack bar message shown when a test push was sent to at least one enabled device.
  ///
  /// In en, this message translates to:
  /// **'Test push sent — check your device for the notification.'**
  String get reminderTestSent;

  /// Snack bar message shown when a test push succeeded but reached zero enabled devices.
  ///
  /// In en, this message translates to:
  /// **'No enabled device received it — try turning notifications on again.'**
  String get reminderTestNoDevice;

  /// Label for the button shown in the permissionDenied state that re-resolves the environment after the user fixes their browser settings.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get reminderRecheck;

  /// Snack bar message shown when tapping the re-check button resolves and permission is still denied, so the user can tell the check ran.
  ///
  /// In en, this message translates to:
  /// **'Notifications are still blocked — enable them in your browser settings, then check again.'**
  String get reminderStillBlocked;

  /// Title for the care reminders screen, and the label for its entry card in the health module's More tab.
  ///
  /// In en, this message translates to:
  /// **'Care management'**
  String get careRemindersTitle;

  /// Heading shown in the empty-state guide when the user has no care reminders.
  ///
  /// In en, this message translates to:
  /// **'No care reminders yet'**
  String get careRemindersEmptyTitle;

  /// Body text shown under the empty-state heading.
  ///
  /// In en, this message translates to:
  /// **'Add one for medication, rehab, radiotherapy care, or a custom reminder.'**
  String get careRemindersEmptyBody;

  /// Label for the button in the empty state that opens the add-reminder form.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get careRemindersAddButton;

  /// Category label/group heading for medication reminders.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get careCategoryMedication;

  /// Category label/group heading for rehab reminders.
  ///
  /// In en, this message translates to:
  /// **'Rehab'**
  String get careCategoryRehab;

  /// Category label/group heading for radiotherapy-care reminders.
  ///
  /// In en, this message translates to:
  /// **'Radiotherapy care'**
  String get careCategoryRadiotherapyCare;

  /// Category label/group heading for custom reminders.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get careCategoryCustom;

  /// Shown for a schedule with no weekday selected (empty repeatDays = every day).
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get careEveryDay;

  /// Appended to a schedule's summary when weekInterval > 1, so a biweekly (or less frequent) schedule is distinguishable from a weekly one.
  ///
  /// In en, this message translates to:
  /// **'· every {n} weeks'**
  String careWeekIntervalSuffix(int n);

  /// Appended to a schedule's summary when it has an end date.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String careScheduleUntil(String date);

  /// Appended to a schedule's summary when weekInterval > 1, since the start (anchor) date then matters for figuring out which weeks it falls on.
  ///
  /// In en, this message translates to:
  /// **'from {date}'**
  String careScheduleFrom(String date);

  /// Shown on a medication reminder's row with its remaining stock count.
  ///
  /// In en, this message translates to:
  /// **'Stock: {n}'**
  String careStockLabel(String n);

  /// Title of the confirmation dialog shown before deleting a reminder.
  ///
  /// In en, this message translates to:
  /// **'Delete this reminder?'**
  String get careDeleteConfirmTitle;

  /// Body text of the delete-reminder confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This reminder will stop firing.'**
  String get careDeleteConfirmMessage;

  /// Label for the confirm button on the delete-reminder confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get careDeleteConfirmButton;

  /// Label for a cancel action in the care reminder form / dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get careCancelButton;

  /// Shown when loading the list, a mutation, or the form's save fails for a non-auth reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get careErrorGeneric;

  /// App bar title for the care reminder form when adding a new reminder.
  ///
  /// In en, this message translates to:
  /// **'Add care reminder'**
  String get careFormTitleAdd;

  /// App bar title for the care reminder form when editing an existing reminder.
  ///
  /// In en, this message translates to:
  /// **'Edit care reminder'**
  String get careFormTitleEdit;

  /// Section heading for the care reminder form's category selector.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get careCategoryLabel;

  /// Label for the care reminder form's title text field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get careTitleField;

  /// Label for the care reminder form's multi-line note text field.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get careNoteField;

  /// Label for the medication-only dose text field.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get careDoseField;

  /// Label for the medication-only stock quantity field.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get careStockField;

  /// Label for the medication-only low-stock alert threshold field.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alert'**
  String get careStockAlertField;

  /// Section heading for the care reminder form's list of schedules.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get careSchedulesLabel;

  /// Label for the button that opens a time picker to add another schedule.
  ///
  /// In en, this message translates to:
  /// **'Add schedule'**
  String get careAddScheduleButton;

  /// Tooltip/accessible label for the control that removes a schedule from the list.
  ///
  /// In en, this message translates to:
  /// **'Remove schedule'**
  String get careRemoveScheduleTooltip;

  /// Tooltip/accessible label for the control that reopens the time picker for a schedule.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get careChangeTimeTooltip;

  /// Label shown above a schedule's time button.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get careTimeLabel;

  /// Section heading for a schedule's weekday chip selector.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get careWeekdaysLabel;

  /// Muted helper text under the weekday chips clarifying that no selection means the schedule repeats daily.
  ///
  /// In en, this message translates to:
  /// **'Leave all unselected for every day.'**
  String get careWeekdaysEmptyHint;

  /// Shows a schedule's current every-N-weeks cadence, with −/+ controls beside it.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Every week} other{Every {n} weeks}}'**
  String careWeekIntervalValue(int n);

  /// Label for a schedule's start-date picker (shown once weekInterval > 1).
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get careStartDateLabel;

  /// Label for a schedule's optional end-date value.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get careEndDateLabel;

  /// Label for the button that opens a date picker to set a schedule's optional end date.
  ///
  /// In en, this message translates to:
  /// **'Add end date'**
  String get careAddEndDateButton;

  /// Tooltip/accessible label for the control that clears a schedule's end date.
  ///
  /// In en, this message translates to:
  /// **'Remove end date'**
  String get careRemoveEndDateTooltip;

  /// Label for a schedule's medication-only dose-quantity field.
  ///
  /// In en, this message translates to:
  /// **'Quantity per dose'**
  String get careDoseQuantityLabel;

  /// Label for a schedule's nag-interval dropdown.
  ///
  /// In en, this message translates to:
  /// **'Reminder repeat'**
  String get careNagIntervalLabel;

  /// Dropdown option label for a nag interval of 0 (no repeat nagging).
  ///
  /// In en, this message translates to:
  /// **'Remind once'**
  String get careNagOnceLabel;

  /// Dropdown option label for a nonzero nag interval.
  ///
  /// In en, this message translates to:
  /// **'Every {n} min'**
  String careNagEveryNMinutes(int n);

  /// Inline hint shown under the Save button while it's disabled, explaining what's still required.
  ///
  /// In en, this message translates to:
  /// **'Add a title and at least one schedule to save.'**
  String get careIncompleteHint;

  /// Label for the care reminder form's submit button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get careSaveButton;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSun;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMon;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTue;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWed;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThu;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFri;

  /// Short weekday label for the reminder form's weekday chips.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSat;

  /// Title for the Today care checklist screen, and its entry in the health More tab.
  ///
  /// In en, this message translates to:
  /// **'Today care'**
  String get careTodayTitle;

  /// Section header for overdue slots on the Today care checklist.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get careTodayOverdueSection;

  /// Section header for pending (not yet due or overdue) slots on the Today care checklist.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get careTodayLaterSection;

  /// Collapsible section header for done/skipped/missed slots, with a count.
  ///
  /// In en, this message translates to:
  /// **'Done ({n})'**
  String careTodayDoneSection(int n);

  /// Button label to mark a pending or overdue care slot done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get careTodayMarkDoneButton;

  /// Button label to mark a pending or overdue care slot skipped.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get careTodaySkipButton;

  /// Shown on a done slot's row with its recorded done time.
  ///
  /// In en, this message translates to:
  /// **'Done at {time}'**
  String careTodayDoneAtLabel(String time);

  /// Title for the Today checklist's empty state when there are no care slots today.
  ///
  /// In en, this message translates to:
  /// **'No schedules today'**
  String get careTodayEmptyTitle;

  /// Body copy for the Today checklist's empty state, guiding the user to add a reminder.
  ///
  /// In en, this message translates to:
  /// **'Add a care reminder to see it here.'**
  String get careTodayEmptyBody;

  /// Title for the all-done celebration shown when nothing is pending or overdue.
  ///
  /// In en, this message translates to:
  /// **'All done for today!'**
  String get careTodayCelebrationTitle;

  /// Body copy for the all-done celebration.
  ///
  /// In en, this message translates to:
  /// **'Nice work — see you tomorrow.'**
  String get careTodayCelebrationBody;

  /// Label for the focus card when its slot is pending (not yet due), signaling it's the next thing to do.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get careTodayUpNext;

  /// Status label on a Done-group row for a slot the user deliberately skipped, distinguishing it from a missed slot.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get careTodayStatusSkipped;

  /// Status label on a Done-group row for a slot that passed with no record, distinguishing it from a deliberate skip.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get careTodayStatusMissed;

  /// Small header label at the top of the Today care Done-group correction sheet.
  ///
  /// In en, this message translates to:
  /// **'Update this record'**
  String get careTodayEditSheetTitle;

  /// Label for the completion-time row in the Today care Done-group correction sheet; its subtitle shows the currently selected local time and tapping it opens the time picker (disabled when the status is set to skipped).
  ///
  /// In en, this message translates to:
  /// **'Completion time'**
  String get careTodayEditTimeLabel;

  /// Label for the confirm button in the Today care Done-group correction sheet that submits the chosen outcome and completion time.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get careTodayEditSubmitButton;

  /// Progress pill on the overview care summary card's header, e.g. '2/5 done' (done vs. total slots today).
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String careTodaySummaryProgress(int done, int total);

  /// Footer text on the overview care summary card naming how many additional slots exist beyond the one shown as focus.
  ///
  /// In en, this message translates to:
  /// **'{n} more'**
  String careTodaySummaryMoreCount(int n);

  /// Footer text on the overview care summary card, always shown alongside a trailing arrow as an open affordance (and alongside careTodaySummaryMoreCount when extra slots exist), hinting that tapping the card opens the full Today checklist.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get careTodaySummarySeeAll;

  /// Header entry on the overview care summary card (shown when today has care schedules), tapped to open care reminders management (medication/rehab/radiotherapy care/custom schedules).
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get careTodaySummaryManage;

  /// Title of the slim setup-prompt card shown on the overview when the user has no care reminders scheduled yet, in place of the today-care summary card.
  ///
  /// In en, this message translates to:
  /// **'No care reminders yet'**
  String get careTodaySummarySetupTitle;

  /// Action label on the overview setup-prompt card (alongside a trailing arrow appended in code), tapped to go set up a care reminder.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get careTodaySummarySetupCta;

  /// Banner shown at the top of the care reminders management list when push notifications aren't enabled, warning the user their reminders won't actually arrive.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t on — reminders won\'t be delivered'**
  String get careRemindersPushOffBanner;

  /// Action button on the push-off banner in care reminders management, tapped to open the reminder/notification settings screen.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get careRemindersPushOffAction;

  /// AppBar title of the care history screen (route /care-history), reachable from care management and Today care.
  ///
  /// In en, this message translates to:
  /// **'Care history'**
  String get careHistoryTitle;

  /// Tooltip on the AppBar icon (in care management and Today care) that opens the care history screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get careHistoryEntryTooltip;

  /// Title of the empty-state guide on the care history screen, shown when every day in the selected period has nothing scheduled.
  ///
  /// In en, this message translates to:
  /// **'No care records'**
  String get careHistoryEmptyTitle;

  /// Body text of the empty-state guide on the care history screen, shown when every day in the selected period has nothing scheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing was scheduled in this period.'**
  String get careHistoryEmptyBody;

  /// Button on the care history screen's empty-state guide, shown when the selected period is shorter than 90 days, that widens the period to the next longer option (7→30→90) and reloads.
  ///
  /// In en, this message translates to:
  /// **'See a longer period'**
  String get careHistoryWidenPeriodButton;

  /// Button on the care history screen's empty-state guide, shown once the period is already the longest (90 days) so widening is no longer possible, that opens care management (/care-items) — at that point the likeliest reason the period is empty is having no care items set up yet.
  ///
  /// In en, this message translates to:
  /// **'Go to care management'**
  String get careHistoryEmptyManageButton;

  /// Headline metric label in the care history chart mode: the share of scheduled slots marked done over the selected period.
  ///
  /// In en, this message translates to:
  /// **'Adherence rate'**
  String get careHistoryAdherenceRateLabel;

  /// Headline metric label in the care history chart mode: the count of days with at least one slot marked done. Neutral wording — this screen aggregates every care category (medication, rehab, phototherapy maintenance, custom), not just medication doses.
  ///
  /// In en, this message translates to:
  /// **'Days with care done'**
  String get careHistoryDaysWithDoseLabel;

  /// Headline metric label in the care history chart mode for the total count of slots with status missed over the selected period — worded as a slot count ('Missed slots') so it reads distinctly from careHistoryLegendMissed (a day-level heatmap state, worded as 'Missed') and from careTodayStatusMissed (a single slot's status word, 'Missed'); the three counts can differ.
  ///
  /// In en, this message translates to:
  /// **'Missed slots'**
  String get careHistoryMissedCountLabel;

  /// Heatmap legend label for a day where every *due* scheduled slot was marked done, in the care history chart mode. A slot still pending (not yet due) doesn't count against this — a day with one dose taken and a later one not yet due still reads Complete, matching the adherence rate (which likewise excludes not-yet-due slots).
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get careHistoryLegendFull;

  /// Heatmap legend label for a day where some but not all scheduled slots were marked done, in the care history chart mode.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get careHistoryLegendPartial;

  /// Heatmap legend label for a day that had scheduled slots but none were marked done (this includes a day where every slot was skipped), in the care history chart mode. Distinct from careTodayStatusMissed (a single slot's status word) and careHistoryMissedCountLabel (the headline's slot-level missed count) — the three counts can differ.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get careHistoryLegendMissed;

  /// Heatmap legend label for a day with nothing scheduled, in the care history chart mode.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get careHistoryLegendNoSchedule;

  /// Title of the bottom sheet opened by tapping a slot in the care history list, offering to mark it done or skipped.
  ///
  /// In en, this message translates to:
  /// **'Update this record'**
  String get careHistoryEditSheetTitle;

  /// Status word shown on a done slot's tile in the care history list (as 'HH:mm · status').
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get careHistoryStatusDone;

  /// Status word shown on a pending slot's tile in the care history list (as 'HH:mm · status') — a slot in the selected period (which can include today) not yet due.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get careHistoryStatusPending;

  /// Status word shown on an overdue slot's tile in the care history list (as 'HH:mm · status') — a slot in the selected period (which can include today) past due with no record yet.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get careHistoryStatusOverdue;

  /// Heatmap legend label for a day whose every scheduled slot is still pending — typically today, before anything has been logged. An overdue slot (past due with no record — genuinely late) does NOT count as not-yet-due, so a day with even one overdue slot reads careHistoryLegendMissed instead. Distinct from careHistoryLegendMissed: nothing has failed here, it just hasn't happened yet.
  ///
  /// In en, this message translates to:
  /// **'Not yet due'**
  String get careHistoryLegendUpcoming;

  /// Brief SnackBar confirmation shown after a slot edit in the care history list succeeds (both the save and the follow-up list refresh).
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get careHistoryEditSuccessMessage;

  /// SnackBar message shown when a slot edit in the care history list saves successfully but the follow-up refresh of the list fails — distinct from careErrorGeneric (which implies the edit itself failed) so the user isn't told their change was lost when it wasn't.
  ///
  /// In en, this message translates to:
  /// **'Saved, but couldn\'t refresh the list.'**
  String get careHistoryEditRefreshErrorMessage;

  /// Low-contrast note on a past day's card in the care history list, explaining why its rows have no edit affordance and do nothing when tapped — corrections are only possible for today (on the Today care checklist).
  ///
  /// In en, this message translates to:
  /// **'Only today can be edited here.'**
  String get careHistoryPastReadOnlyHint;

  /// Title of the health module's trend-tab care adherence card — a heatmap summarizing care schedule adherence over a selectable period, shown below the vitals trend chart.
  ///
  /// In en, this message translates to:
  /// **'Care adherence'**
  String get careAdherenceCardTitle;

  /// Combined date-and-state text for a single heatmap cell on the care adherence card, used as both its Tooltip message and its Semantics label so the cell's state is exposed as text, not color alone, to screen readers and pointer/hover users.
  ///
  /// In en, this message translates to:
  /// **'{date} · {state}'**
  String careAdherenceHeatmapCellLabel(String date, String state);

  /// Action in the care adherence card's header that opens the care history screen, so a user who sees a missed/partial day on the heatmap can go correct that record in place instead of hunting for the list through the More tab.
  ///
  /// In en, this message translates to:
  /// **'View records'**
  String get careAdherenceOpenHistory;

  /// A care adherence card legend entry's label with its day count appended, e.g. 'Complete (12)' — so a sighted touch user can read how much of the period each day-state covers without long-pressing individual heatmap cells.
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String careAdherenceLegendWithCount(String label, int count);
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
