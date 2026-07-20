// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get signInSubtitle => '登入 Life OS';

  @override
  String get emailLabel => '電子郵件';

  @override
  String get passwordLabel => '密碼';

  @override
  String get signInButton => '登入';

  @override
  String get signingIn => '登入中…';

  @override
  String get errorIncorrectCredentials => '電子郵件或密碼錯誤。';

  @override
  String get errorInvalidEmail => '此電子郵件地址無效。';

  @override
  String get errorAccountDisabled => '此帳號已被停用。';

  @override
  String get errorTooManyRequests => '嘗試次數過多，請稍後再試。';

  @override
  String get errorSignInFailed => '登入失敗，請再試一次。';

  @override
  String get registerTitle => '建立帳號';

  @override
  String get registerSubtitle => '開始使用 Life OS';

  @override
  String get confirmPasswordLabel => '確認密碼';

  @override
  String get registerButton => '註冊';

  @override
  String get signingUp => '註冊中…';

  @override
  String get errorPasswordMismatch => '兩次密碼不一致';

  @override
  String get errorEmailAlreadyInUse => '這個電子郵件已被使用';

  @override
  String get errorWeakPassword => '密碼強度不足（至少 6 個字元）';

  @override
  String get noAccountLink => '還沒有帳號？註冊';

  @override
  String get haveAccountLink => '已有帳號？登入';

  @override
  String get greetingMorning => '早安';

  @override
  String get greetingAfternoon => '午安';

  @override
  String get greetingEvening => '晚安';

  @override
  String get yourSpaces => '你的空間';

  @override
  String get spaceHealth => '健康';

  @override
  String get spaceFinance => '財務';

  @override
  String get spaceTasks => '任務';

  @override
  String get spaceJournal => '日誌';

  @override
  String get signedIn => '已登入';

  @override
  String get signOut => '登出';

  @override
  String get signInAgain => '重新登入';

  @override
  String get pleaseSignInAgain => '請重新登入。';

  @override
  String get errorProfileLoadFailed => '無法載入你的個人資料，請再試一次。';

  @override
  String get errorSomethingWentWrong => '發生錯誤，請再試一次。';

  @override
  String get authErrorGeneric => '發生錯誤，請再試一次。';

  @override
  String get retry => '重試';

  @override
  String get switchLanguage => '切換語言';

  @override
  String get followSystemLanguage => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsIconTooltip => '設定';

  @override
  String get themeSectionTitle => '主題';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get languageSectionTitle => '語言';

  @override
  String get dietTabToday => '今日';

  @override
  String get dietTabTarget => '目標';

  @override
  String get dietCategoryStaple => '主食';

  @override
  String get dietCategoryMeat => '肉類';

  @override
  String get dietCategoryFruit => '水果';

  @override
  String get dietCategoryVeg => '蔬菜';

  @override
  String get dietCategoryIconStaple => '主';

  @override
  String get dietCategoryIconMeat => '肉';

  @override
  String get dietCategoryIconFruit => '果';

  @override
  String get dietCategoryIconVeg => '菜';

  @override
  String dietProgressOfTarget(double logged, double target) {
    final intl.NumberFormat loggedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String loggedString = loggedNumberFormat.format(logged);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$loggedString / $targetString';
  }

  @override
  String dietRemainingOfCategory(double remaining) {
    final intl.NumberFormat remainingNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);

    return '剩餘 $remainingString';
  }

  @override
  String get dietMealBreakfast => '早餐';

  @override
  String get dietMealLunch => '午餐';

  @override
  String get dietMealDinner => '晚餐';

  @override
  String get dietAddSnack => '新增點心';

  @override
  String get dietSnackLabelHint => '點心名稱';

  @override
  String get dietSnackBaseName => '點心';

  @override
  String dietLoggingToMeal(String meal) {
    return '記錄到：$meal';
  }

  @override
  String get dietLoggingDoneButton => '完成';

  @override
  String dietAddedToMealSnackbar(String meal) {
    return '已加入 $meal';
  }

  @override
  String get dietSnackRenameTooltip => '命名這批點心';

  @override
  String get dietSnackRenameConfirmTooltip => '確認名稱';

  @override
  String get dietSnackRenameCancelTooltip => '取消改名';

  @override
  String get dietSearchFoodHint => '搜尋食物';

  @override
  String get dietFavoritesTitle => '常用食物';

  @override
  String get dietQuantityLabel => '份量';

  @override
  String get dietGramsLabel => '公克';

  @override
  String get dietUseGramsLabel => '使用公克';

  @override
  String get dietEatenAtLabel => '食用時間';

  @override
  String get dietSaveEntryButton => '儲存';

  @override
  String dietAddToMealButton(String meal) {
    return '加入$meal';
  }

  @override
  String get dietPreviewTitle => '預覽';

  @override
  String get dietSetTargetTitle => '設定每日目標';

  @override
  String get dietSaveTargetButton => '儲存';

  @override
  String get dietFavoriteTooltip => '加入常用';

  @override
  String get dietUnfavoriteTooltip => '移除常用';

  @override
  String get errorDietLoadFailed => '無法載入飲食資料，請再試一次。';

  @override
  String get dietManualEntryAffordance => '找不到? 手動輸入';

  @override
  String get dietManualEntryTitle => '手動記錄飲食';

  @override
  String get dietManualEntryNameLabel => '名稱（選填）';

  @override
  String get dietManualEntryFallbackName => '手動記錄';

  @override
  String get dietManualEntryAllZeroError => '儲存前請至少輸入一項份量。';

  @override
  String get dietTabAll => '全部';

  @override
  String get dietSearchAllPrompt => '搜尋食物以查看結果';

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
  String get dietBonusNote => '✳️ 運動後可加成份數（之後串運動模組）';

  @override
  String get dietEditEntryTitle => '編輯記錄';

  @override
  String get dietDeleteEntryButton => '刪除';

  @override
  String get dietDeleteConfirmTitle => '刪除記錄？';

  @override
  String get dietDeleteConfirmMessage => '這將移除該記錄，且無法復原。';

  @override
  String get dietTodayTitle => '今日飲食';

  @override
  String get dietHistoryTitle => '飲食紀錄';

  @override
  String get dietDayToday => '今日';

  @override
  String get dietDayYesterday => '昨天';

  @override
  String get dietCalendarTitle => '日曆';

  @override
  String get dietCalendarCloseTooltip => '關閉';

  @override
  String get dietDayPrevTooltip => '前一天';

  @override
  String get dietDayNextTooltip => '後一天';

  @override
  String get dietCalendarOpenTooltip => '開啟日曆';

  @override
  String get dietGoHomeTooltip => '回首頁';

  @override
  String get dietCalendarPrevMonth => '上個月';

  @override
  String get dietCalendarNextMonth => '下個月';

  @override
  String get dietAddToMeal => '加';

  @override
  String dietAddToMealA11yLabel(String meal) {
    return '加到$meal';
  }

  @override
  String get dietMealEmptyLabel => '還沒記錄';

  @override
  String get dietSnackAreaTitle => '點心';

  @override
  String get dietAddSnackButton => '加點心';

  @override
  String get dietOpenDictionaryTooltip => '食物字典';

  @override
  String get dietBrowseOnlyHint => '瀏覽模式 — 點 ♥ 收藏。記錄請從各餐的＋。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get welcomeBack => '歡迎回來';

  @override
  String get signInSubtitle => '登入 Life OS';

  @override
  String get emailLabel => '電子郵件';

  @override
  String get passwordLabel => '密碼';

  @override
  String get signInButton => '登入';

  @override
  String get signingIn => '登入中…';

  @override
  String get errorIncorrectCredentials => '電子郵件或密碼錯誤。';

  @override
  String get errorInvalidEmail => '此電子郵件地址無效。';

  @override
  String get errorAccountDisabled => '此帳號已被停用。';

  @override
  String get errorTooManyRequests => '嘗試次數過多，請稍後再試。';

  @override
  String get errorSignInFailed => '登入失敗，請再試一次。';

  @override
  String get registerTitle => '建立帳號';

  @override
  String get registerSubtitle => '開始使用 Life OS';

  @override
  String get confirmPasswordLabel => '確認密碼';

  @override
  String get registerButton => '註冊';

  @override
  String get signingUp => '註冊中…';

  @override
  String get errorPasswordMismatch => '兩次密碼不一致';

  @override
  String get errorEmailAlreadyInUse => '這個電子郵件已被使用';

  @override
  String get errorWeakPassword => '密碼強度不足（至少 6 個字元）';

  @override
  String get noAccountLink => '還沒有帳號？註冊';

  @override
  String get haveAccountLink => '已有帳號？登入';

  @override
  String get greetingMorning => '早安';

  @override
  String get greetingAfternoon => '午安';

  @override
  String get greetingEvening => '晚安';

  @override
  String get yourSpaces => '你的空間';

  @override
  String get spaceHealth => '健康';

  @override
  String get spaceFinance => '財務';

  @override
  String get spaceTasks => '任務';

  @override
  String get spaceJournal => '日誌';

  @override
  String get signedIn => '已登入';

  @override
  String get signOut => '登出';

  @override
  String get signInAgain => '重新登入';

  @override
  String get pleaseSignInAgain => '請重新登入。';

  @override
  String get errorProfileLoadFailed => '無法載入你的個人資料，請再試一次。';

  @override
  String get errorSomethingWentWrong => '發生錯誤，請再試一次。';

  @override
  String get authErrorGeneric => '發生錯誤，請再試一次。';

  @override
  String get retry => '重試';

  @override
  String get switchLanguage => '切換語言';

  @override
  String get followSystemLanguage => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsIconTooltip => '設定';

  @override
  String get themeSectionTitle => '主題';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get languageSectionTitle => '語言';

  @override
  String get dietTabToday => '今日';

  @override
  String get dietTabTarget => '目標';

  @override
  String get dietCategoryStaple => '主食';

  @override
  String get dietCategoryMeat => '肉類';

  @override
  String get dietCategoryFruit => '水果';

  @override
  String get dietCategoryVeg => '蔬菜';

  @override
  String get dietCategoryIconStaple => '主';

  @override
  String get dietCategoryIconMeat => '肉';

  @override
  String get dietCategoryIconFruit => '果';

  @override
  String get dietCategoryIconVeg => '菜';

  @override
  String dietProgressOfTarget(double logged, double target) {
    final intl.NumberFormat loggedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String loggedString = loggedNumberFormat.format(logged);
    final intl.NumberFormat targetNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$loggedString / $targetString';
  }

  @override
  String dietRemainingOfCategory(double remaining) {
    final intl.NumberFormat remainingNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);

    return '剩餘 $remainingString';
  }

  @override
  String get dietMealBreakfast => '早餐';

  @override
  String get dietMealLunch => '午餐';

  @override
  String get dietMealDinner => '晚餐';

  @override
  String get dietAddSnack => '新增點心';

  @override
  String get dietSnackLabelHint => '點心名稱';

  @override
  String get dietSnackBaseName => '點心';

  @override
  String dietLoggingToMeal(String meal) {
    return '記錄到：$meal';
  }

  @override
  String get dietLoggingDoneButton => '完成';

  @override
  String dietAddedToMealSnackbar(String meal) {
    return '已加入 $meal';
  }

  @override
  String get dietSnackRenameTooltip => '命名這批點心';

  @override
  String get dietSnackRenameConfirmTooltip => '確認名稱';

  @override
  String get dietSnackRenameCancelTooltip => '取消改名';

  @override
  String get dietSearchFoodHint => '搜尋食物';

  @override
  String get dietFavoritesTitle => '常用食物';

  @override
  String get dietQuantityLabel => '份量';

  @override
  String get dietGramsLabel => '公克';

  @override
  String get dietUseGramsLabel => '使用公克';

  @override
  String get dietEatenAtLabel => '食用時間';

  @override
  String get dietSaveEntryButton => '儲存';

  @override
  String dietAddToMealButton(String meal) {
    return '加入$meal';
  }

  @override
  String get dietPreviewTitle => '預覽';

  @override
  String get dietSetTargetTitle => '設定每日目標';

  @override
  String get dietSaveTargetButton => '儲存';

  @override
  String get dietFavoriteTooltip => '加入常用';

  @override
  String get dietUnfavoriteTooltip => '移除常用';

  @override
  String get errorDietLoadFailed => '無法載入飲食資料，請再試一次。';

  @override
  String get dietManualEntryAffordance => '找不到? 手動輸入';

  @override
  String get dietManualEntryTitle => '手動記錄飲食';

  @override
  String get dietManualEntryNameLabel => '名稱（選填）';

  @override
  String get dietManualEntryFallbackName => '手動記錄';

  @override
  String get dietManualEntryAllZeroError => '儲存前請至少輸入一項份量。';

  @override
  String get dietTabAll => '全部';

  @override
  String get dietSearchAllPrompt => '搜尋食物以查看結果';

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
  String get dietBonusNote => '✳️ 運動後可加成份數（之後串運動模組）';

  @override
  String get dietEditEntryTitle => '編輯記錄';

  @override
  String get dietDeleteEntryButton => '刪除';

  @override
  String get dietDeleteConfirmTitle => '刪除記錄？';

  @override
  String get dietDeleteConfirmMessage => '這將移除該記錄，且無法復原。';

  @override
  String get dietTodayTitle => '今日飲食';

  @override
  String get dietHistoryTitle => '飲食紀錄';

  @override
  String get dietDayToday => '今日';

  @override
  String get dietDayYesterday => '昨天';

  @override
  String get dietCalendarTitle => '日曆';

  @override
  String get dietCalendarCloseTooltip => '關閉';

  @override
  String get dietDayPrevTooltip => '前一天';

  @override
  String get dietDayNextTooltip => '後一天';

  @override
  String get dietCalendarOpenTooltip => '開啟日曆';

  @override
  String get dietGoHomeTooltip => '回首頁';

  @override
  String get dietCalendarPrevMonth => '上個月';

  @override
  String get dietCalendarNextMonth => '下個月';

  @override
  String get dietAddToMeal => '加';

  @override
  String dietAddToMealA11yLabel(String meal) {
    return '加到$meal';
  }

  @override
  String get dietMealEmptyLabel => '還沒記錄';

  @override
  String get dietSnackAreaTitle => '點心';

  @override
  String get dietAddSnackButton => '加點心';

  @override
  String get dietOpenDictionaryTooltip => '食物字典';

  @override
  String get dietBrowseOnlyHint => '瀏覽模式 — 點 ♥ 收藏。記錄請從各餐的＋。';
}
