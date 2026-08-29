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

  /// Product name shown in the top app bar.
  ///
  /// In en, this message translates to:
  /// **'Life OS'**
  String get appTitle;

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

  /// Title of the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get passwordResetTitle;

  /// Subtitle of the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a link to set a new one.'**
  String get passwordResetSubtitle;

  /// Submit button on the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get passwordResetButton;

  /// Announced while the reset request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get passwordResetSending;

  /// Link on the sign-in screen that opens the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordLink;

  /// Heading shown after a reset request is accepted.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get passwordResetSentTitle;

  /// Confirmation after a reset request. Deliberately the same whether or not the address has an account: saying which would let anyone test whether an address uses this app.
  ///
  /// In en, this message translates to:
  /// **'If that address has an account, a reset link is on its way. It can land in spam — look for a message from noreply.'**
  String get passwordResetSentBody;

  /// Returns from the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get passwordResetBackToSignIn;

  /// Shown when the auth service throttles repeated reset requests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get errorTooManyResetRequests;

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

  /// Personalized home greeting shown before noon.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorningName(String name);

  /// Personalized home greeting shown in the afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetingAfternoonName(String name);

  /// Personalized home greeting shown in the evening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEveningName(String name);

  /// Prompt below the personalized greeting on the home hub.
  ///
  /// In en, this message translates to:
  /// **'What would you like to take care of first?'**
  String get homeHubPrompt;

  /// Action that opens the full Health app area.
  ///
  /// In en, this message translates to:
  /// **'Open Health →'**
  String get homeOpenHealth;

  /// Action that opens the full Finance app area.
  ///
  /// In en, this message translates to:
  /// **'Open Finance →'**
  String get homeOpenFinance;

  /// Label for the latest-weight home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Latest weight'**
  String get homeLatestWeight;

  /// Latest weight value on the home snapshot.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String homeWeightValue(String value);

  /// Label for the daily food-portion target home snapshot. Kept to a single short word: on a 332dp phone the label column is ~51px wide after the 44pt action icon, and 'Food portions' broke to three lines there.
  ///
  /// In en, this message translates to:
  /// **'Portions'**
  String get homeFoodPortion;

  /// Today's effective portion target on the home snapshot, all four food groups. Each count binds directly to its own one-glyph food-group icon with NO space between them, and only the group-to-group gap is a space — that tightening is the whole of issue #196's round-3 fix: it takes the string's natural width from 258.40 to 193.80 (widget-test font, titleMedium, measured — a real device render is expected to be narrower still, since the test font's fixed-width space measures the same as a digit), which moves the width at which all four groups survive from 470dp down to 386dp. That still leaves 332-385.5dp eliding the vegetable group, and that band includes 360dp and 375dp — both common phone widths, not edge cases — so this is not yet 'every mainstream phone'.
  ///
  /// In en, this message translates to:
  /// **'{staple}{stapleIcon} {meat}{meatIcon} {fruit}{fruitIcon} {veg}{vegIcon}'**
  String homeFoodPortionTargetFull(
    String staple,
    String stapleIcon,
    String meat,
    String meatIcon,
    String fruit,
    String fruitIcon,
    String veg,
    String vegIcon,
  );

  /// The same target with the vegetable group dropped, used when the tile is too narrow for all four groups to stay legible — which after the round-3 tightening is only below 386dp. Carries a bare trailing ellipsis (U+2026, no leading space) as a visible elision marker, so three groups and 'today genuinely has no vegetable target' do not look identical. Remeasured on this build: the short string's natural width is 161.50 with the marker and 145.35 without it, so the marker costs 16.15px; at the narrowest two-column tile (332dp, value box 99.00) it paints at 0.6130x, well above the 0.45 legibility floor that corner is held to. Assistive tech is also given the full four-group figure, via the tile's semantics label.
  ///
  /// In en, this message translates to:
  /// **'{staple}{stapleIcon} {meat}{meatIcon} {fruit}{fruitIcon}…'**
  String homeFoodPortionTargetShort(
    String staple,
    String stapleIcon,
    String meat,
    String meatIcon,
    String fruit,
    String fruitIcon,
  );

  /// The value semantics label for the food-portion home snapshot: the full four-group figure spelled out with the group NAME rather than its one-glyph icon (which in English is a bare letter — S/M/F/V — that does not decode when read aloud). Used regardless of whether the tile paints three groups or four.
  ///
  /// In en, this message translates to:
  /// **'Today\'s target: staple {staple}, meat {meat}, fruit {fruit}, vegetable {veg} servings'**
  String homeFoodPortionTargetSemantics(
    String staple,
    String meat,
    String fruit,
    String veg,
  );

  /// Tooltip/semantic label for the search icon on the home Portions snapshot; opens the same destination as dietOpenDictionaryTooltip, so the two share one name.
  ///
  /// In en, this message translates to:
  /// **'Open Portions'**
  String get homeFoodPortionButton;

  /// Label for the latest blood-pressure home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Latest blood pressure'**
  String get homeLatestBloodPressure;

  /// Label for the menstrual-cycle home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Cycle prediction'**
  String get homeMenstrualPrediction;

  /// Cycle snapshot while a period is ongoing.
  ///
  /// In en, this message translates to:
  /// **'Period day {days}'**
  String homeMenstrualOngoing(int days);

  /// Cycle snapshot when one more period is needed for a prediction.
  ///
  /// In en, this message translates to:
  /// **'Log one more period to predict'**
  String get homeMenstrualNeedsMore;

  /// Cycle snapshot with the predicted next date.
  ///
  /// In en, this message translates to:
  /// **'Expected {date}'**
  String homeMenstrualExpected(String date);

  /// Cycle snapshot when the next period is predicted today.
  ///
  /// In en, this message translates to:
  /// **'Expected today'**
  String get homeMenstrualToday;

  /// Cycle snapshot when the predicted date has passed.
  ///
  /// In en, this message translates to:
  /// **'Prediction passed {days} days ago'**
  String homeMenstrualOverdue(int days);

  /// Label for the overall monthly-budget home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get homeBudget;

  /// Remaining overall budget shown on the home snapshot.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String homeBudgetRemaining(String amount);

  /// Label for net worth (assets minus liabilities) on the home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get homeNetWorth;

  /// Label for total liabilities on the home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Total liabilities'**
  String get homeTotalLiabilities;

  /// Label for the split-bill home snapshot.
  ///
  /// In en, this message translates to:
  /// **'Split overview'**
  String get homeSplitOverview;

  /// Split snapshot when other people owe the user.
  ///
  /// In en, this message translates to:
  /// **'To receive {amount}'**
  String homeSplitReceivable(String amount);

  /// Split snapshot when the user owes other people.
  ///
  /// In en, this message translates to:
  /// **'To pay {amount}'**
  String homeSplitPayable(String amount);

  /// Split snapshot when no TWD balance remains.
  ///
  /// In en, this message translates to:
  /// **'All settled'**
  String get homeSplitSettled;

  /// Home snapshot fallback when no record exists.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get homeNoData;

  /// Shown in place of (or beside) one home snapshot tile's figure when that tile's own request failed. Deliberately NOT homeNoData: a failed fetch must not read as 'you have no record'.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get homeTileLoadFailed;

  /// Announced to assistive tech after one home snapshot tile's own retry succeeds, prefixed with that tile's name. Not the page-wide lastUpdatedAt: a single-tile retry deliberately does not move the dashboard's 'updated HH:mm'.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get homeTileRefreshed;

  /// Announced after a whole-dashboard refresh that landed some figures and lost others. Neither cardRefreshFailed (the screen does show newer data) nor lastUpdatedAt (some tiles are stale) is true of that round.
  ///
  /// In en, this message translates to:
  /// **'Refreshed, but some items couldn\'t load'**
  String get homeRefreshPartial;

  /// Visual stand-in painted over a home snapshot figure the user chose to hide. Lives in the ARB so presentation code never hard-codes it; screen readers get homeValueHidden instead.
  ///
  /// In en, this message translates to:
  /// **'••••'**
  String get homeMaskedValue;

  /// What a screen reader reads in place of a hidden home snapshot figure, instead of spelling out the bullet characters.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get homeValueHidden;

  /// Tooltip/semantic label of the eye button on a home snapshot tile whose figure is currently visible. Names the tile so four eyes on one screen are distinguishable.
  ///
  /// In en, this message translates to:
  /// **'Hide {label}'**
  String homeMaskHide(String label);

  /// Tooltip/semantic label of the eye button on a home snapshot tile whose figure is currently hidden. Names the tile so four eyes on one screen are distinguishable.
  ///
  /// In en, this message translates to:
  /// **'Show {label}'**
  String homeMaskShow(String label);

  /// Fallback used by isolated home views without dashboard dependencies.
  ///
  /// In en, this message translates to:
  /// **'Dashboard details are unavailable in this view.'**
  String get homeDashboardUnavailable;

  /// Shown when the home snapshot batch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your dashboard.'**
  String get homeDashboardLoadFailed;

  /// StaleNotice's subject on the home screen, i.e. what failed to refresh — not the app's name.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get homeDashboardTitle;

  /// Tooltip for the app-bar icon button that reloads the home dashboard, for keyboard/mouse users who cannot pull-to-refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get homeRefreshTooltip;

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

  /// Label of the home screen's action bar that opens the AI assistant conversation.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything'**
  String get homeAssistantBarLabel;

  /// Small badge on a home screen space tile that has no destination yet, indicating it isn't tappable.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get spaceComingSoon;

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

  /// Shown when an action that cannot be disabled (a SnackBar Undo) is tapped while another save is still in flight, so the action was refused rather than performed.
  ///
  /// In en, this message translates to:
  /// **'Still saving — try again in a moment.'**
  String get trackerStillSaving;

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

  /// Slim marker appended inside an overview card that still shows content but whose latest reload failed. Says the content was not updated rather than that it is old — a reload can fail halfway and leave part of the card fresh. Sits next to a retry that reloads only that card.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh'**
  String get cardRefreshFailed;

  /// Accessible label for a card's stale-content notice while its retry is in flight, replacing the failure label so a screen reader announces progress instead of repeating the same failure message.
  ///
  /// In en, this message translates to:
  /// **'Refreshing'**
  String get cardRefreshing;

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

  /// Heading for the signed-in account section in settings.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSectionTitle;

  /// Label for the editable display-name field in settings.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get settingsDisplayNameLabel;

  /// Explains where the user's chosen display name appears.
  ///
  /// In en, this message translates to:
  /// **'Used in your home greeting and shared activity.'**
  String get settingsDisplayNameHelper;

  /// Button that saves the chosen display name.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get settingsDisplayNameSaveButton;

  /// Confirmation after the display name is saved.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get settingsDisplayNameSaved;

  /// Error shown when updating the display name fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your name. Try again.'**
  String get settingsDisplayNameSaveFailed;

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

  /// Title of the full-screen food search when it is opened as the portion tool — with no target meal — instead of to add food to a specific meal.
  ///
  /// In en, this message translates to:
  /// **'Portions'**
  String get dietDictionaryTitle;

  /// Tooltip/accessible label for the diet screen's icon-only action that opens Portions without first choosing a meal. Named after the destination screen (dietDictionaryTitle) rather than a separate 'portion tool' term.
  ///
  /// In en, this message translates to:
  /// **'Open Portions'**
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

  /// Empty-state title shown in the food search results area when the user has no favorite foods and has not searched for anything yet.
  ///
  /// In en, this message translates to:
  /// **'No usual foods yet'**
  String get dietDictionaryFavoritesEmptyTitle;

  /// Empty-state body shown with dietDictionaryFavoritesEmptyTitle, telling the user what to do next.
  ///
  /// In en, this message translates to:
  /// **'Search for a food to see what it counts as, and tap the heart to keep it here.'**
  String get dietDictionaryFavoritesEmptyBody;

  /// Empty-state title shown in the food search results area when a search found nothing, naming the query that found nothing.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String dietDictionaryNoResultsTitle(String query);

  /// Empty-state body shown with dietDictionaryNoResultsTitle, suggesting the user search differently.
  ///
  /// In en, this message translates to:
  /// **'Try another name for it.'**
  String get dietDictionaryNoResultsBody;

  /// Error message shown in the food search results area when loading favorites or running a search fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load foods. Please try again.'**
  String get dietDictionaryLoadFailed;

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

  /// Label for the waist-circumference field on the vitals screen.
  ///
  /// In en, this message translates to:
  /// **'Waist (cm)'**
  String get vitalsWaistLabel;

  /// Trend tab and series label for waist circumference.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get trendMetricWaist;

  /// Unit shown on the waist trend.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get trendUnitCm;

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

  /// Screen-reader label for a menstrual calendar day cell that falls within a recorded period. {date} is the localized date; {cycleDay} is which day of that period it is, counting the start date as day 1 and never capped.
  ///
  /// In en, this message translates to:
  /// **'{date}, period day {cycleDay}'**
  String menstrualDaySemanticPeriod(String date, int cycleDay);

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

  /// Legend label under the menstrual calendar explaining that the smaller second number inside a filled day marker is which day of that period the day is.
  ///
  /// In en, this message translates to:
  /// **'Small number = day of period'**
  String get menstrualLegendCycleDay;

  /// First-run guidance shown on the menstrual screen when there are no recorded periods yet, so the empty statistics don't look broken.
  ///
  /// In en, this message translates to:
  /// **'No periods recorded yet. Tap a day on the calendar or \'Log period\' to start tracking.'**
  String get menstrualEmptyHint;

  /// Title of the health overview's next-period card, which opens the menstrual tracker.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get nextPeriodTitle;

  /// The overview's next-period card when the predicted next start is still ahead: the predicted date and how many days away it is. Pluralized — being one day away happens every cycle.
  ///
  /// In en, this message translates to:
  /// **'{date} · in {days, plural, =1{1 day} other{{days} days}}'**
  String nextPeriodUpcoming(String date, int days);

  /// The overview's next-period card when the predicted next start is today — said outright rather than as a zero-day countdown.
  ///
  /// In en, this message translates to:
  /// **'Expected today'**
  String get nextPeriodToday;

  /// The overview's next-period card when the predicted next start has passed: the predicted date (never rolled forward) and how long ago it was. Worded as a gap in the record, not as a late period — the app cannot tell those apart, and a lapse in logging is the commoner cause. Pluralized.
  ///
  /// In en, this message translates to:
  /// **'Expected {date} · {days, plural, =1{1 day} other{{days} days}} ago, nothing logged'**
  String nextPeriodOverdue(String date, int days);

  /// The overview's next-period card when today falls inside a recorded period: which day of it today is (the start day is day 1, and the count is uncapped so a period left open reads as such).
  ///
  /// In en, this message translates to:
  /// **'Ongoing · day {day}'**
  String nextPeriodOngoing(int day);

  /// Secondary line on the overview's next-period card while a period is ongoing, showing the predicted next start. Omitted entirely when there is no prediction.
  ///
  /// In en, this message translates to:
  /// **'Next expected {date}'**
  String nextPeriodOngoingNext(String date);

  /// The overview's next-period card when nothing has been recorded at all — deliberately not promising that one more recording enables a prediction, which it would not.
  ///
  /// In en, this message translates to:
  /// **'No periods recorded yet'**
  String get nextPeriodNoRecords;

  /// The overview's next-period card when exactly one period has been recorded, so a cycle length cannot be derived yet.
  ///
  /// In en, this message translates to:
  /// **'Record one more to predict the next'**
  String get nextPeriodNeedsOneMore;

  /// Shown on the menstrual screen when loading the overview fails (not an auth failure).
  ///
  /// In en, this message translates to:
  /// **'Unable to load your period data. Please try again.'**
  String get errorMenstrualLoadFailed;

  /// Shown on the overview's care-today summary card when its first-ever load fails (not an auth failure). Names its subject, like the other overview cards' error copy — unlike careErrorGeneric, which is written for full screens whose app bar already says what failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load today\'s care. Please try again.'**
  String get errorCareTodayLoadFailed;

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

  /// Label for the menstrual-period row in the chaodays import results.
  ///
  /// In en, this message translates to:
  /// **'Periods'**
  String get importTypeMenstrual;

  /// Caption under the import type list: chaodays periods that have not ended yet are skipped and come in on a later import
  ///
  /// In en, this message translates to:
  /// **'An ongoing period is skipped — import again after it ends.'**
  String get importMenstrualOpenPeriodHint;

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

  /// Error banner shown when a chaodays import request times out client-side. Unlike importErrorUnavailable, a timeout does not mean the import failed to reach the backend, so the copy warns against blindly re-running the same range.
  ///
  /// In en, this message translates to:
  /// **'The request took too long. It may have already gone through — check your data before importing this range again.'**
  String get importErrorTimedOut;

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

  /// Appended to every schedule's summary, whatever its weekInterval: the start date is when the schedule begins firing at all, not just the anchor an every-N-weeks interval counts from.
  ///
  /// In en, this message translates to:
  /// **'from {date}'**
  String careScheduleFrom(String date);

  /// Shown on a medication reminder's row with its remaining stock count.
  ///
  /// In en, this message translates to:
  /// **'Stock: {n}'**
  String careStockLabel(String n);

  /// A care dose quantity shown as a unit-less multiplier, e.g. ×2. The stored quantity carries no unit, so no unit word is added. The number is pre-formatted in Dart (a whole number drops its trailing .0), hence the String placeholder.
  ///
  /// In en, this message translates to:
  /// **'×{quantity}'**
  String careDoseQuantityValue(String quantity);

  /// Screen-reader label for a care slot's dose text (visually shown as e.g. '×2 · 5mg'), so assistive tech announces it as a dose rather than a bare symbol/number.
  ///
  /// In en, this message translates to:
  /// **'Dose: {label}'**
  String careDoseSemanticLabel(String label);

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

  /// Banner shown on the health overview, Today care, and care reminders management when notification permission has never been requested, warning the user their reminders won't actually arrive. Deliberately parallel to careRemindersPushDeniedBanner: same consequence clause, only the state differs, so the two states read as distinct at a glance.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t turned on yet — reminders won\'t be delivered'**
  String get careRemindersPushOffBanner;

  /// Action button on the push-off banner in both its never-requested and its blocked state, tapped to open the reminder/notification settings screen. One label for both, because it goes to the same place.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get careRemindersPushOffAction;

  /// Banner shown on the health overview, Today care, and care reminders management when notification permission was blocked by the user or the system — distinct from the never-requested wording, which would be false here. 'Blocked' matches the wording on the reminder settings screen the banner links to. Avoids naming a device, since this is a web app that also runs on desktop.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked — reminders won\'t be delivered'**
  String get careRemindersPushDeniedBanner;

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

  /// Title of the empty-state guide shown when every day in the selected period has nothing scheduled — shared by the care history screen and the trend tab's care adherence card.
  ///
  /// In en, this message translates to:
  /// **'No care records'**
  String get careHistoryEmptyTitle;

  /// Body text of the empty-state guide shown when every day in the selected period has nothing scheduled — shared by the care history screen and the trend tab's care adherence card.
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

  /// Headline metric label on the trend tab's care adherence card: the share of scheduled slots marked done over the selected period.
  ///
  /// In en, this message translates to:
  /// **'Adherence rate'**
  String get careHistoryAdherenceRateLabel;

  /// Headline metric label on the trend tab's care adherence card: the count of days with at least one slot marked done. Neutral wording — this card aggregates every care category (medication, rehab, phototherapy maintenance, custom), not just medication doses.
  ///
  /// In en, this message translates to:
  /// **'Days with care done'**
  String get careHistoryDaysWithDoseLabel;

  /// Headline metric label on the trend tab's care adherence card for the total count of slots with status missed over the selected period — worded as a slot count ('Missed slots') so it reads distinctly from careHistoryLegendMissed (a day-level heatmap state, worded as 'Missed') and from careTodayStatusMissed (a single slot's status word, 'Missed'); the three counts can differ.
  ///
  /// In en, this message translates to:
  /// **'Missed slots'**
  String get careHistoryMissedCountLabel;

  /// Heatmap legend label on the trend tab's care adherence card for a day where every *due* scheduled slot was marked done. A slot still pending (not yet due) doesn't count against this — a day with one dose taken and a later one not yet due still reads Complete, matching the adherence rate (which likewise excludes not-yet-due slots).
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get careHistoryLegendFull;

  /// Heatmap legend label on the trend tab's care adherence card for a day where some but not all scheduled slots were marked done.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get careHistoryLegendPartial;

  /// Heatmap legend label on the trend tab's care adherence card for a day that had scheduled slots but none were marked done (this includes a day where every slot was skipped). Distinct from careTodayStatusMissed (a single slot's status word) and careHistoryMissedCountLabel (the headline's slot-level missed count) — the three counts can differ.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get careHistoryLegendMissed;

  /// Heatmap legend label on the trend tab's care adherence card for a day with nothing scheduled.
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

  /// Heatmap legend label on the trend tab's care adherence card for a day whose every scheduled slot is still pending — typically today, before anything has been logged. An overdue slot (past due with no record — genuinely late) does NOT count as not-yet-due, so a day with even one overdue slot reads careHistoryLegendMissed instead. Distinct from careHistoryLegendMissed: nothing has failed here, it just hasn't happened yet.
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

  /// Caption below the care adherence card's heatmap showing the loaded period's start and end date (both already medium-date-formatted per locale), so the calendar dates a row of unlabeled squares covers are readable without long-pressing every cell. Sourced from the loaded days' first/last entries — the card has no clock of its own.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String careAdherenceHeatmapRangeCaption(String from, String to);

  /// Screen-reader-only summary announced immediately before the care adherence card's heatmap grid (design D1) — a one-line per-state day count, built from the same label+count text as the legend, so a screen reader user hears the whole picture before deciding whether to traverse the individual day cells (each of which keeps its own label).
  ///
  /// In en, this message translates to:
  /// **'Adherence by day: {details}'**
  String careAdherenceHeatmapSummaryLabel(String details);

  /// Separator joining the per-state entries inside careAdherenceHeatmapSummaryLabel's {details}. Localized rather than hard-coded ASCII: Chinese uses the ideographic comma (、) and its counts are already wrapped in full-width parentheses, so an ASCII ', ' reads as a stray half-width mark mid-sentence.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get careAdherenceHeatmapSummarySeparator;

  /// Accessibility label for the edit-record icon shown on a Done-group row (Today care checklist) or a slot tile (care history list) — a short action verb, distinct from careTodayEditSheetTitle/careHistoryEditSheetTitle (the sheet's own noun-phrase heading).
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get careEditActionLabel;

  /// Error message shown by the care adherence card and the care history screen when a period load fails, naming the period (in days) that failed so the retained period selector reads as a way out rather than an unrelated control.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the last {days} days. Please try again.'**
  String careErrorForPeriod(int days);

  /// SnackBar message on the Today care checklist when a correction is dropped by the in-flight re-entrancy guard (another mark/edit was already running) — worded as 'not applied' rather than an error, since nothing actually failed; offered alongside a retry action.
  ///
  /// In en, this message translates to:
  /// **'Not applied — nothing was changed. Please try again.'**
  String get careHistoryEditNotAppliedMessage;

  /// Title shown in the care history screen's empty state once the period is already the longest (90 days) and widening is no longer offered — distinct from careHistoryEmptyTitle ('No care records'), since at this point the likelier cause is having no care items configured at all, not merely an empty date range.
  ///
  /// In en, this message translates to:
  /// **'No care items yet'**
  String get careHistoryNoCareItemsTitle;

  /// Body copy paired with careHistoryNoCareItemsTitle, prompting the user toward care management rather than describing an empty date range (distinct from careHistoryEmptyBody, 'Nothing was scheduled in this period.').
  ///
  /// In en, this message translates to:
  /// **'You haven\'t set up any care items yet. Add one to start tracking.'**
  String get careHistoryNoCareItemsBody;

  /// A small line at the top of a data-bearing health screen (overview, trends, and the day-keyed trackers) showing the clock time its data was last successfully loaded, so the user can tell how old the shown content is. {time} is a localized clock time following the system 12/24-hour setting (e.g. '9:41 AM' or '21:41'), not a machine timestamp.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String lastUpdatedAt(String time);

  /// Title of the confirmation dialog shown when the user pulls to refresh the vitals screen while it holds unsaved edits — reloading would overwrite the draft, so it confirms first.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get refreshDiscardTitle;

  /// Body of the confirmation dialog shown when pulling to refresh the vitals screen with unsaved edits, explaining that a refresh replaces the draft with freshly loaded data.
  ///
  /// In en, this message translates to:
  /// **'Refreshing will discard your unsaved changes.'**
  String get refreshDiscardMessage;

  /// Confirm button on the refresh-with-unsaved-changes dialog — proceeds with the reload and drops the unsaved draft.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Generic cancel button — dismisses the refresh-with-unsaved-changes dialog without reloading, keeping the draft.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Title of the bottom sheet used to create a new shared dictionary item.
  ///
  /// In en, this message translates to:
  /// **'New shared item'**
  String get sharedFoodItemCreateTitle;

  /// Title of the bottom sheet used to edit an existing shared dictionary item.
  ///
  /// In en, this message translates to:
  /// **'Edit shared item'**
  String get sharedFoodItemEditTitle;

  /// Label for the name field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sharedFoodItemNameLabel;

  /// Label for the carbohydrate (grams) field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get sharedFoodItemCarbLabel;

  /// Label for the protein (grams) field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get sharedFoodItemProteinLabel;

  /// Label for the fat (grams) field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get sharedFoodItemFatLabel;

  /// Label for the sugar (grams) field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Sugar (g)'**
  String get sharedFoodItemSugarLabel;

  /// Label for the fiber (grams) field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Fiber (g)'**
  String get sharedFoodItemFiberLabel;

  /// Label for the calories (kcal) field on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal)'**
  String get sharedFoodItemKcalLabel;

  /// Label for the measure-basis amount field (e.g. 50 for '50g') on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Measure amount'**
  String get sharedFoodItemMeasureAmountLabel;

  /// Label for the measure-basis unit field ('g' or 'ml') on the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Measure unit'**
  String get sharedFoodItemMeasureUnitLabel;

  /// Label for the shared dictionary item form's submit button, for both create and edit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sharedFoodItemSubmitButton;

  /// Validation error shown next to the measure fields when only one of amount/unit is filled in.
  ///
  /// In en, this message translates to:
  /// **'Give both the measure amount and unit, or leave them both empty.'**
  String get sharedFoodItemMeasurePairError;

  /// Validation error shown next to the measure amount field when it is zero or negative.
  ///
  /// In en, this message translates to:
  /// **'The measure amount must be greater than zero.'**
  String get sharedFoodItemMeasureAmountPositiveError;

  /// Validation error shown on the shared dictionary item form when a numeric macro/portion field is unparseable or negative, naming the offending field's label.
  ///
  /// In en, this message translates to:
  /// **'{field} must be zero or a positive number.'**
  String sharedFoodItemNumberFieldError(String field);

  /// Validation error shown next to the name field on the shared dictionary item form (create or edit mode) when it is blank; blocks submission.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get sharedFoodItemNameRequiredError;

  /// SnackBar shown after successfully creating a shared dictionary item.
  ///
  /// In en, this message translates to:
  /// **'Shared item created.'**
  String get sharedFoodItemCreateSuccess;

  /// SnackBar shown after successfully editing a shared dictionary item.
  ///
  /// In en, this message translates to:
  /// **'Shared item updated.'**
  String get sharedFoodItemEditSuccess;

  /// Error shown in the shared dictionary item form when the backend refuses the request because the user is not an administrator, distinct from a generic retryable failure.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get sharedFoodItemForbiddenError;

  /// Retryable error shown in the shared dictionary item form when the create/update request fails for a reason other than a permission refusal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again.'**
  String get sharedFoodItemSaveFailed;

  /// Error shown in the shared dictionary item form when the create/update request fails because the session expired (401), distinct from the generic retryable saveFailed message so the admin knows retrying won't help without signing in again.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to save this.'**
  String get sharedFoodItemNeedsReauthError;

  /// Tooltip/accessible label for the app-bar action, shown only to administrators, that opens the empty create-shared-item form.
  ///
  /// In en, this message translates to:
  /// **'New shared item'**
  String get createSharedItemTooltip;

  /// Tooltip/accessible label for the per-row action, shown only to administrators on shared items, that opens the edit-shared-item form.
  ///
  /// In en, this message translates to:
  /// **'Edit shared item'**
  String get editSharedItemTooltip;

  /// Label for the single item inside the per-row '⋮' menu on a shared item, shown only to administrators. Kept short and generic (unlike the menu's own descriptive tooltip) since the menu already scopes it to this row; a future 'delete' entry will join it in the same menu.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editSharedItemMenuLabel;

  /// Section heading above the four food-group portion fields (staple/meat/fruit/veg) in the shared dictionary item form, naming them as portion counts.
  ///
  /// In en, this message translates to:
  /// **'Portions'**
  String get sharedFoodItemPortionsHeading;

  /// Section heading above the six macro/calorie fields (carbs/protein/fat/sugar/fiber/kcal) in the shared dictionary item form.
  ///
  /// In en, this message translates to:
  /// **'Nutrients'**
  String get sharedFoodItemNutrientsHeading;

  /// Bottom-nav destination label for the finance shell's overview tab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get financeTabOverview;

  /// Bottom-nav destination label for the finance shell's transaction-list tab.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get financeTabTransactions;

  /// Tooltip/accessible label for the finance shell's floating action button that opens the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Record a transaction'**
  String get financeFabTooltip;

  /// Tooltip on the secondary FAB that opens the recurring-charge (instalment plan) form.
  ///
  /// In en, this message translates to:
  /// **'Set up a recurring charge'**
  String get financeInstallmentFabTooltip;

  /// Confirmation shown after an instalment plan is settled in one go.
  ///
  /// In en, this message translates to:
  /// **'Plan settled'**
  String get financeInstallmentSettled;

  /// Heading shown at the top of the record sheet when creating a new transaction.
  ///
  /// In en, this message translates to:
  /// **'Record a transaction'**
  String get financeAddTitle;

  /// Heading shown at the top of the record sheet when editing an existing transaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get financeEditTitle;

  /// Label for the amount field in the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get financeAmountLabel;

  /// Label for the expense option in the record sheet's expense/income toggle, and for the expense total on the overview card.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get financeTypeExpense;

  /// Label for the income option in the record sheet's expense/income toggle, and for the income total on the overview card.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get financeTypeIncome;

  /// Label above the category grid in the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get financeCategoryLabel;

  /// Label for the date field in the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get financeDateLabel;

  /// Label for the currency selector in the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get financeCurrencyLabel;

  /// Label for the optional note field in the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get financeNoteLabel;

  /// Label for the record sheet's save/submit button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get financeSaveButton;

  /// Label for the delete action shown in the record sheet when editing an existing transaction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get financeDeleteButton;

  /// Title of the confirmation dialog shown before deleting a transaction.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get financeDeleteConfirmTitle;

  /// Body text of the confirmation dialog shown before deleting a transaction.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get financeDeleteConfirmMessage;

  /// Confirm button label in the delete-transaction confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get financeDeleteConfirmButton;

  /// Cancel button label in the delete-transaction confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get financeCancelButton;

  /// Snackbar shown when recording/editing/deleting a transaction fails for a retryable reason (network/server error); the sheet stays open with its content intact.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please check your connection and try again.'**
  String get financeSaveFailed;

  /// Error message shown (with a retry action) when the finance month fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your finance data.'**
  String get financeLoadFailed;

  /// Snackbar shown when a background reload of the ledger (triggered by a split write or returning from group detail) fails, on a screen other than the two ledger tabs that already carry their own stale notice.
  ///
  /// In en, this message translates to:
  /// **'The ledger didn\'t update.'**
  String get financeLedgerNotUpdated;

  /// Empty-state guide shown on the overview and transactions tabs when the selected month has no transactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet this month'**
  String get financeEmptyTitle;

  /// Call-to-action button in the empty-state guide that opens the record sheet.
  ///
  /// In en, this message translates to:
  /// **'Record your first one'**
  String get financeEmptyCta;

  /// Row label for a currency's expense total on the overview cards.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get financeExpenseTotal;

  /// Row label for a currency's income total on the overview cards.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get financeIncomeTotal;

  /// Row label for a currency's net (income - expense) total on the overview cards.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get financeNetTotal;

  /// Section heading above the five most recent transactions on the overview tab.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get financeRecentTransactions;

  /// Label for the overview tab's own line showing what the user personally owed on split expenses that month — shown beside, never folded into, the recorded expense total or the budget card.
  ///
  /// In en, this message translates to:
  /// **'Your split spending'**
  String get financeSplitSpendingTitle;

  /// Heading above the split-spending card's group of currencies whose shares the server already mirrored into the user's transactions. Only shown when that group has something in it — an empty group reads as 'this is zero'.
  ///
  /// In en, this message translates to:
  /// **'Counted in your totals'**
  String get financeSplitSpendingCountedHeading;

  /// Sentence stated beside the counted group's own amounts on the overview tab's split-spending card. The card is otherwise indistinguishable from a totals card, and whether the money is already counted is the only thing the reader needs from it.
  ///
  /// In en, this message translates to:
  /// **'Already in the totals above, and in any budget.'**
  String get financeSplitSpendingCountedNote;

  /// Heading above the split-spending card's group of currencies the server cannot mirror into transactions. Only shown when that group has something in it.
  ///
  /// In en, this message translates to:
  /// **'Not counted in your totals'**
  String get financeSplitSpendingUncountedHeading;

  /// Sentence stated beside the uncounted group's own amounts on the overview tab's split-spending card.
  ///
  /// In en, this message translates to:
  /// **'Not in the totals above — this currency cannot be a transaction.'**
  String get financeSplitSpendingUncountedNote;

  /// Marker on a ledger row the server mirrored out of a split expense, so the user can tell it apart from a row they recorded themselves before opening it — a mirrored row cannot be deleted and most of its fields cannot be edited.
  ///
  /// In en, this message translates to:
  /// **'From a split'**
  String get financeSplitMirrorBadge;

  /// Title of the edit sheet for a transaction the server mirrored out of a split expense. {label} is the transaction's own note, which starts out as the split's description but belongs to the user afterwards — they can edit it in this same sheet, so this is not 'the split's description'.
  ///
  /// In en, this message translates to:
  /// **'From a split · {label}'**
  String financeSplitMirrorSheetTitle(String label);

  /// Action on the mirrored-transaction sheet that leaves for the split records, where the locked parts are changed. Without it the sentence telling the user to go there is a dead end they have to walk alone.
  ///
  /// In en, this message translates to:
  /// **'Go to splits'**
  String get financeSplitMirrorGoToSplit;

  /// Sentence under the mirrored-transaction sheet's two editable fields, explaining where everything else is changed — the sheet shows those as facts rather than as inputs, and has no delete action at all.
  ///
  /// In en, this message translates to:
  /// **'The amount, date, currency and type are changed on the split itself, and this row can only be deleted there.'**
  String get financeSplitMirrorLockedNote;

  /// Shown when the server refuses the save because the split moved on between the sheet opening and the save (HTTP 409). Deliberately not the generic save-failed copy: retrying the same values would be refused the same way, so the message says the record moved and the sheet shows the current values instead.
  ///
  /// In en, this message translates to:
  /// **'This split was just changed. The current amount and date are shown now — check them and save again.'**
  String get financeSplitChangedReloaded;

  /// Shown when saving a mirrored transaction returns 404: the split it mirrored was deleted and took this row with it. The sheet closes rather than leaving the user editing a record that no longer exists.
  ///
  /// In en, this message translates to:
  /// **'The payer deleted this split, so this record is gone.'**
  String get financeSplitDeletedElsewhere;

  /// Shown when a save is refused because the transaction no longer exists, on a row the user recorded themselves.
  ///
  /// In en, this message translates to:
  /// **'This record is gone — it may have been deleted on another device.'**
  String get financeTransactionGoneElsewhere;

  /// Shown when the reload after a refused save cannot find the row in the selected month — the payer moved the split's date into a different month. Treated like a deleted one: the sheet closes rather than showing stale facts.
  ///
  /// In en, this message translates to:
  /// **'This split is no longer in this month.'**
  String get financeSplitMovedOutOfMonth;

  /// Shown in place of the split-spending line when it fails to load; the rest of the overview (recorded totals, budget card) still shows normally.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your split spending'**
  String get financeSplitSpendingLoadFailed;

  /// Section heading above the per-category expense breakdown bars on the overview tab.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get financeCategoryBreakdown;

  /// Title of the budget progress card on the overview tab.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get financeBudgetCardTitle;

  /// Row label for the overall (non-category-specific) budget.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get financeBudgetOverallLabel;

  /// Guidance shown on the budget card when no budgets are set.
  ///
  /// In en, this message translates to:
  /// **'No budgets set yet'**
  String get financeBudgetEmptyTitle;

  /// Call-to-action button on the budget card's empty state, opens the budget sheet.
  ///
  /// In en, this message translates to:
  /// **'Set a budget'**
  String get financeBudgetEmptyCta;

  /// Badge label shown on a budget row that has reached or exceeded 100%.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get financeBudgetOverLabel;

  /// Title of the budget-setting bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get financeBudgetSheetTitle;

  /// Explanatory text shown under the budget sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Budgets are recurring monthly settings and apply to every month.'**
  String get financeBudgetSheetHint;

  /// Shown under an archived category's budget field in the budget sheet.
  ///
  /// In en, this message translates to:
  /// **'Archived — can only be cleared'**
  String get financeBudgetArchivedLabel;

  /// Button that marks an archived category's budget to be deleted on save.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get financeBudgetClearButton;

  /// Shown after tapping the clear button for an archived category's budget.
  ///
  /// In en, this message translates to:
  /// **'Will be cleared'**
  String get financeBudgetClearedLabel;

  /// Field error shown when a budget amount has content but isn't a positive whole number; leaving it empty clears the budget instead.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get financeBudgetInvalidAmount;

  /// Bottom-nav destination label for the finance shell's net worth tab.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get financeTabNetWorth;

  /// Marker on a transaction that is one period of an instalment plan, shown once the plan itself (its total period count) has been fetched — the record/edit sheet and both transaction lists.
  ///
  /// In en, this message translates to:
  /// **'Period {no} of {total}'**
  String financeInstallmentPeriodOfTotal(int no, int total);

  /// Same marker as financeInstallmentPeriodOfTotal, for a plan the viewer does not own (the plan fetch answered 404, so the total period count is unknown) — the period number still rides on the transaction itself.
  ///
  /// In en, this message translates to:
  /// **'Period {no}'**
  String financeInstallmentPeriodOnly(int no);

  /// Exit from the record/edit sheet to the instalment plan an editable period belongs to. Shown only when the viewer owns that plan (tasks 2.1/2.2).
  ///
  /// In en, this message translates to:
  /// **'Manage plan'**
  String get financeInstallmentGoToPlan;

  /// Title of the standalone instalment-plan create sheet.
  ///
  /// In en, this message translates to:
  /// **'New instalment plan'**
  String get financeInstallmentCreateTitle;

  /// Mode choice on the instalment-plan create sheet: the user is entering the whole sum, split evenly across the periods.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get financeInstallmentModeTotal;

  /// Mode choice on the instalment-plan create sheet: the user is entering the fixed charge for each period (e.g. a mortgage payment), not the whole sum.
  ///
  /// In en, this message translates to:
  /// **'Amount per period'**
  String get financeInstallmentModePerInstallment;

  /// Amount field label in total mode — asks how much altogether, not the per-period figure.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get financeInstallmentTotalAmountLabel;

  /// Amount field label in per-instalment mode — asks how much each period, not the whole sum. A different label from financeInstallmentTotalAmountLabel is not decoration: the same field means a different number in each mode, and a user who mistakes one for the other gets a plan 12x or 1/12 off with no error anywhere.
  ///
  /// In en, this message translates to:
  /// **'Amount per period'**
  String get financeInstallmentPerAmountLabel;

  /// Field label for how many periods the instalment plan runs — required; open-ended subscriptions are not supported yet (see financeInstallmentNoEndDateWarning).
  ///
  /// In en, this message translates to:
  /// **'Number of periods'**
  String get financeInstallmentPeriodsLabel;

  /// Live preview under the amount/periods fields in total mode: the total divided by the period count, so a typo reads as an obviously wrong per-period figure before saving.
  ///
  /// In en, this message translates to:
  /// **'= {perPeriod} per period'**
  String financeInstallmentPreviewPerPeriod(String perPeriod);

  /// Live preview under the amount/periods fields in per-instalment mode: the per-period amount multiplied by the period count, so a typo reads as an obviously wrong total before saving.
  ///
  /// In en, this message translates to:
  /// **'= {total} total'**
  String financeInstallmentPreviewTotal(String total);

  /// Notice on the instalment-plan create sheet: every plan needs a fixed period count, so an open-ended subscription cannot be modelled yet.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions with no end date aren\'t supported yet — enter a number of periods.'**
  String get financeInstallmentNoEndDateWarning;

  /// Submit button on the instalment-plan create sheet.
  ///
  /// In en, this message translates to:
  /// **'Create plan'**
  String get financeInstallmentSaveButton;

  /// Title of the instalment plan's own page.
  ///
  /// In en, this message translates to:
  /// **'Instalment plan'**
  String get financeInstallmentPlanTitle;

  /// Action on the plan page that pays the plan off early.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get financeInstallmentSettleButton;

  /// Amount field shown only for a per-instalment plan's settle action — the system cannot compute this payoff (it may include future interest), so the bank's own figure is required.
  ///
  /// In en, this message translates to:
  /// **'Payoff amount (from your bank)'**
  String get financeInstallmentSettleAmountLabel;

  /// Confirms the settle action.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get financeInstallmentSettleConfirm;

  /// Explains why a total-mode plan's settle action asks for no amount: the system computes it from what's left.
  ///
  /// In en, this message translates to:
  /// **'The remaining periods add up to the payoff automatically — no amount to enter.'**
  String get financeInstallmentSettleTotalNote;

  /// Explains why a per-instalment plan's settle action asks for an amount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount your bank quoted — it may include interest the app has no way to compute.'**
  String get financeInstallmentSettlePerNote;

  /// Generic fallback marker for an instalment-period row when the plan behind it hasn't been resolved (rare — the list rows normally know the period count and use financeInstallmentPeriodOfTotal instead).
  ///
  /// In en, this message translates to:
  /// **'Instalment'**
  String get financeInstallmentBadge;

  /// Label above the headline net worth figure.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get networthNetWorthLabel;

  /// Direction word shown with the growth arrow when net worth grew month over month (never color alone).
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get networthGrowthUp;

  /// Direction word shown with the growth arrow when net worth fell month over month (never color alone).
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get networthGrowthDown;

  /// Direction word shown when net worth was unchanged month over month (0%) — neither a rise nor a fall, so no arrow is shown.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get networthGrowthFlat;

  /// Row label for the sum of this month's snapshots belonging to archived accounts, which are no longer listed individually but still count toward the group total.
  ///
  /// In en, this message translates to:
  /// **'Archived accounts'**
  String get networthArchivedSubtotal;

  /// Section heading above the asset accounts in the net worth tab.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get networthAssetsTitle;

  /// Section heading above the liability accounts in the net worth tab.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get networthLiabilitiesTitle;

  /// Row label for the sum of the month's asset snapshots.
  ///
  /// In en, this message translates to:
  /// **'Total assets'**
  String get networthTotalAssets;

  /// Row label for the sum of the month's liability snapshots.
  ///
  /// In en, this message translates to:
  /// **'Total liabilities'**
  String get networthTotalLiabilities;

  /// Section heading above the net worth trend chart.
  ///
  /// In en, this message translates to:
  /// **'Net worth trend'**
  String get networthTrendTitle;

  /// Shown instead of the trend chart when fewer than two months have snapshots.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet — keep recording to see your trend.'**
  String get networthTrendInsufficient;

  /// Accessible summary read in place of the trend chart's visuals.
  ///
  /// In en, this message translates to:
  /// **'Net worth trend over the last months.'**
  String get networthTrendSummary;

  /// Empty-month guide title in the net worth tab.
  ///
  /// In en, this message translates to:
  /// **'No values recorded for this month yet'**
  String get networthEmptyTitle;

  /// Empty-month guide call to action that opens the value sheet.
  ///
  /// In en, this message translates to:
  /// **'Record your first value'**
  String get networthEmptyCta;

  /// Tooltip/title for the net worth account management sheet.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get networthManageAccounts;

  /// Button that creates a new net worth account.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get networthAddAccount;

  /// Label for the net worth account name field.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get networthAccountNameLabel;

  /// The asset account kind.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get networthKindAsset;

  /// The liability account kind.
  ///
  /// In en, this message translates to:
  /// **'Liability'**
  String get networthKindLiability;

  /// Button that archives a net worth account (its past snapshots still count).
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get networthArchiveButton;

  /// Button that un-archives a net worth account.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get networthRestoreButton;

  /// Marks an archived net worth account in the management sheet.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get networthArchivedLabel;

  /// Tooltip for the button that moves a net worth account earlier in its group.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get networthMoveUpTooltip;

  /// Tooltip for the button that moves a net worth account later in its group.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get networthMoveDownTooltip;

  /// Label for the monthly market-value field in the snapshot sheet.
  ///
  /// In en, this message translates to:
  /// **'Value (TWD)'**
  String get networthValueLabel;

  /// Shown as an account's value when the selected month has no snapshot for it.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get networthNotRecorded;

  /// Field error when the typed market value isn't a non-negative whole number; leaving it empty means the month is unrecorded.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of 0 or more'**
  String get networthInvalidValue;

  /// Title of the bottom sheet that records an account's value for the selected month.
  ///
  /// In en, this message translates to:
  /// **'Update value'**
  String get networthSnapshotSheetTitle;

  /// Field error shown when an account's name is cleared while renaming it; the rename can't be saved until a name is typed.
  ///
  /// In en, this message translates to:
  /// **'Enter an account name'**
  String get networthAccountNameRequired;

  /// Tooltip/accessible label for the button that saves a typed account name.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get networthSaveNameTooltip;

  /// Tooltip/accessible label for the shared month header's previous-month arrow.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get monthNavPreviousTooltip;

  /// Tooltip/accessible label for the shared month header's next-month arrow.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get monthNavNextTooltip;

  /// Title of the dialog that jumps the view to any year and month.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get monthPickerTitle;

  /// Tooltip/accessible label for the month picker's previous-year arrow.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get monthPickerPreviousYearTooltip;

  /// Tooltip/accessible label for the month picker's next-year arrow.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get monthPickerNextYearTooltip;

  /// Tooltip/accessible label for the month picker's year label, which opens a scrollable list of years.
  ///
  /// In en, this message translates to:
  /// **'Select year'**
  String get monthPickerYearTooltip;

  /// Tooltip/accessible label for a month label that opens the month picker.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get monthPickerOpenTooltip;

  /// AppBar title of the friends page.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// Empty-state title on the friends page when the user has no friends.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsEmptyTitle;

  /// Empty-state body text explaining how to add a friend, shown together with the invite action.
  ///
  /// In en, this message translates to:
  /// **'Invite someone using a link to add your first friend.'**
  String get friendsEmptyMessage;

  /// Button that creates a new invite link on the friends page.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get friendsInviteButton;

  /// Label of the same create-invite button once a link is already on screen — creating another one replaces it, so the label says what it does instead of 'Invite a friend'.
  ///
  /// In en, this message translates to:
  /// **'Create another link'**
  String get friendsInviteAnotherButton;

  /// Title of the confirmation shown when the user asks for a new invite link while an uncopied one is still displayed.
  ///
  /// In en, this message translates to:
  /// **'Create another link?'**
  String get friendsCreateAnotherConfirmTitle;

  /// Body of the confirmation shown before replacing an uncopied invite link, explaining that the old link is lost for good.
  ///
  /// In en, this message translates to:
  /// **'The link above hasn\'t been copied yet. A new link replaces it, and it can\'t be shown again.'**
  String get friendsCreateAnotherConfirmMessage;

  /// Confirm action of the replace-the-uncopied-invite-link dialog.
  ///
  /// In en, this message translates to:
  /// **'Replace it'**
  String get friendsCreateAnotherConfirmButton;

  /// Error message shown on the friends page when loading friends/invites fails, alongside a retry action.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your friends.'**
  String get friendsLoadErrorMessage;

  /// Section header above the list of friends on the friends page.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsSectionFriends;

  /// Section header above the list of the user's own still-usable invites on the friends page.
  ///
  /// In en, this message translates to:
  /// **'Outstanding invites'**
  String get friendsSectionInvites;

  /// Tooltip/accessible label for the button that starts removing a friend (opens the confirmation dialog).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get friendsRemoveTooltip;

  /// Title of the confirmation dialog shown before removing a friend, naming the friend being removed.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String friendsRemoveConfirmTitle(String name);

  /// Body text of the remove-friend confirmation dialog, naming the friend being removed.
  ///
  /// In en, this message translates to:
  /// **'You and {name} will no longer be friends.'**
  String friendsRemoveConfirmMessage(String name);

  /// Confirm button label in the remove-friend confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get friendsRemoveConfirmButton;

  /// Shown when removing a friend fails because the friendship is already gone (404). Deliberately distinct from the invite-invalid-link copy shown on the invite page.
  ///
  /// In en, this message translates to:
  /// **'That friendship no longer exists.'**
  String get friendsRemoveNotFoundMessage;

  /// Generic error shown when removing a friend fails for a reason other than the friendship already being gone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove that friend. Try again.'**
  String get friendsRemoveFailedMessage;

  /// Heading above the just-created invite link and its copy action on the friends page.
  ///
  /// In en, this message translates to:
  /// **'Your invite link'**
  String get friendsInviteLinkTitle;

  /// Button that copies the invite link to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get friendsCopyButton;

  /// SnackBar confirmation shown after the invite link is copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get friendsCopiedMessage;

  /// SnackBar shown when copying the invite link to the clipboard fails (e.g. the browser rejects the clipboard write); the link text stays on screen so the user can select and copy it manually.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t copy. Select the link above to copy it manually.'**
  String get friendsCopyFailedMessage;

  /// Error message shown when creating a new invite fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create an invite link. Try again.'**
  String get friendsCreateInviteFailedMessage;

  /// Shown when the invite was created successfully but the follow-up refresh of the friends/invites lists failed. Deliberately distinct from the creation-failed message: the link is on screen and must still be copied.
  ///
  /// In en, this message translates to:
  /// **'Invite link created, but the list couldn\'t be refreshed.'**
  String get friendsCreateInviteRefreshFailedMessage;

  /// Warning shown with a freshly created invite link: the plaintext token exists only in the create response, so leaving the page loses the link for good.
  ///
  /// In en, this message translates to:
  /// **'Copy it now — this link is shown only once and can\'t be retrieved later.'**
  String get friendsInviteLinkOnceWarning;

  /// Shows an outstanding invite's creation date and time, already formatted for display. Distinguishes invites that share an expiry date.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String friendsInviteCreatedLabel(String date);

  /// Shows an outstanding invite's expiry date, already formatted for display.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String friendsInviteExpiresLabel(String date);

  /// Button that revokes an outstanding invite; opens a confirmation first.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get friendsRevokeButton;

  /// Title of the confirmation shown before revoking an outstanding invite.
  ///
  /// In en, this message translates to:
  /// **'Revoke this invite?'**
  String get friendsRevokeConfirmTitle;

  /// Body of the revoke confirmation, explaining that the cost of revoking lands on the person holding the link.
  ///
  /// In en, this message translates to:
  /// **'The link you already shared will stop working, and whoever has it won\'t be able to accept.'**
  String get friendsRevokeConfirmMessage;

  /// Confirming action of the revoke-invite confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get friendsRevokeConfirmButton;

  /// Shown when revoking an invite answers 404 because it is already gone; the listed row was stale and the list is refreshed.
  ///
  /// In en, this message translates to:
  /// **'That invite no longer exists.'**
  String get friendsRevokeNotFoundMessage;

  /// Error message shown when revoking an outstanding invite fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t revoke that invite. Try again.'**
  String get friendsRevokeFailedMessage;

  /// AppBar title of the invite page. The bar also carries the page's only exit, so it is present in every state.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get inviteTitle;

  /// Shown on the invite page after a successful preview, naming the inviter.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to be friends'**
  String inviteFromMessage(String name);

  /// Button that accepts a previewed invite, creating the friendship. Disabled while the request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get inviteAcceptButton;

  /// Shown on the invite page when preview or accept reports the user is already friends with the inviter — worded distinctly from a fresh acceptance.
  ///
  /// In en, this message translates to:
  /// **'You\'re already friends with {name}.'**
  String inviteAlreadyFriendsMessage(String name);

  /// Button on the invite page's error/already-friends states that returns to the friends list.
  ///
  /// In en, this message translates to:
  /// **'Back to friends'**
  String get inviteBackToFriendsButton;

  /// Shown on the invite page when the invite has expired.
  ///
  /// In en, this message translates to:
  /// **'This invite has expired. Ask for a new link.'**
  String get inviteExpiredMessage;

  /// Shown on the invite page when the invite has already been used.
  ///
  /// In en, this message translates to:
  /// **'This invite has already been used.'**
  String get inviteAlreadyUsedMessage;

  /// Shown on the invite page when the invite was revoked by the person who created it.
  ///
  /// In en, this message translates to:
  /// **'This invite was revoked.'**
  String get inviteRevokedMessage;

  /// Shown on the invite page for an unknown link (404), a blank/missing token, or a malformed request.
  ///
  /// In en, this message translates to:
  /// **'This link is invalid. Check that it was copied in full.'**
  String get inviteInvalidMessage;

  /// Shown on the invite page for a generic/network failure while previewing or accepting the invite (SocialFetchFailure) — distinct from the invalid-link message since the link itself may be fine, and paired with a retry action.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this invite. Check your connection and try again.'**
  String get inviteFetchFailedMessage;

  /// Shown on the invite page after the user activates accept on their own invite link (only detectable at that point, not at preview).
  ///
  /// In en, this message translates to:
  /// **'This is your own invite link.'**
  String get inviteOwnInviteMessage;

  /// Heading for the friends section of the settings page.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get settingsFriendsSectionTitle;

  /// Label of the settings row that navigates to the friends page.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get settingsFriendsRowLabel;

  /// Shown when writing the Gemini key to device storage fails. The typed key is kept so the user can retry without pasting again.
  ///
  /// In en, this message translates to:
  /// **'Could not save the key on this device. Private browsing or cleared site data can block it — try again, or use a normal window.'**
  String get settingsAssistantSaveFailed;

  /// Heading for the AI assistant section of the settings page, where the user manages their Gemini API key.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get settingsAssistantSectionTitle;

  /// Tappable link to aistudio.google.com, where the user creates the key. Its own element rather than text inside a paragraph — the address is the one thing the user has to take somewhere else, and a link that cannot be tapped is where a bring-your-own-key feature loses people.
  ///
  /// In en, this message translates to:
  /// **'Create a key in Google AI Studio'**
  String get settingsAssistantGetKeyLink;

  /// Shown when launching the URL fails, and it names the address so the user is not left with a dead button.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. The address is aistudio.google.com'**
  String get settingsAssistantGetKeyFailed;

  /// Intro shown in the assistant settings section when no key is stored yet, telling the user where to obtain a Gemini API key.
  ///
  /// In en, this message translates to:
  /// **'Paste a Gemini API key to enable the AI assistant. You can create one for free — no card needed.'**
  String get settingsAssistantIntro;

  /// Label of the obscured text field where the user pastes their Gemini API key.
  ///
  /// In en, this message translates to:
  /// **'Gemini API key'**
  String get settingsAssistantKeyFieldLabel;

  /// Hint text inside the empty Gemini API key field.
  ///
  /// In en, this message translates to:
  /// **'Paste your Gemini API key'**
  String get settingsAssistantKeyFieldHint;

  /// Button that saves the pasted Gemini API key to the device.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get settingsAssistantSaveKeyButton;

  /// Button that removes the stored Gemini API key from the device.
  ///
  /// In en, this message translates to:
  /// **'Clear key'**
  String get settingsAssistantClearKeyButton;

  /// Status line shown when a Gemini API key is stored; last4 is the final four characters of the key, the only fragment ever displayed.
  ///
  /// In en, this message translates to:
  /// **'Key set (****{last4})'**
  String settingsAssistantKeySet(String last4);

  /// Always-visible disclosure in the assistant settings section that free-tier Gemini content, including anything sent via the health-access switch above, may be used for model training. Stated once for the whole section, not repeated per feature.
  ///
  /// In en, this message translates to:
  /// **'On the Gemini free tier, Google may use what you send to improve its models.'**
  String get settingsAssistantTrainingNotice;

  /// Always-visible notice in the assistant settings section that the key lives in device-local storage and does not survive signing out, a PWA reinstall, or cleared browser data — and that the same event also resets the health-access switch above, since consent is stored alongside the key. Stated once for the whole section, not repeated per feature.
  ///
  /// In en, this message translates to:
  /// **'The key is stored only on this device. Signing out, reinstalling the app, or clearing browser data removes it and turns the health-access switch back off — you\'ll need to paste the key and turn the switch back on again.'**
  String get settingsAssistantDeviceNotice;

  /// Label of the switch in the assistant settings section that grants the assistant read access to the user's health, diet and care records. Off by default. Care records ride this same single opt-in — there is no separate care switch — so the label names the same scope the disclosure beside it does.
  ///
  /// In en, this message translates to:
  /// **'Let the assistant read my health, diet and care records'**
  String get settingsAssistantHealthLabel;

  /// Always-visible disclosure beside the health-access switch, naming the record types (menstrual cycles, blood glucose, vital signs, and care records such as medication and rehabilitation — the app's own care categories) and the destination (Google's Gemini). Phrased as a standing rule about how the feature works, not as a notice that something has happened. The free-tier training use is stated once, in settingsAssistantTrainingNotice below, rather than repeated here.
  ///
  /// In en, this message translates to:
  /// **'With this on, the assistant can read your health, diet and care records — including menstrual cycles, blood glucose, vital signs and care records such as medication and rehabilitation — and sends them to Google\'s Gemini.'**
  String get settingsAssistantHealthDisclosure;

  /// Notice shown in the assistant settings section when no Gemini API key is stored: the health-access switch can still be set, but no request is made at all until a key exists.
  ///
  /// In en, this message translates to:
  /// **'With no key saved, the assistant sends nothing anywhere — this setting takes effect once you add one.'**
  String get settingsAssistantHealthNoKeyNotice;

  /// Label of the finance shell's fourth bottom-nav destination and app bar title, for the split-expenses tab.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get financeTabSplit;

  /// Tooltip for the split tab's floating action button, which opens the record-expense sheet.
  ///
  /// In en, this message translates to:
  /// **'Record a split expense'**
  String get splitFabTooltip;

  /// Title shown on the split tab when the caller has no groups, balances, or expenses at all.
  ///
  /// In en, this message translates to:
  /// **'No split expenses yet'**
  String get splitEmptyTitle;

  /// Call-to-action button in the split tab's empty state, opening the record-expense sheet.
  ///
  /// In en, this message translates to:
  /// **'Record a split expense'**
  String get splitEmptyCta;

  /// Shown on the split tab when loading balances/groups/expenses fails for a reason other than needing reauthentication.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your split expenses. Check your connection and try again.'**
  String get splitLoadFailedMessage;

  /// Shown on the split tab when the caller's own profile (needed to gate the split UI) could not be fetched — design D5c: the tab goes to an error state rather than carrying a null user id forward.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile. Try again.'**
  String get splitProfileFailedMessage;

  /// Heading for the split tab's list of people who owe the caller money.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get splitSectionOwedToMe;

  /// One row under the 'owed to you' heading: the person's name and the amount, already formatted with currency grouping.
  ///
  /// In en, this message translates to:
  /// **'{name} owes you {amount}'**
  String splitOwedToMeRow(String name, String amount);

  /// Heading for the split tab's list of people the caller owes money to.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get splitSectionOwedByMe;

  /// One row under the 'you owe' heading: the person's name and the amount, already formatted with currency grouping.
  ///
  /// In en, this message translates to:
  /// **'You owe {name} {amount}'**
  String splitOwedByMeRow(String name, String amount);

  /// Heading for the split tab's list of the caller's groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get splitSectionGroups;

  /// Shown in the groups section of the split tab when the caller has no groups.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get splitNoGroupsYet;

  /// Button on the split tab that opens the create-group dialog.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get splitAddGroupButton;

  /// Heading for the split tab's list of recent split expenses.
  ///
  /// In en, this message translates to:
  /// **'Recent expenses'**
  String get splitSectionRecentExpenses;

  /// Shown in the recent-expenses section of the split tab when there are none.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get splitNoExpensesYet;

  /// Subtitle of an expense row: who fronted the money, and the day it was spent. The payer's name comes with the expense itself because a payer holds no share to carry it.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name} · {date}'**
  String splitExpensePaidBy(String name, String date);

  /// Shown on an expense row when the viewer holds a share in it, so a participant can read what they owe without opening anything.
  ///
  /// In en, this message translates to:
  /// **'Your share {amount}'**
  String splitYourShare(String amount);

  /// Shown in place of a balances list when nothing is owed in either direction — distinguishes 'settled' from 'failed to load'.
  ///
  /// In en, this message translates to:
  /// **'Everyone is settled up'**
  String get splitAllSettledUp;

  /// Label standing in for the caller's own name in a candidate list (payer/participant picker) — the caller's own display name is never fetched for this purpose.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get splitYouLabel;

  /// Neutral placeholder shown in place of a person's name when the server genuinely has none to give — never a raw id, never blank (design D1).
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get splitUnknownMember;

  /// Title of the dialog used to create a new split group.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get splitCreateGroupTitle;

  /// Text field label in the create-group dialog.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get splitGroupNameLabel;

  /// Validation message shown when trying to create a group with an empty name.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name'**
  String get splitGroupNameRequired;

  /// Confirm button label in the create-group dialog.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get splitCreateButton;

  /// Title of the record-expense sheet when creating a new expense.
  ///
  /// In en, this message translates to:
  /// **'Record a split expense'**
  String get splitExpenseAddTitle;

  /// Title of the record-expense sheet when editing an existing expense.
  ///
  /// In en, this message translates to:
  /// **'Edit split expense'**
  String get splitExpenseEditTitle;

  /// Label of the record-expense sheet's group selector, shown only when creating a group-less-or-grouped expense (hidden entirely while editing, since group_id is immutable server-side).
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get splitGroupFieldLabel;

  /// The split expense form's category picker option for leaving the category unset — allowed, and what every expense recorded before the picker existed did. Every participant's mirrored transaction then lands in their own fallback category.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get splitCategoryNoneOption;

  /// Option in the record-expense sheet's group selector meaning the expense has no group — candidates are then the caller's friends plus themselves.
  ///
  /// In en, this message translates to:
  /// **'No group (one-off)'**
  String get splitGroupNoneOption;

  /// Label of the record-expense sheet's payer selector.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get splitPayerLabel;

  /// Label of the record-expense sheet's description field.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get splitDescriptionLabel;

  /// Validation message shown when trying to save an expense with an empty description.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get splitDescriptionRequired;

  /// Label of the record-expense sheet's date field (a plain calendar date, not an instant).
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get splitDayLabel;

  /// Label of the record-expense sheet's participant checklist.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get splitParticipantsLabel;

  /// Label of the record-expense sheet's equal/exact split-mode toggle.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get splitSplitModeLabel;

  /// Option label for an equal split.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get splitModeEqual;

  /// Option label for an exact (custom per-person amount) split.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get splitModeExact;

  /// One row of the equal-split live preview: a participant's name and the share they will be recorded with, computed identically to the backend so the preview never diverges from what gets stored.
  ///
  /// In en, this message translates to:
  /// **'{name}: {amount}'**
  String splitEqualShareRow(String name, String amount);

  /// Section heading for putting one participant's share on a monthly repayment schedule.
  ///
  /// In en, this message translates to:
  /// **'Repayment schedule'**
  String get splitScheduleSectionTitle;

  /// Shown in equal-split mode, where the server accepts no schedule.
  ///
  /// In en, this message translates to:
  /// **'To have one person repay monthly, the split has to be Exact.'**
  String get splitScheduleExactOnly;

  /// Shown once after switching from exact to equal with a schedule set.
  ///
  /// In en, this message translates to:
  /// **'Switched to an equal split, so the repayment schedule was cleared.'**
  String get splitScheduleClearedOnEqual;

  /// The 'nobody is repaying in instalments' option in the repayment-person selector.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get splitScheduleNobody;

  /// Label for the selector choosing which participant repays in instalments.
  ///
  /// In en, this message translates to:
  /// **'Who repays monthly'**
  String get splitSchedulePersonLabel;

  /// Label for the period-count field of a repayment schedule.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get splitSchedulePeriodsLabel;

  /// The derived per-period amount of a repayment schedule.
  ///
  /// In en, this message translates to:
  /// **'{amount} per month'**
  String splitSchedulePerPeriod(String amount);

  /// Shown when the share had to change so the periods divide exactly. Both figures are shown deliberately.
  ///
  /// In en, this message translates to:
  /// **'Share adjusted {from} → {to}; {name} takes the difference'**
  String splitScheduleAdjusted(String from, String to, String name);

  /// Shown when no participant can absorb the rounding.
  ///
  /// In en, this message translates to:
  /// **'{amount} does not divide into {periods} months, and nobody else can take the difference'**
  String splitScheduleImpossible(String amount, int periods);

  /// Alternative period counts offered when the chosen one cannot work.
  ///
  /// In en, this message translates to:
  /// **'Months that would divide exactly: {periods}'**
  String splitScheduleSuggestions(String periods);

  /// One repayment schedule behind a balance row: which period is next, of how many, and what that period is worth.
  ///
  /// In en, this message translates to:
  /// **'Period {next} of {total} · {amount} each'**
  String splitBalanceSchedule(int next, int total, String amount);

  /// Action that switches the split to exact mode from the repayment-schedule section, so the section is a way in rather than a dead end.
  ///
  /// In en, this message translates to:
  /// **'Use Exact'**
  String get splitScheduleSwitchToExact;

  /// Field label for one participant's amount entry in exact-split mode.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s share'**
  String splitExactShareLabel(String name);

  /// Live shortfall shown in exact-split mode: how much of the total amount the entered shares don't yet add up to.
  ///
  /// In en, this message translates to:
  /// **'Remaining to assign: {amount}'**
  String splitExactRemaining(String amount);

  /// Exact-split running total when the entered shares add up to MORE than the amount — a separate string from the shortfall one, because a negative shortfall reads as its own opposite.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String splitExactOverAssigned(String amount);

  /// Exact-split running total when the entered shares add up to exactly the amount.
  ///
  /// In en, this message translates to:
  /// **'Assigned in full'**
  String get splitExactAssignedInFull;

  /// Shown in the record-expense sheet when the caller is neither the payer nor a participant with a share above zero — submission is refused locally before any request is sent.
  ///
  /// In en, this message translates to:
  /// **'You must be the payer, or hold a share above zero, to record this expense.'**
  String get splitStakeWarning;

  /// Shown in the record-expense sheet when the entered amount exceeds the maximum the backend accepts (2147483647 minor units).
  ///
  /// In en, this message translates to:
  /// **'This amount is too large.'**
  String get splitAmountTooLarge;

  /// Reason shown above a disabled Save in the record-expense sheet when the amount is missing or not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero.'**
  String get splitAmountRequired;

  /// Reason shown above a disabled Save in the record-expense sheet when no payer is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose who paid.'**
  String get splitPayerRequired;

  /// Reason shown above a disabled Save in the record-expense sheet when no participant is ticked.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one participant.'**
  String get splitParticipantsRequired;

  /// Reason shown above a disabled Save when the payer and the participants are the same single person; the backend refuses such a split outright.
  ///
  /// In en, this message translates to:
  /// **'A split needs at least two people — add someone besides the payer.'**
  String get splitTooFewPeople;

  /// Reason shown above a disabled Save when the caller has no group and no friends, so the participant list holds nobody but themselves and no amount of typing in the sheet can complete the form.
  ///
  /// In en, this message translates to:
  /// **'You have no friends yet — add a friend first, then you can split with them.'**
  String get splitNoFriendsYet;

  /// Button that leaves for the friends page, offered wherever splitting is blocked by the caller having no friends yet.
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get splitAddFriendAction;

  /// Reason shown above a disabled Save when an equal split's amount is smaller than the participant count, which the backend refuses outright.
  ///
  /// In en, this message translates to:
  /// **'This amount is too small to split equally between {count} people.'**
  String splitAmountBelowParticipants(int count);

  /// Reason shown above a disabled Save in exact-split mode when the entered shares do not add up to the total amount.
  ///
  /// In en, this message translates to:
  /// **'The shares must add up to the amount.'**
  String get splitExactMustSumToAmount;

  /// Title of the confirmation dialog shown before deleting a split expense, naming it by its description.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{description}\"?'**
  String splitDeleteConfirmTitle(String description);

  /// Body text of the confirmation dialog shown before deleting a split expense.
  ///
  /// In en, this message translates to:
  /// **'This removes the expense and its split for everyone involved. This can\'t be undone.'**
  String get splitDeleteConfirmMessage;

  /// Confirm button label in the delete-expense confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get splitDeleteConfirmButton;

  /// Generic fallback shown when saving a split expense fails for a reason with no more specific mapped message.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get splitSaveFailedMessage;

  /// Actionable message for the backend's not_friends error.
  ///
  /// In en, this message translates to:
  /// **'This person isn\'t your friend yet — add them as a friend first.'**
  String get splitErrorNotFriends;

  /// Actionable message for the backend's not_a_group_member error.
  ///
  /// In en, this message translates to:
  /// **'That person isn\'t a member of this group.'**
  String get splitErrorNotAGroupMember;

  /// Actionable message for the backend's group_archived error.
  ///
  /// In en, this message translates to:
  /// **'This group is archived, so no expense can be added to it.'**
  String get splitErrorGroupArchived;

  /// Message for the backend's shares_do_not_sum_to_amount error, including the backend's own discrepancy text rather than a bare status code.
  ///
  /// In en, this message translates to:
  /// **'The shares don\'t add up to the amount: {message}'**
  String splitErrorSharesMismatch(String message);

  /// Actionable message for the backend's split_too_small error.
  ///
  /// In en, this message translates to:
  /// **'This amount is too small to split.'**
  String get splitErrorTooSmall;

  /// Actionable message for the backend's duplicate_participant error.
  ///
  /// In en, this message translates to:
  /// **'The same person can\'t be listed twice.'**
  String get splitErrorDuplicateParticipant;

  /// Actionable message for the backend's already_a_group_member error.
  ///
  /// In en, this message translates to:
  /// **'That person is already a member of this group.'**
  String get splitErrorAlreadyMember;

  /// Actionable message for the backend's not_a_participant error.
  ///
  /// In en, this message translates to:
  /// **'You need a share in this expense to do that.'**
  String get splitErrorNotAParticipant;

  /// Message for the backend's invalid_split_input error. The framing sentence is localized so a reader always gets one sentence in their own language; {message} is the backend's own (English) explanation.
  ///
  /// In en, this message translates to:
  /// **'This split couldn\'t be accepted: {message}'**
  String splitErrorInvalidInput(String message);

  /// Message for the backend's bad_request error (route-level input validation). The framing sentence is localized — and deliberately different from invalid_split_input's — so the two never collapse into each other; {message} is the backend's own (English) explanation.
  ///
  /// In en, this message translates to:
  /// **'This entry was rejected: {message}'**
  String splitErrorBadRequest(String message);

  /// Message for a 404 not_found response — visibility, never distinguished from 'not yours to see'.
  ///
  /// In en, this message translates to:
  /// **'This couldn\'t be found. It may have been deleted.'**
  String get splitErrorNotFound;

  /// Message for a 400 cannot_settle_with_self response — the payer and the payee of a repayment are the same person.
  ///
  /// In en, this message translates to:
  /// **'You can\'t record a repayment with yourself.'**
  String get splitErrorCannotSettleWithSelf;

  /// Fallback message for a split failure with no more specific mapping.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get splitErrorGeneric;

  /// Shown when a split mutation (create/update expense, settle up) times out client-side. Unlike other failures, a timeout does not mean the server rejected the request — it may have gone through — so the copy asks the user to check before resubmitting rather than implying it is safe to just retry.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t get a confirmation. Check your split activity before trying again.'**
  String get splitErrorTimeout;

  /// Badge shown on the group detail screen when the group is archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get splitGroupArchivedBadge;

  /// Heading for the group detail screen's member list.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get splitGroupMembersTitle;

  /// Heading for the group detail screen's per-member-vs-group balances (design D8). Labelled to say it excludes repayments: this change's repayments are always person-to-person (group_id null), and the group balance only sums group-scoped repayments, so this figure never moves when one is recorded — without the label the group screen would keep showing a debt the split tab shows as settled.
  ///
  /// In en, this message translates to:
  /// **'Group balances (excludes repayments)'**
  String get splitGroupBalancesTitle;

  /// Subtitle under the group detail screen's per-member balances, spelling out why they never move when a person-to-person repayment is recorded (design D8).
  ///
  /// In en, this message translates to:
  /// **'Excludes repayments — a repayment recorded between two people never changes these figures.'**
  String get splitGroupBalancesNote;

  /// A group balance row for a member who is net owed by the group (design D2 — group balances read differently from the two-person 'owed to me' balance, so this has its own wording).
  ///
  /// In en, this message translates to:
  /// **'{name} should collect {amount}'**
  String splitGroupBalanceShouldCollect(String name, String amount);

  /// A group balance row for a member who net owes the group.
  ///
  /// In en, this message translates to:
  /// **'{name} should pay {amount}'**
  String splitGroupBalanceShouldPay(String name, String amount);

  /// Heading for the group detail screen's list of the group's expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get splitGroupExpensesTitle;

  /// Shown in the group detail screen's expenses section when the group has none.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this group yet'**
  String get splitGroupNoExpensesYet;

  /// Button on the group detail screen that opens the add-member picker, hidden once the group is archived.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get splitAddMemberButton;

  /// Title of the add-member picker dialog.
  ///
  /// In en, this message translates to:
  /// **'Add a friend to this group'**
  String get splitAddMemberTitle;

  /// Shown in the add-member picker when every one of the caller's friends is already a member.
  ///
  /// In en, this message translates to:
  /// **'All your friends are already in this group.'**
  String get splitAddMemberEmpty;

  /// Button on the group detail screen that archives the group, shown only to the group's creator.
  ///
  /// In en, this message translates to:
  /// **'Archive group'**
  String get splitArchiveButton;

  /// Title of the confirmation dialog shown before archiving a group, naming it.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{groupName}\"?'**
  String splitArchiveConfirmTitle(String groupName);

  /// Body text of the confirmation dialog shown before archiving a group.
  ///
  /// In en, this message translates to:
  /// **'The group becomes read-only: no new expenses or members can be added, though its existing expenses can still be edited by their creator or payer.'**
  String get splitArchiveConfirmMessage;

  /// Confirm button label in the archive-group confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get splitArchiveConfirmButton;

  /// Tooltip for the group detail screen's floating action button, which opens the record-expense sheet pre-locked to this group.
  ///
  /// In en, this message translates to:
  /// **'Record a split expense'**
  String get splitAddExpenseTooltip;

  /// Tooltip for an expense row's edit icon button, shown only to the expense's creator or payer.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get splitEditExpenseTooltip;

  /// Tooltip for an expense row's delete icon button, shown only to the expense's creator or payer.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get splitDeleteExpenseTooltip;

  /// Shown on the group detail screen when loading fails for a reason other than needing reauthentication.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this group. Check your connection and try again.'**
  String get splitGroupLoadFailedMessage;

  /// Heading of the settle-up sheet when the caller owes the other person — names them and states the direction so the user need not check which balance row they tapped.
  ///
  /// In en, this message translates to:
  /// **'Pay {name} back'**
  String settleUpTitlePaying(String name);

  /// Heading of the settle-up sheet when the other person owes the caller.
  ///
  /// In en, this message translates to:
  /// **'{name} pays you back'**
  String settleUpTitleReceiving(String name);

  /// Label for the settle-up sheet's submit button.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settleUpConfirmButton;

  /// Shown below the settle-up sheet's amount row when the amount is empty, zero, or negative.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get settleUpAmountRequired;

  /// Shown below the settle-up sheet's amount row when a fractional value is entered for a currency with no minor-unit decimals (TWD/JPY/KRW) — refused explicitly rather than silently rounded. Full-width, not inside the 120dp amount field, which would clip it.
  ///
  /// In en, this message translates to:
  /// **'This currency doesn\'t use decimals — enter a whole number'**
  String get settleUpAmountMustBeWhole;

  /// Shown below the settle-up sheet's amount row when the amount exceeds the backend's maximum (a signed 32-bit int).
  ///
  /// In en, this message translates to:
  /// **'This amount is too large'**
  String get settleUpAmountTooLarge;

  /// Warning shown before submitting when the caller is paying the other person and types more than the full outstanding amount — states the consequence (the direction flips) rather than a generic 'amount is large' message.
  ///
  /// In en, this message translates to:
  /// **'{name} will end up owing you {amount}'**
  String settleUpOverpayWarningTheyWillOwe(String name, String amount);

  /// Warning shown before submitting when the caller is recording the other person paying and types more than the full outstanding amount — the opposite direction from settleUpOverpayWarningTheyWillOwe, since one fixed sentence would be wrong half the time.
  ///
  /// In en, this message translates to:
  /// **'You will end up owing {name} {amount}'**
  String settleUpOverpayWarningYouWillOwe(String name, String amount);

  /// Section heading above the split tab's combined list of expenses and repayments — replaces the expenses-only heading now that repayments appear alongside expenses in the same list.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get splitSectionRecentActivity;

  /// Shown under the recent-activity heading when there are no expenses and no repayments.
  ///
  /// In en, this message translates to:
  /// **'No expenses or repayments yet'**
  String get splitNoActivityYet;

  /// Tooltip for the settle-up icon button on a two-person balance row, on the split tab and on a group's person-to-person section.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get splitSettleUpTooltip;

  /// A repayment's label in the activity list. States the word "repayment" explicitly in the copy itself, not only via an icon or colour, so it cannot be misread as another expense.
  ///
  /// In en, this message translates to:
  /// **'Repayment: {from} paid {to} back'**
  String splitSettlementRow(String from, String to);

  /// Tooltip for a repayment row's delete icon button, shown only to the repayment's creator or payer (design D4) — anyone else would get a 404 from the server.
  ///
  /// In en, this message translates to:
  /// **'Delete repayment'**
  String get splitDeleteSettlementTooltip;

  /// Title of the confirmation dialog shown before deleting a repayment.
  ///
  /// In en, this message translates to:
  /// **'Delete this repayment?'**
  String get splitDeleteSettlementConfirmTitle;

  /// Body text of the delete-repayment confirmation dialog — names the other person and the amount (design D4) so the user knows exactly what they are removing before confirming.
  ///
  /// In en, this message translates to:
  /// **'This removes the {amount} repayment with {name}. This can\'t be undone.'**
  String splitDeleteSettlementConfirmMessage(String name, String amount);

  /// Confirm button label in the delete-repayment confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get splitDeleteSettlementConfirmButton;

  /// Heading for the group detail screen's person-to-person balances section (design D8) — distinct from the group balances above: filtered from the caller's two-person balances to this group's members, and each row offers settling.
  ///
  /// In en, this message translates to:
  /// **'Your balance with each member'**
  String get splitGroupPersonalBalancesTitle;

  /// Subtitle clarifying that the person-to-person balances section is not scoped to this group alone (design D8 — the label must be honest about that).
  ///
  /// In en, this message translates to:
  /// **'Spans your shared history everywhere, not only this group.'**
  String get splitGroupPersonalBalancesNote;

  /// Label of the split tab's first section switch: the balances/groups/recent-expenses view. Deliberately not 'Overview' — the finance bottom bar's first destination is already called that, and both are visible on this same screen at once.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get splitSectionOverview;

  /// Label of the split tab's second section switch: what has happened, including deletions and edits, as opposed to what currently exists.
  ///
  /// In en, this message translates to:
  /// **'Change log'**
  String get splitSectionChangeLog;

  /// Empty state title for the split change log.
  ///
  /// In en, this message translates to:
  /// **'No changes yet'**
  String get splitActivityEmptyTitle;

  /// Empty state body for the split change log, explaining what will fill it.
  ///
  /// In en, this message translates to:
  /// **'When you or someone you split with adds, edits or deletes something, it appears here.'**
  String get splitActivityEmptyBody;

  /// Shown when the first page of the split change log fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the change log. Check your connection and try again.'**
  String get splitActivityLoadFailedMessage;

  /// Shown at the bottom of the split change log when loading a further page failed; the entries already loaded stay on screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more entries.'**
  String get splitActivityLoadMoreFailed;

  /// Change-log entry: the reader recorded a split expense.
  ///
  /// In en, this message translates to:
  /// **'You added {description}'**
  String splitActivityExpenseCreatedYou(String description);

  /// Change-log entry: someone else recorded a split expense.
  ///
  /// In en, this message translates to:
  /// **'{name} added {description}'**
  String splitActivityExpenseCreatedOther(String name, String description);

  /// Change-log entry: the reader edited a split expense.
  ///
  /// In en, this message translates to:
  /// **'You edited {description}'**
  String splitActivityExpenseUpdatedYou(String description);

  /// Change-log entry: someone else edited a split expense.
  ///
  /// In en, this message translates to:
  /// **'{name} edited {description}'**
  String splitActivityExpenseUpdatedOther(String name, String description);

  /// Change-log entry: the reader deleted a split expense. The wording must make the deletion audible on its own, since the expense no longer exists.
  ///
  /// In en, this message translates to:
  /// **'You deleted {description}'**
  String splitActivityExpenseDeletedYou(String description);

  /// Change-log entry: someone else deleted a split expense.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted {description}'**
  String splitActivityExpenseDeletedOther(String name, String description);

  /// Change-log entry: the reader recorded a repayment. Who paid whom is a separate line, because the direction is not the same as who recorded it.
  ///
  /// In en, this message translates to:
  /// **'You recorded a repayment'**
  String get splitActivitySettlementCreatedYou;

  /// Change-log entry: someone else recorded a repayment.
  ///
  /// In en, this message translates to:
  /// **'{name} recorded a repayment'**
  String splitActivitySettlementCreatedOther(String name);

  /// Change-log entry: the reader deleted a repayment.
  ///
  /// In en, this message translates to:
  /// **'You deleted a repayment'**
  String get splitActivitySettlementDeletedYou;

  /// Change-log entry: someone else deleted a repayment.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted a repayment'**
  String splitActivitySettlementDeletedOther(String name);

  /// Change-log entry: the reader created a split group.
  ///
  /// In en, this message translates to:
  /// **'You created the group {group}'**
  String splitActivityGroupCreatedYou(String group);

  /// Change-log entry: someone else created a split group.
  ///
  /// In en, this message translates to:
  /// **'{name} created the group {group}'**
  String splitActivityGroupCreatedOther(String name, String group);

  /// Change-log entry: the reader added someone to a split group.
  ///
  /// In en, this message translates to:
  /// **'You added {member} to {group}'**
  String splitActivityGroupMemberAddedYou(String member, String group);

  /// Change-log entry: someone else added a member to a split group.
  ///
  /// In en, this message translates to:
  /// **'{name} added {member} to {group}'**
  String splitActivityGroupMemberAddedOther(
    String name,
    String member,
    String group,
  );

  /// Change-log entry: someone else added the reader to a split group. Without it the reader's own display name is rendered in the third person — the same bug repayment entries were fixed for.
  ///
  /// In en, this message translates to:
  /// **'{name} added you to {group}'**
  String splitActivityGroupMemberAddedYouWere(String name, String group);

  /// Change-log entry: the reader archived a split group.
  ///
  /// In en, this message translates to:
  /// **'You archived the group {group}'**
  String splitActivityGroupArchivedYou(String group);

  /// Change-log entry: someone else archived a split group.
  ///
  /// In en, this message translates to:
  /// **'{name} archived the group {group}'**
  String splitActivityGroupArchivedOther(String name, String group);

  /// Direction line of a change-log repayment entry when the reader is the one who paid. The stored flag is relative to whoever recorded the entry, so this is not simply 'the actor paid'.
  ///
  /// In en, this message translates to:
  /// **'You paid {name}'**
  String splitActivityRepaymentYouPaid(String name);

  /// Direction line of a change-log repayment entry when the reader is the one who was paid.
  ///
  /// In en, this message translates to:
  /// **'{name} paid you'**
  String splitActivityRepaymentPaidYou(String name);

  /// Direction line of a change-log repayment entry read by a group member who is neither party.
  ///
  /// In en, this message translates to:
  /// **'{payer} paid {payee}'**
  String splitActivityRepaymentBetween(String payer, String payee);

  /// Shown on an edit entry whose change list is empty — the update endpoint replaces the whole record, so re-saving identical values is ordinary.
  ///
  /// In en, this message translates to:
  /// **'This edit changed nothing'**
  String get splitActivityChangedNothing;

  /// One entry in an edit's list of what changed.
  ///
  /// In en, this message translates to:
  /// **'currency'**
  String get splitActivityChangedFieldCurrency;

  /// One entry in an edit's list of what changed.
  ///
  /// In en, this message translates to:
  /// **'description'**
  String get splitActivityChangedFieldDescription;

  /// One entry in an edit's list of what changed.
  ///
  /// In en, this message translates to:
  /// **'date'**
  String get splitActivityChangedFieldDay;

  /// One entry in an edit's list of what changed.
  ///
  /// In en, this message translates to:
  /// **'who paid'**
  String get splitActivityChangedFieldPayer;

  /// One entry in an edit's list of what changed. Covers both who is in the split and how much each owes.
  ///
  /// In en, this message translates to:
  /// **'the split'**
  String get splitActivityChangedFieldShares;

  /// Stands in for a change this build does not have a name for, so a newer backend's field is reported rather than silently dropped.
  ///
  /// In en, this message translates to:
  /// **'something else'**
  String get splitActivityChangedFieldOther;

  /// An edit's list of what it touched.
  ///
  /// In en, this message translates to:
  /// **'Changed {fields}'**
  String splitActivityChangedFields(String fields);

  /// Who joined a split in this edit.
  ///
  /// In en, this message translates to:
  /// **'Added to the split: {names}'**
  String splitActivityParticipantsAdded(String names);

  /// Who left a split in this edit. The most consequential line on the row — their balance moved.
  ///
  /// In en, this message translates to:
  /// **'Removed from the split: {names}'**
  String splitActivityParticipantsRemoved(String names);

  /// Joins names or field names inside one change line. A separate string because the comma differs by script.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get splitActivityNameSeparator;

  /// Joins the row's detail lines into the single sentence a screen reader announces.
  ///
  /// In en, this message translates to:
  /// **'. '**
  String get splitActivityDetailSeparator;

  /// Shown in place of a plain amount on a change-log edit entry when the amount actually moved. Not shown when the edit left the amount alone, which is most of them.
  ///
  /// In en, this message translates to:
  /// **'{previous} → {amount}'**
  String splitActivityAmountChange(String previous, String amount);

  /// The screen-reader wording of splitActivityAmountChange. The painted arrow is either announced as a glyph name or dropped, either way leaving a listener with two amounts and no idea which is the new one.
  ///
  /// In en, this message translates to:
  /// **'from {previous} to {amount}'**
  String splitActivityAmountChangeSpoken(String previous, String amount);

  /// Change-log entry for an event type this build of the app does not recognise, made by the reader. The backend ships independently, so a newer event type must degrade to a neutral row rather than take the page down.
  ///
  /// In en, this message translates to:
  /// **'You changed something'**
  String get splitActivityUnknownYou;

  /// As splitActivityUnknownYou, for an unrecognised event type made by someone else.
  ///
  /// In en, this message translates to:
  /// **'{name} changed something'**
  String splitActivityUnknownOther(String name);

  /// Joins a change-log entry's headline to its second line for screen readers, so the row is read as one sentence rather than as fragments.
  ///
  /// In en, this message translates to:
  /// **'{what}: {detail}'**
  String splitActivityRowDetail(String what, String detail);

  /// The whole change-log row as one sentence for screen readers: who did what, how much, and when.
  ///
  /// In en, this message translates to:
  /// **'{what}, {amount}, {time}'**
  String splitActivityRowSemantics(String what, String amount, String time);

  /// Stands in for a change-log entry's description when the record was saved without one.
  ///
  /// In en, this message translates to:
  /// **'an untitled item'**
  String get splitActivityUnnamedItem;

  /// Stands in for a group's name in a change-log entry when it is unavailable.
  ///
  /// In en, this message translates to:
  /// **'an untitled group'**
  String get splitActivityUnnamedGroup;

  /// As splitActivityRowSemantics but for a change-log entry that carries no amount (the group events), so a screen reader is not handed an empty slot.
  ///
  /// In en, this message translates to:
  /// **'{what}, {time}'**
  String splitActivityRowSemanticsNoAmount(String what, String time);

  /// App bar title of the assistant conversation screen.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get assistantTitle;

  /// Row in the assistant transcript naming what the user was looking at when they opened the assistant (e.g. the finance space, a tab name and a month) — past tense on purpose: the assistant only saw this view once, at entry, not for the whole conversation. The exact same string is prepended into the first message sent to the model.
  ///
  /// In en, this message translates to:
  /// **'Started from: {view}'**
  String assistantContextViewing(String view);

  /// Placeholder shown in the empty transcript before the first message, telling the user what the assistant can do — used when the assistant was opened WITH a chat context (e.g. from the finance tabs), which gives the model a month/tab to anchor a vague question to. Kept to one line: it sits above the tappable example prompts, which are what actually teach the capability.
  ///
  /// In en, this message translates to:
  /// **'Ask about your spending, budgets or split balances — or tell me a transaction to log.'**
  String get assistantEmptyHint;

  /// Placeholder shown in the empty transcript before the first message, used when the assistant was opened WITHOUT a chat context (e.g. from the home screen) — nudges the user to state a time range themselves, since the assistant has no month/tab to anchor a question like "how much did I spend" to.
  ///
  /// In en, this message translates to:
  /// **'Ask about your spending, budgets or split balances — or tell me a transaction to log. I don\'t know what you were looking at, so name a month if it matters.'**
  String get assistantEmptyHintNoContext;

  /// Placeholder shown in the empty transcript before the first message, used when the assistant was opened with NO module at all (the home entry, which belongs to neither finance nor health) AND health access is already on. It must name both halves — finance (spending, budgets, split balances, logging a transaction) and health/diet/care records — or the home entry presents the assistant as finance-only. When health access is off, assistantEmptyHintNoContextMixedConsentOff is used instead: this wording promises a capability that is not switched on. Ends with the same ask-for-a-period nudge as assistantEmptyHintNoContext, since a home visit carries no month or day to anchor a vague question to.
  ///
  /// In en, this message translates to:
  /// **'Ask about your spending, budgets or split balances — or tell me a transaction to log. You can also ask about your health, diet and care records. I don\'t know what you were looking at, so name the period you mean.'**
  String get assistantEmptyHintNoContextMixed;

  /// Placeholder shown in the empty transcript before the first message, used ONLY on the home entry (no module at all) while health access is off — the default state, since health access is opt-in and sign-out clears it. Same as assistantEmptyHintNoContextMixed except the health/diet/care half is conditional: it says what turning the consent on would unlock instead of promising a capability the assistant does not currently have. A low-emphasis text button pointing at settings sits under the example prompts so the sentence has somewhere to lead; the health entry's fuller access-off notice stays out of the home path.
  ///
  /// In en, this message translates to:
  /// **'Ask about your spending, budgets or split balances — or tell me a transaction to log. Turn on health access in settings and you can also ask about your health, diet and care records. I don\'t know what you were looking at, so name the period you mean.'**
  String get assistantEmptyHintNoContextMixedConsentOff;

  /// Screen-reader announcement while an assistant reply is in flight. The spinner is animation only, so without this a screen-reader user gets no signal that anything is happening (WCAG 4.1.3).
  ///
  /// In en, this message translates to:
  /// **'Sending your message'**
  String get assistantSendingLabel;

  /// Label of the button that opens the assistant from a screen's app bar (finance and health). Spelled out rather than icon-only: a tooltip never appears on a touch device, so an unlabelled robot icon says nothing there.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get assistantOpenButton;

  /// Tappable example prompt in the assistant's empty state. Tapping fills the composer (it does not send), so the user can edit it first.
  ///
  /// In en, this message translates to:
  /// **'How much did I spend this month?'**
  String get assistantExampleSpend;

  /// Tappable example prompt in the assistant's empty state, showing that a transaction can be dictated in one line. Tapping fills the composer (it does not send).
  ///
  /// In en, this message translates to:
  /// **'Log: lunch 120'**
  String get assistantExampleLog;

  /// Tappable example prompt in the assistant's empty state, pointing at split balances. Tapping fills the composer (it does not send).
  ///
  /// In en, this message translates to:
  /// **'Who do I owe?'**
  String get assistantExampleOwe;

  /// Placeholder shown in the empty transcript before the first message, used when the assistant was opened from the HEALTH module on a tab that shows a day (總覽 only). The finance wording (spending, budgets, split balances) would be about a module the user did not come from. Unlike the finance hint, this does not offer to log an entry: the shipped health tools (list_favorite_foods/list_recent_foods/search_foods) are read-only, and so are the care tools (get_care_today/get_care_range/list_care_items) — the hint must not offer to log, complete or change a care entry either.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health, diet and care records.'**
  String get assistantEmptyHintHealth;

  /// As assistantEmptyHintHealth (same health, diet and care scope), but used when the health entry carried no day (記錄 / 趨勢 / 更多 are not day-keyed) — nudges the user to state the period themselves, since the assistant has no day to anchor a question like "how much did I eat" to.
  ///
  /// In en, this message translates to:
  /// **'Ask about your health, diet and care records. I don\'t know which day you were looking at, so name the period you mean.'**
  String get assistantEmptyHintHealthNoDay;

  /// Tappable example prompt in the assistant's HEALTH empty state, pointing at the day's remaining portion allowance. Tapping fills the composer (it does not send).
  ///
  /// In en, this message translates to:
  /// **'What can I still eat with today\'s remaining portions?'**
  String get assistantExampleRemainingPortions;

  /// Tappable example prompt in the assistant's HEALTH empty state, pointing at recent/favorite foods (the shipped read-only tools). Tapping fills the composer (it does not send).
  ///
  /// In en, this message translates to:
  /// **'What did I usually eat for lunch this week?'**
  String get assistantExampleRecentLunches;

  /// Tappable example prompt in the assistant's HEALTH empty state, pointing at the weight trend. Tapping fills the composer (it does not send).
  ///
  /// In en, this message translates to:
  /// **'How has my weight changed this month?'**
  String get assistantExampleWeightTrend;

  /// Shown in the assistant's empty state INSTEAD of the health example prompts, when the assistant was opened from the health module while the health-access consent is off (it is opt-in and sign-out clears it). Names health, diet and care records — the same ground the settings disclosure covers — joined with "or" to match the negative phrasing, and names no reminder or push records, which the consent does not cover. Without it the most common first-time path — 健康 → 問助手 → tap the remaining-portions example — asks an assistant that can see no health data, with nothing on screen saying why.
  ///
  /// In en, this message translates to:
  /// **'I can\'t read your health, diet or care records yet — health access is off. Turn it on in settings, then come back.'**
  String get assistantHealthAccessOff;

  /// Body text of the assistant screen's setup state, shown when no Gemini API key is stored yet; includes the free-tier data-use disclosure echoing the settings page.
  ///
  /// In en, this message translates to:
  /// **'The assistant needs your own Gemini API key. Add one in Settings — it\'s free to create, and on the free tier your conversations may be used to improve the provider\'s products.'**
  String get assistantSetupIntro;

  /// Secondary line under the assistant setup state's intro, explaining why a key the user already set is gone: sign-out clears it. Shown to first-time users too, so it reads as a rule rather than an incident report.
  ///
  /// In en, this message translates to:
  /// **'Your key is stored only on this device and is cleared when you sign out, so it has to be pasted again after each sign-in.'**
  String get assistantSetupSignOutNotice;

  /// Button that opens the settings page, shown in the assistant's setup state, on key-related errors, and in the health entry's health-access-off notice (where the sentence right above it already says what settings is for). The home empty state's consent exit does NOT use it — it sits under three finance examples, far from the sentence that explains it, so it names its own purpose with assistantEnableHealthAccess instead.
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get assistantGoToSettings;

  /// Low-emphasis button under the home empty state's example prompts, shown only while health access is off; it opens the settings page where the consent lives. Says what it is for rather than where it goes: it is read out on its own by a screen reader, several nodes after the hint sentence whose conditional half it answers (WCAG 2.4.6).
  ///
  /// In en, this message translates to:
  /// **'Turn on health access'**
  String get assistantEnableHealthAccess;

  /// Hint text of the assistant conversation's message input field.
  ///
  /// In en, this message translates to:
  /// **'Message the assistant…'**
  String get assistantComposerHint;

  /// Tooltip of the assistant composer's send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistantSendTooltip;

  /// Error shown when the backend relays that Gemini refused the user's API key (400 gemini_key_rejected); the fix is on the settings page.
  ///
  /// In en, this message translates to:
  /// **'Gemini rejected this API key. Check it in Settings.'**
  String get assistantErrorKeyRejected;

  /// Error shown when the user's Gemini free-tier quota is exhausted (429 gemini_quota_exhausted); the key itself is fine, so no settings link is offered.
  ///
  /// In en, this message translates to:
  /// **'Your Gemini free quota is used up for now — it comes back tomorrow.'**
  String get assistantErrorQuotaExhausted;

  /// Error shown when the user's key cannot access the served model (403 gemini_model_unavailable); the fix is on the settings page.
  ///
  /// In en, this message translates to:
  /// **'This key can\'t use the assistant\'s model. Check it in Settings.'**
  String get assistantErrorModelUnavailable;

  /// Error shown for an upstream AI-service failure (502 gemini_unavailable) or a network error — retryable, not the user's fault.
  ///
  /// In en, this message translates to:
  /// **'The AI service is temporarily unavailable. Please try again shortly.'**
  String get assistantErrorUnavailable;

  /// Heading of a transaction confirmation card the assistant proposed; the user decides whether to accept it.
  ///
  /// In en, this message translates to:
  /// **'Record this?'**
  String get assistantProposalTitle;

  /// Category line on a proposal confirmation card. {name} is the category name the assistant proposed.
  ///
  /// In en, this message translates to:
  /// **'Category: {name}'**
  String assistantProposalCategoryRow(String name);

  /// Stands in on a proposal confirmation card's category line when the assistant proposed no category; such a card cannot be accepted.
  ///
  /// In en, this message translates to:
  /// **'No category given'**
  String get assistantProposalNoCategory;

  /// Date line on a proposal confirmation card. {day} is the YYYY-MM-DD the transaction would be recorded under.
  ///
  /// In en, this message translates to:
  /// **'Date: {day}'**
  String assistantProposalDateRow(String day);

  /// Note line on a proposal confirmation card, only shown when the proposal carries a note.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String assistantProposalNoteRow(String note);

  /// The accept button after a category could not be found. Named differently from the first attempt because by now the user has been told to go and create the category, and this is the press that tries again.
  ///
  /// In en, this message translates to:
  /// **'Record it now'**
  String get assistantProposalRetryAccept;

  /// Accept button on a proposal confirmation card — saves the drafted transaction into the ledger.
  ///
  /// In en, this message translates to:
  /// **'Record it'**
  String get assistantProposalAccept;

  /// Shown on a proposal confirmation card after it was saved successfully; the accept button is gone.
  ///
  /// In en, this message translates to:
  /// **'Recorded ✓'**
  String get assistantProposalSaved;

  /// Shown on a proposal confirmation card when saving failed; the accept button is re-enabled.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — try again.'**
  String get assistantProposalSaveFailed;

  /// Shown on a proposal confirmation card when no active category of the right type matches the proposed name. The card stays acceptable: the message tells the user to create the category, so pressing again afterwards re-resolves it.
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" not found — create it in the ledger first.'**
  String assistantProposalCategoryNotFound(String name);

  /// Shown in place of a proposal confirmation card whose fields could not be normalized (bad type or amount); it has no accept button.
  ///
  /// In en, this message translates to:
  /// **'This proposal is incomplete and can\'t be shown.'**
  String get assistantProposalUnrenderable;

  /// Heading of the care history screen's filter bottom sheet, and the tooltip of the toolbar button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get careHistoryFilterTitle;

  /// Group heading in the care history filter sheet above the single-select list of care items that occur in the loaded period.
  ///
  /// In en, this message translates to:
  /// **'Care item'**
  String get careHistoryFilterItemLabel;

  /// The care-item filter option that selects no particular item, i.e. shows records for every item.
  ///
  /// In en, this message translates to:
  /// **'All items'**
  String get careHistoryFilterAllItems;

  /// Group heading in the care history filter sheet above the multi-select slot statuses (done, skipped, missed, overdue, pending).
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get careHistoryFilterStatusLabel;

  /// Button that removes every active care history filter at once — shown at the end of the applied-filter chip row and in the filtered-empty state.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get careHistoryFilterClearButton;

  /// Title of the care history empty state shown when the period does contain records but the active filters exclude all of them — distinct from careHistoryEmptyTitle ('No care records'), which means the period itself is empty.
  ///
  /// In en, this message translates to:
  /// **'No records match'**
  String get careHistoryFilteredEmptyTitle;

  /// Body copy paired with careHistoryFilteredEmptyTitle. It does not suggest widening the period: the records are filtered out, not out of range, so a longer period would not bring them back.
  ///
  /// In en, this message translates to:
  /// **'This period has records, but none of them match the current filters.'**
  String get careHistoryFilteredEmptyBody;

  /// Label of the care history time-range control (and of its picker's rolling-span options) for a rolling span: 'Last 7 days'. Deliberately not the bare trendRange7/30/90 strings ('7 days'), which read as a fragment on a standalone control that has to say what the number means on its own.
  ///
  /// In en, this message translates to:
  /// **'Last {days} days'**
  String careHistoryPeriodSpanLabel(int days);

  /// Heading of the care history time-range picker sheet, opened from the period control.
  ///
  /// In en, this message translates to:
  /// **'Time range'**
  String get careHistoryPeriodPickerTitle;

  /// Fourth row of the care history time-range picker sheet (after 7/30/90 days), which opens a date range picker.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get careHistoryPeriodCustom;

  /// Label of the care history period selector's custom segment once a range is picked, replacing the word 'Custom' with the dates actually in effect so the current period is readable at a glance. Both values are already locale-formatted dates.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String careHistoryPeriodCustomLabel(String from, String to);

  /// Care history load-failure message for a custom date range, naming the dates that failed. The counterpart of careErrorForPeriod, which names a length in days and so cannot describe a custom range. Both values are already locale-formatted dates.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load {from} – {to}. Please try again.'**
  String careHistoryErrorForCustomRange(String from, String to);

  /// Shown when a URL or a handed-over destination matches no screen in this app version.
  ///
  /// In en, this message translates to:
  /// **'This page does not exist.'**
  String get routeNotFound;

  /// Label of the control on the not-found screen that returns to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get routeNotFoundGoHome;
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
