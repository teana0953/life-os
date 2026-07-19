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

  /// Diet shell bottom navigation label and screen title for the Today section.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dietTabToday;

  /// Diet shell bottom navigation label and screen title for the food dictionary section.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get dietTabDictionary;

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

  /// Meal chip label that switches the entry to a custom-labeled snack.
  ///
  /// In en, this message translates to:
  /// **'Add snack'**
  String get dietAddSnack;

  /// Hint text for the custom snack label text field.
  ///
  /// In en, this message translates to:
  /// **'Snack name'**
  String get dietSnackLabelHint;

  /// Hint text for the food dictionary search field.
  ///
  /// In en, this message translates to:
  /// **'Search food'**
  String get dietSearchFoodHint;

  /// Heading above the list of favorite dictionary items.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get dietFavoritesTitle;

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

  /// Label for the toggle that switches the log-entry card's amount input from unit quantity to grams.
  ///
  /// In en, this message translates to:
  /// **'Use grams'**
  String get dietUseGramsLabel;

  /// Label for the eaten-at time picker on the log-entry card.
  ///
  /// In en, this message translates to:
  /// **'Eaten at'**
  String get dietEatenAtLabel;

  /// Label for the button that saves a logged food entry.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dietSaveEntryButton;

  /// Heading above the live portion preview on the log-entry card.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get dietPreviewTitle;

  /// Screen title for logging a food entry from the dictionary.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get dietLogEntryTitle;

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

  /// Button at the bottom of the dictionary screen that opens the manual food-entry screen.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Log manually'**
  String get dietManualEntryAffordance;

  /// Screen title for logging a food not in the dictionary.
  ///
  /// In en, this message translates to:
  /// **'Log food manually'**
  String get dietManualEntryTitle;

  /// Label for the optional name text field on the manual-entry screen.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get dietManualEntryNameLabel;

  /// Fallback title shown on Today for a manually-logged entry that has no name.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get dietManualEntryFallbackName;

  /// Shown on the manual-entry screen when the user tries to save with all portions at zero.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one portion before saving.'**
  String get dietManualEntryAllZeroError;

  /// Segmented control label for showing all dictionary search results, as opposed to favorites.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dietTabAll;

  /// Shown in the All tab of the dictionary before the user has typed a search query.
  ///
  /// In en, this message translates to:
  /// **'Search for a food to see results'**
  String get dietSearchAllPrompt;

  /// Prefix shown before the dictionary-basis portion pills on the quantity card, e.g. '1碗 ＝' (unit equals) before the portions it's worth.
  ///
  /// In en, this message translates to:
  /// **'{unit} ＝'**
  String dietBasisEquals(String unit);

  /// Shows the dictionary base portion value times the entered quantity beneath the preview pills, e.g. '4 × 1.5'.
  ///
  /// In en, this message translates to:
  /// **'{base} × {quantity}'**
  String dietPreviewMathLabel(double base, double quantity);

  /// Muted, non-editable note on the daily target screen about a future exercise-based bonus.
  ///
  /// In en, this message translates to:
  /// **'✳️ Bonus portions from exercise can be added later (exercise module integration coming soon).'**
  String get dietBonusNote;

  /// Title of the bottom sheet for editing a past food entry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get dietEditEntryTitle;

  /// Label for the button that deletes a food entry, and for the destructive action in its confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dietDeleteEntryButton;

  /// Title of the confirmation dialog shown before deleting a food entry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get dietDeleteConfirmTitle;

  /// Body message of the confirmation dialog shown before deleting a food entry.
  ///
  /// In en, this message translates to:
  /// **'This removes the entry and can\'t be undone.'**
  String get dietDeleteConfirmMessage;

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

  /// Friendly empty-state message shown below the progress bars on Today when the viewed day has no logged meals.
  ///
  /// In en, this message translates to:
  /// **'No entries yet for this day'**
  String get dietDayEmpty;

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
