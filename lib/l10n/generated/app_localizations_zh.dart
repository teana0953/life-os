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
  String get trackerStillSaving => '尚在儲存——請稍後再試。';

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
  String get cardRefreshFailed => '沒有更新到';

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
  String get settingsInstallSectionTitle => '安裝應用程式';

  @override
  String get settingsInstallButton => '安裝 LifeOS';

  @override
  String get settingsInstallIosHint => '加到主畫面:分享 → 加入主畫面';

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
  String get dietSnackBaseName => '點心';

  @override
  String get dietSearchFoodHint => '搜尋食物';

  @override
  String get dietQuantityLabel => '份量';

  @override
  String get dietGramsLabel => '公克';

  @override
  String get dietPortionUnit => '份';

  @override
  String dietAddToMealButton(String meal) {
    return '加入$meal';
  }

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
  String get dietBonusNote => '✳️ 運動會加成當日目標份數(主食・肉類)。';

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
  String get dietCalendarPrevMonth => '上個月';

  @override
  String get dietCalendarNextMonth => '下個月';

  @override
  String dietAddToMealA11yLabel(String meal) {
    return '加到$meal';
  }

  @override
  String get dietMealEmptyLabel => '還沒記錄';

  @override
  String get dietAddSnackButton => '加點心';

  @override
  String dietSearchDoneButton(int count) {
    return '完成（$count）';
  }

  @override
  String get dietDictionaryTitle => '食物字典';

  @override
  String get dietOpenDictionaryTooltip => '查詢食物';

  @override
  String get dietChooseMealSheetTitle => '要加到哪一餐？';

  @override
  String get dietRemoveItemTooltip => '移除';

  @override
  String get dietMealTotalLabel => '合計';

  @override
  String get dietSaveMealFailed => '儲存失敗，請再試一次。';

  @override
  String get dietUnnamedItemLabel => '未命名項目';

  @override
  String get dietMeasureUnitMl => '毫升';

  @override
  String get dietManualEntryLink => '找不到？手動輸入';

  @override
  String get dietDictionaryFavoritesEmptyTitle => '還沒有常用食物';

  @override
  String get dietDictionaryFavoritesEmptyBody => '搜尋看看某個食物算幾份，點愛心就能留在這裡。';

  @override
  String dietDictionaryNoResultsTitle(String query) {
    return '找不到「$query」';
  }

  @override
  String get dietDictionaryNoResultsBody => '換個名字再找找看。';

  @override
  String get dietDictionaryLoadFailed => '無法載入食物，請再試一次。';

  @override
  String get dietManualEntryTitle => '手動輸入';

  @override
  String get dietManualEntryNameLabel => '名稱';

  @override
  String get dietManualEntryAddButton => '加入';

  @override
  String get dietDeleteItemTooltip => '刪除';

  @override
  String get dietDeleteMealTooltip => '刪除整餐';

  @override
  String get dietDeleteMealConfirmTitle => '刪除這餐？';

  @override
  String get dietDeleteMealConfirmMessage => '將會移除所有項目。';

  @override
  String get dietDeleteMealConfirmButton => '刪除';

  @override
  String get dietChangeTimeTooltip => '改時間';

  @override
  String get errorDietItemNotFound => '找不到這筆紀錄。';

  @override
  String get dietSaveEditButton => '儲存';

  @override
  String get dietTabWater => '飲水';

  @override
  String get waterTitle => '今日飲水';

  @override
  String get waterHistoryTitle => '飲水紀錄';

  @override
  String waterTotalOfTarget(int total, int target) {
    return '$total / $target ml';
  }

  @override
  String get waterAdd250 => '＋250 ml';

  @override
  String get waterAdd500 => '＋500 ml';

  @override
  String get waterCustomAmount => '自訂';

  @override
  String get waterCorrect250 => '−250 ml';

  @override
  String get waterSetTargetButton => '設定目標';

  @override
  String get waterCustomAmountTitle => '新增飲水量(ml)';

  @override
  String get waterSetTargetTitle => '每日飲水目標(ml)';

  @override
  String get errorWaterLoadFailed => '無法載入飲水資料,請再試一次。';

  @override
  String get waterSaveFailed => '儲存失敗,請再試一次';

  @override
  String get waterGoalMet => '達標';

  @override
  String get dietTabBowel => '排便';

  @override
  String get bowelTitle => '今日排便';

  @override
  String get bowelHistoryTitle => '排便紀錄';

  @override
  String get bowelCountLabel => '次數';

  @override
  String get bowelNormalityLabel => '是否正常';

  @override
  String get bowelNormalLabel => '正常';

  @override
  String get bowelAbnormalLabel => '異常';

  @override
  String get bowelNoteLabel => '備註';

  @override
  String get bowelSaveButton => '儲存';

  @override
  String get bowelUnsavedChanges => '尚未儲存';

  @override
  String get bowelSaveFailed => '儲存失敗,請再試一次';

  @override
  String get errorBowelLoadFailed => '無法載入排便資料,請再試一次。';

  @override
  String get dietTabVitals => '數值';

  @override
  String get vitalsTitle => '今日數值';

  @override
  String get vitalsHistoryTitle => '數值紀錄';

  @override
  String get vitalsWeightLabel => '體重(公斤)';

  @override
  String get vitalsBodyFatLabel => '體脂(%)';

  @override
  String get vitalsBloodPressureSection => '血壓 (mmHg)';

  @override
  String get vitalsGlucoseSection => '血糖';

  @override
  String get vitalsSpo2Section => '血氧';

  @override
  String get vitalsSystolicLabel => '收縮壓';

  @override
  String get vitalsDiastolicLabel => '舒張壓';

  @override
  String get vitalsPulseLabel => '脈搏';

  @override
  String get vitalsPulseUnit => 'bpm';

  @override
  String get vitalsGlucoseLabelField => '標籤';

  @override
  String get vitalsGlucoseValueLabel => 'mg/dL';

  @override
  String get vitalsSpo2Label => '血氧 (%)';

  @override
  String get vitalsAddReading => '加一筆';

  @override
  String get vitalsRemoveReading => '移除';

  @override
  String get vitalsSaveButton => '儲存';

  @override
  String get vitalsTimeLabel => '時間';

  @override
  String get vitalsUnsavedChanges => '尚未儲存';

  @override
  String get vitalsSaveFailed => '儲存失敗,請再試一次';

  @override
  String get errorVitalsLoadFailed => '無法載入數值資料,請再試一次。';

  @override
  String get dietTabMore => '更多';

  @override
  String get dietTabExercise => '運動';

  @override
  String get exerciseTitle => '今日運動';

  @override
  String get exerciseHistoryTitle => '運動記錄';

  @override
  String exerciseTotalMinutes(int minutes) {
    return '共 $minutes 分鐘';
  }

  @override
  String exerciseEntryDuration(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get exerciseEmptyLabel => '尚未記錄運動';

  @override
  String get exerciseAddButton => '記錄運動';

  @override
  String get exerciseAddDialogTitle => '記錄運動';

  @override
  String get exerciseActivityLabel => '項目';

  @override
  String get exerciseDurationLabel => '分鐘';

  @override
  String get exerciseNoteLabel => '備註';

  @override
  String get exerciseCategoryAerobic => '有氧';

  @override
  String get exerciseCategoryAnaerobic => '無氧';

  @override
  String get exerciseAddConfirmButton => '新增';

  @override
  String get exerciseRemoveEntry => '移除';

  @override
  String get exerciseSaveFailed => '儲存失敗,請再試一次';

  @override
  String get exerciseEntryRemoved => '已移除運動紀錄';

  @override
  String get exerciseUndo => '復原';

  @override
  String get errorExerciseLoadFailed => '無法載入運動資料,請再試一次。';

  @override
  String get menstrualTitle => '生理期';

  @override
  String get menstrualAverageCycleLabel => '平均週期';

  @override
  String get menstrualAveragePeriodLabel => '平均經期';

  @override
  String get menstrualPredictedNextLabel => '預測下次';

  @override
  String menstrualDaysValue(int days) {
    return '$days 天';
  }

  @override
  String get menstrualStatPlaceholder => '—';

  @override
  String get menstrualLastPeriodLabel => '最近一次週期';

  @override
  String get menstrualOngoingLabel => '進行中';

  @override
  String get menstrualAddButton => '新增週期';

  @override
  String get menstrualAddDialogTitle => '新增週期';

  @override
  String get menstrualEditDialogTitle => '編輯週期';

  @override
  String get menstrualStartDateLabel => '開始日期';

  @override
  String get menstrualEndDateLabel => '結束日期';

  @override
  String get menstrualSelectDate => '選擇';

  @override
  String get menstrualClearEndDate => '清除結束日期';

  @override
  String get menstrualEndBeforeStartError => '結束日期不能早於開始日期。';

  @override
  String get menstrualSavePeriod => '儲存';

  @override
  String get menstrualDeletePeriod => '刪除';

  @override
  String get menstrualPeriodDeleted => '已刪除週期';

  @override
  String get menstrualUndo => '復原';

  @override
  String get menstrualSaveFailed => '儲存失敗,請再試一次';

  @override
  String get menstrualPrevMonth => '上個月';

  @override
  String get menstrualNextMonth => '下個月';

  @override
  String menstrualDaySemanticPeriod(String date) {
    return '$date,經期';
  }

  @override
  String menstrualDaySemanticPredicted(String date) {
    return '$date,預測下次';
  }

  @override
  String menstrualDaySemanticToday(String date) {
    return '$date,今天';
  }

  @override
  String get menstrualLegendPeriod => '經期';

  @override
  String get menstrualLegendPredicted => '預測下次';

  @override
  String get menstrualEmptyHint => '還沒有生理期紀錄,點日曆上的日期或「新增週期」開始記錄。';

  @override
  String get nextPeriodTitle => '下次生理期';

  @override
  String nextPeriodUpcoming(String date, int days) {
    return '$date・還有 $days 天';
  }

  @override
  String get nextPeriodToday => '預計今天';

  @override
  String nextPeriodOverdue(String date, int days) {
    return '預計 $date・已過 $days 天還沒有紀錄';
  }

  @override
  String nextPeriodOngoing(int day) {
    return '進行中・第 $day 天';
  }

  @override
  String nextPeriodOngoingNext(String date) {
    return '下次預計 $date';
  }

  @override
  String get nextPeriodNoRecords => '還沒有生理期紀錄';

  @override
  String get nextPeriodNeedsOneMore => '再記錄一次就能預測下次';

  @override
  String get errorMenstrualLoadFailed => '無法載入生理期資料,請再試一次。';

  @override
  String get errorCareTodayLoadFailed => '無法載入今日照護,請再試一次。';

  @override
  String get updateAvailableTitle => '有新版本可用';

  @override
  String get updateButton => '更新';

  @override
  String get updateDismiss => '關閉';

  @override
  String get dashboardTitle => '總覽';

  @override
  String get healthTabRecord => '記錄';

  @override
  String get healthRecordDiet => '飲食';

  @override
  String get healthCalendarTitle => '本月記錄';

  @override
  String get healthCalendarLoggingRate => '記錄率';

  @override
  String get healthCalendarDietRate => '飲食達標';

  @override
  String get healthCalendarWeightRate => '體重達成';

  @override
  String get healthCalendarLoggedLegend => '有記錄';

  @override
  String get healthCalendarNoData => '無資料';

  @override
  String get healthCalendarLoadFailed => '無法載入本月記錄,請再試一次。';

  @override
  String get goalCardTitle => '體重目標';

  @override
  String get goalTargetLabel => '目標';

  @override
  String get goalCurrentLabel => '目前';

  @override
  String get goalRemainingLabel => '剩餘';

  @override
  String get goalKgUnit => '公斤';

  @override
  String get goalCmUnit => '公分';

  @override
  String get goalHeightShortLabel => '身高';

  @override
  String get goalAchievementLabel => '達成率';

  @override
  String get goalAchievementHint => '再記一天體重即可顯示進度。';

  @override
  String get goalBmiLabel => 'BMI';

  @override
  String get goalPlaceholder => '—';

  @override
  String get goalNoData => '無資料';

  @override
  String get goalUnsetPrompt => '設定身高與目標體重,開始追蹤你的目標。';

  @override
  String get goalSetButton => '設定你的目標';

  @override
  String get goalEditTitle => '設定你的目標';

  @override
  String get goalHeightLabel => '身高(公分)';

  @override
  String get goalTargetWeightLabel => '目標體重(公斤)';

  @override
  String get goalSaveButton => '儲存';

  @override
  String get errorWeightGoalLoadFailed => '無法載入目標資料,請再試一次。';

  @override
  String get trendCardTitle => '趨勢';

  @override
  String get trendMetricWeight => '體重';

  @override
  String get trendMetricBodyFat => '體脂';

  @override
  String get trendMetricSystolic => '收縮壓';

  @override
  String get trendMetricDiastolic => '舒張壓';

  @override
  String get trendMetricPulse => '心跳';

  @override
  String get trendMetricGlucose => '血糖';

  @override
  String get trendMetricSpo2 => '血氧';

  @override
  String get trendMetricBloodPressurePulse => '血壓・心跳';

  @override
  String get glucoseContextFasting => '空腹';

  @override
  String get glucoseContextPreMeal => '餐前';

  @override
  String get glucoseContextPostMeal => '餐後';

  @override
  String get glucoseContextUnspecified => '未分類';

  @override
  String get trendRange7 => '7 天';

  @override
  String get trendRange30 => '30 天';

  @override
  String get trendRange90 => '90 天';

  @override
  String get trendEmpty => '尚無資料';

  @override
  String get trendNormalRangeLabel => '正常範圍';

  @override
  String get trendLoadFailed => '無法載入趨勢資料,請再試一次。';

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

    return '$metric趨勢,近 $days 天,最新 $valueString $unit';
  }

  @override
  String trendChartSemanticsEmpty(String metric, int days) {
    return '$metric趨勢,近 $days 天,無資料';
  }

  @override
  String trendChartSemanticsMulti(String metric, int days) {
    return '$metric趨勢,近 $days 天';
  }

  @override
  String get importTitle => '從 chaodays 匯入';

  @override
  String get importAccountLabel => 'chaodays 帳號';

  @override
  String get importPasswordLabel => 'chaodays 密碼';

  @override
  String get importStartDateLabel => '起始日期';

  @override
  String get importEndDateLabel => '結束日期';

  @override
  String get importSelectDateLabel => '選擇';

  @override
  String get importSubmitButton => '開始匯入';

  @override
  String get importDoneMessage => '匯入完成';

  @override
  String get importCredentialsNote => '帳密僅用於這次匯入,不會儲存。';

  @override
  String get importTypesTitle => '匯入項目';

  @override
  String get importTypeWeight => '體重體脂';

  @override
  String get importTypeDiet => '飲食血糖';

  @override
  String get importTypeWater => '飲水';

  @override
  String get importTypeBowel => '排便';

  @override
  String get importTypeDietTarget => '飲食目標';

  @override
  String get importTypeMenstrual => '生理期';

  @override
  String get importMenstrualOpenPeriodHint => '進行中的週期會跳過，等它結束後再匯入一次';

  @override
  String importResultSummary(int imported, int skipped) {
    return '匯入 $imported・跳過 $skipped';
  }

  @override
  String importResultGlucoseSuffix(int count) {
    return '・血糖 $count';
  }

  @override
  String importResultWaterTargetSuffix(int count) {
    return '・飲水目標 $count';
  }

  @override
  String get importTypeFailed => '失敗';

  @override
  String get importStatusImporting => '正在匯入';

  @override
  String get importStatusSuccess => '匯入成功';

  @override
  String get importStatusFailed => '匯入失敗';

  @override
  String get importStatusNotAttempted => '未匯入';

  @override
  String get importErrorAuthFailed => 'chaodays 帳號或密碼錯誤,請確認後再試一次。';

  @override
  String get importErrorUnavailable => 'chaodays 暫時無法連線,請稍後再試。';

  @override
  String get reminderTitle => '提醒通知';

  @override
  String get reminderStatusUnsupported => '此瀏覽器或裝置不支援通知功能。';

  @override
  String get reminderStatusIosNeedsInstall =>
      '在 iOS 上要接收通知,請在 Safari 點選分享圖示,選擇「加入主畫面」,然後從主畫面開啟 LifeOS 並回到這裡。';

  @override
  String get reminderStatusPermissionDenied => '此網站的通知已被封鎖,請至瀏覽器設定開啟後再回來。';

  @override
  String get reminderEnabledStatus => '此裝置已開啟通知。';

  @override
  String get reminderErrorGeneric => '開啟通知時發生錯誤,請再試一次。';

  @override
  String get reminderEnableButton => '開啟通知';

  @override
  String get reminderTestButton => '測試推播';

  @override
  String reminderTestResult(int sent, int failed) {
    return '已送出 $sent・失敗 $failed';
  }

  @override
  String get reminderTestErrorGeneric => '測試推播失敗,請再試一次。';

  @override
  String get reminderTestSent => '測試推播已送出,請查看你的裝置通知。';

  @override
  String get reminderTestNoDevice => '目前沒有已啟用的裝置收到,請再開啟一次通知。';

  @override
  String get reminderRecheck => '重新檢查';

  @override
  String get reminderStillBlocked => '通知仍被封鎖,請到瀏覽器設定開啟後再重新檢查。';

  @override
  String get careRemindersTitle => '照護管理';

  @override
  String get careRemindersEmptyTitle => '還沒有任何提醒';

  @override
  String get careRemindersEmptyBody => '新增一筆提醒,涵蓋用藥、復健、放療保養或自訂項目。';

  @override
  String get careRemindersAddButton => '新增提醒';

  @override
  String get careCategoryMedication => '用藥';

  @override
  String get careCategoryRehab => '復健';

  @override
  String get careCategoryRadiotherapyCare => '放療保養';

  @override
  String get careCategoryCustom => '自訂';

  @override
  String get careEveryDay => '每天';

  @override
  String careWeekIntervalSuffix(int n) {
    return '· 每 $n 週';
  }

  @override
  String careScheduleUntil(String date) {
    return '至 $date';
  }

  @override
  String careScheduleFrom(String date) {
    return '$date 起';
  }

  @override
  String careStockLabel(String n) {
    return '庫存:$n';
  }

  @override
  String get careDeleteConfirmTitle => '刪除這筆提醒?';

  @override
  String get careDeleteConfirmMessage => '刪除後將不再提醒。';

  @override
  String get careDeleteConfirmButton => '刪除';

  @override
  String get careCancelButton => '取消';

  @override
  String get careErrorGeneric => '發生問題,請再試一次。';

  @override
  String get careFormTitleAdd => '新增照護提醒';

  @override
  String get careFormTitleEdit => '編輯照護提醒';

  @override
  String get careCategoryLabel => '分類';

  @override
  String get careTitleField => '標題';

  @override
  String get careNoteField => '備註';

  @override
  String get careDoseField => '劑量說明';

  @override
  String get careStockField => '庫存數量';

  @override
  String get careStockAlertField => '低庫存提醒門檻';

  @override
  String get careSchedulesLabel => '排程';

  @override
  String get careAddScheduleButton => '新增排程';

  @override
  String get careRemoveScheduleTooltip => '移除排程';

  @override
  String get careChangeTimeTooltip => '變更時間';

  @override
  String get careTimeLabel => '時間';

  @override
  String get careWeekdaysLabel => '重複星期';

  @override
  String get careWeekdaysEmptyHint => '全部不選 = 每天。';

  @override
  String careWeekIntervalValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每 $n 週',
      one: '每週',
    );
    return '$_temp0';
  }

  @override
  String get careStartDateLabel => '起始日';

  @override
  String get careEndDateLabel => '結束日';

  @override
  String get careAddEndDateButton => '新增結束日';

  @override
  String get careRemoveEndDateTooltip => '移除結束日';

  @override
  String get careDoseQuantityLabel => '每次劑量';

  @override
  String get careNagIntervalLabel => '提醒重複頻率';

  @override
  String get careNagOnceLabel => '只提醒一次';

  @override
  String careNagEveryNMinutes(int n) {
    return '每 $n 分鐘';
  }

  @override
  String get careIncompleteHint => '請輸入標題並新增至少一筆排程,才能儲存。';

  @override
  String get careSaveButton => '儲存';

  @override
  String get weekdayShortSun => '週日';

  @override
  String get weekdayShortMon => '週一';

  @override
  String get weekdayShortTue => '週二';

  @override
  String get weekdayShortWed => '週三';

  @override
  String get weekdayShortThu => '週四';

  @override
  String get weekdayShortFri => '週五';

  @override
  String get weekdayShortSat => '週六';

  @override
  String get careTodayTitle => '今日照護';

  @override
  String get careTodayOverdueSection => '逾期';

  @override
  String get careTodayLaterSection => '稍後';

  @override
  String careTodayDoneSection(int n) {
    return '已完成（$n）';
  }

  @override
  String get careTodayMarkDoneButton => '完成';

  @override
  String get careTodaySkipButton => '略過';

  @override
  String careTodayDoneAtLabel(String time) {
    return '$time 完成';
  }

  @override
  String get careTodayEmptyTitle => '今天沒有排程';

  @override
  String get careTodayEmptyBody => '新增照護提醒後就會顯示在這裡。';

  @override
  String get careTodayCelebrationTitle => '今天的照護都完成了！';

  @override
  String get careTodayCelebrationBody => '做得好，明天見。';

  @override
  String get careTodayUpNext => '接下來';

  @override
  String get careTodayStatusSkipped => '略過';

  @override
  String get careTodayStatusMissed => '未完成';

  @override
  String get careTodayEditSheetTitle => '更新這筆紀錄';

  @override
  String get careTodayEditTimeLabel => '完成時間';

  @override
  String get careTodayEditSubmitButton => '儲存';

  @override
  String careTodaySummaryProgress(int done, int total) {
    return '$done/$total 完成';
  }

  @override
  String careTodaySummaryMoreCount(int n) {
    return '還有 $n 項';
  }

  @override
  String get careTodaySummarySeeAll => '查看全部';

  @override
  String get careTodaySummaryManage => '管理';

  @override
  String get careTodaySummarySetupTitle => '還沒有照護提醒';

  @override
  String get careTodaySummarySetupCta => '設定';

  @override
  String get careRemindersPushOffBanner => '通知還沒開啟，提醒不會送達';

  @override
  String get careRemindersPushOffAction => '開啟通知';

  @override
  String get careRemindersPushDeniedBanner => '通知已被封鎖，提醒不會送達';

  @override
  String get careHistoryTitle => '照護紀錄';

  @override
  String get careHistoryEntryTooltip => '紀錄';

  @override
  String get careHistoryEmptyTitle => '沒有照護紀錄';

  @override
  String get careHistoryEmptyBody => '這段期間沒有排程。';

  @override
  String get careHistoryWidenPeriodButton => '看更長期間';

  @override
  String get careHistoryEmptyManageButton => '前往照護管理';

  @override
  String get careHistoryAdherenceRateLabel => '達成率';

  @override
  String get careHistoryDaysWithDoseLabel => '有完成的天數';

  @override
  String get careHistoryMissedCountLabel => '未完成次數';

  @override
  String get careHistoryLegendFull => '完成';

  @override
  String get careHistoryLegendPartial => '部分';

  @override
  String get careHistoryLegendMissed => '未完成';

  @override
  String get careHistoryLegendNoSchedule => '無排程';

  @override
  String get careHistoryEditSheetTitle => '更新這筆紀錄';

  @override
  String get careHistoryStatusDone => '已完成';

  @override
  String get careHistoryStatusPending => '待完成';

  @override
  String get careHistoryStatusOverdue => '逾期';

  @override
  String get careHistoryLegendUpcoming => '尚未到期';

  @override
  String get careHistoryEditSuccessMessage => '已儲存。';

  @override
  String get careHistoryEditRefreshErrorMessage => '已儲存，但更新清單失敗。';

  @override
  String get careHistoryPastReadOnlyHint => '這裡只有今天可以修改。';

  @override
  String get careAdherenceCardTitle => '照護達成';

  @override
  String careAdherenceHeatmapCellLabel(String date, String state) {
    return '$date · $state';
  }

  @override
  String get careAdherenceOpenHistory => '查看紀錄';

  @override
  String careAdherenceLegendWithCount(String label, int count) {
    return '$label（$count）';
  }

  @override
  String careAdherenceHeatmapRangeCaption(String from, String to) {
    return '$from – $to';
  }

  @override
  String careAdherenceHeatmapSummaryLabel(String details) {
    return '各狀態天數：$details';
  }

  @override
  String get careAdherenceHeatmapSummarySeparator => '、';

  @override
  String get careEditActionLabel => '編輯';

  @override
  String careErrorForPeriod(int days) {
    return '無法載入過去 $days 天的資料，請再試一次。';
  }

  @override
  String get careHistoryEditNotAppliedMessage => '未套用，沒有任何變更，請再試一次。';

  @override
  String get careHistoryNoCareItemsTitle => '還沒有任何照護項目';

  @override
  String get careHistoryNoCareItemsBody => '你還沒有設定任何照護項目，新增一個開始追蹤吧。';

  @override
  String lastUpdatedAt(String time) {
    return '上次更新 $time';
  }

  @override
  String get refreshDiscardTitle => '要捨棄未儲存的變更嗎？';

  @override
  String get refreshDiscardMessage => '重新整理會捨棄你尚未儲存的變更。';

  @override
  String get discard => '捨棄';

  @override
  String get cancel => '取消';

  @override
  String get sharedFoodItemCreateTitle => '新增共用品項';

  @override
  String get sharedFoodItemEditTitle => '編輯共用品項';

  @override
  String get sharedFoodItemNameLabel => '名稱';

  @override
  String get sharedFoodItemCarbLabel => '碳水化合物 (g)';

  @override
  String get sharedFoodItemProteinLabel => '蛋白質 (g)';

  @override
  String get sharedFoodItemFatLabel => '脂肪 (g)';

  @override
  String get sharedFoodItemSugarLabel => '糖 (g)';

  @override
  String get sharedFoodItemFiberLabel => '纖維 (g)';

  @override
  String get sharedFoodItemKcalLabel => '熱量 (kcal)';

  @override
  String get sharedFoodItemMeasureAmountLabel => '量基準數量';

  @override
  String get sharedFoodItemMeasureUnitLabel => '量基準單位';

  @override
  String get sharedFoodItemSubmitButton => '儲存';

  @override
  String get sharedFoodItemMeasurePairError => '數量與單位要一起填,或一起留空。';

  @override
  String get sharedFoodItemMeasureAmountPositiveError => '數量必須大於零。';

  @override
  String sharedFoodItemNumberFieldError(String field) {
    return '$field必須是零或正數。';
  }

  @override
  String get sharedFoodItemNameRequiredError => '名稱為必填。';

  @override
  String get sharedFoodItemCreateSuccess => '已建立共用品項。';

  @override
  String get sharedFoodItemEditSuccess => '已更新共用品項。';

  @override
  String get sharedFoodItemForbiddenError => '你沒有權限執行此操作。';

  @override
  String get sharedFoodItemSaveFailed => '儲存失敗,請再試一次。';

  @override
  String get sharedFoodItemNeedsReauthError => '請重新登入以儲存。';

  @override
  String get createSharedItemTooltip => '新增共用品項';

  @override
  String get editSharedItemTooltip => '編輯共用品項';

  @override
  String get editSharedItemMenuLabel => '編輯';

  @override
  String get sharedFoodItemPortionsHeading => '份量';

  @override
  String get sharedFoodItemNutrientsHeading => '營養素';

  @override
  String get financeTabOverview => '總覽';

  @override
  String get financeTabTransactions => '明細';

  @override
  String get financeFabTooltip => '記一筆';

  @override
  String get financeAddTitle => '記一筆';

  @override
  String get financeEditTitle => '編輯交易';

  @override
  String get financeAmountLabel => '金額';

  @override
  String get financeTypeExpense => '支出';

  @override
  String get financeTypeIncome => '收入';

  @override
  String get financeCategoryLabel => '分類';

  @override
  String get financeDateLabel => '日期';

  @override
  String get financeCurrencyLabel => '幣別';

  @override
  String get financeNoteLabel => '備註';

  @override
  String get financeSaveButton => '儲存';

  @override
  String get financeDeleteButton => '刪除';

  @override
  String get financeDeleteConfirmTitle => '刪除這筆交易?';

  @override
  String get financeDeleteConfirmMessage => '此動作無法復原。';

  @override
  String get financeDeleteConfirmButton => '刪除';

  @override
  String get financeCancelButton => '取消';

  @override
  String get financeSaveFailed => '儲存失敗,請檢查網路後重試。';

  @override
  String get financeLoadFailed => '財務資料載入失敗。';

  @override
  String get financeEmptyTitle => '這個月還沒有紀錄';

  @override
  String get financeEmptyCta => '記第一筆';

  @override
  String get financeExpenseTotal => '支出';

  @override
  String get financeIncomeTotal => '收入';

  @override
  String get financeNetTotal => '結餘';

  @override
  String get financeRecentTransactions => '最近交易';

  @override
  String get financeSplitSpendingTitle => '你的分帳自付額';

  @override
  String get financeSplitSpendingNote => '不計入上方的支出總額,也不計入預算。';

  @override
  String get financeSplitSpendingLoadFailed => '分帳自付額載入失敗';

  @override
  String get financeCategoryBreakdown => '分類統計';

  @override
  String get financeBudgetCardTitle => '預算';

  @override
  String get financeBudgetOverallLabel => '總額';

  @override
  String get financeBudgetEmptyTitle => '尚未設定預算';

  @override
  String get financeBudgetEmptyCta => '設定預算';

  @override
  String get financeBudgetOverLabel => '已超支';

  @override
  String get financeBudgetSheetTitle => '預算設定';

  @override
  String get financeBudgetSheetHint => '預算為每月循環設定,修改即套用到所有月份。';

  @override
  String get financeBudgetArchivedLabel => '已封存,僅能清空';

  @override
  String get financeBudgetClearButton => '清空';

  @override
  String get financeBudgetClearedLabel => '將被清空';

  @override
  String get financeBudgetInvalidAmount => 'Enter a valid amount';

  @override
  String get financeTabNetWorth => '淨值';

  @override
  String get networthNetWorthLabel => '淨值';

  @override
  String get networthGrowthUp => '上升';

  @override
  String get networthGrowthDown => '下降';

  @override
  String get networthGrowthFlat => '持平';

  @override
  String get networthArchivedSubtotal => '已封存科目';

  @override
  String get networthAssetsTitle => '資產';

  @override
  String get networthLiabilitiesTitle => '負債';

  @override
  String get networthTotalAssets => '資產合計';

  @override
  String get networthTotalLiabilities => '負債合計';

  @override
  String get networthTrendTitle => '淨值趨勢';

  @override
  String get networthTrendInsufficient => '資料不足,持續記錄以看趨勢。';

  @override
  String get networthTrendSummary => '近幾個月的淨值趨勢。';

  @override
  String get networthEmptyTitle => '本月尚未記錄任何市值';

  @override
  String get networthEmptyCta => '記錄第一筆';

  @override
  String get networthManageAccounts => '管理科目';

  @override
  String get networthAddAccount => '新增科目';

  @override
  String get networthAccountNameLabel => '科目名稱';

  @override
  String get networthKindAsset => '資產';

  @override
  String get networthKindLiability => '負債';

  @override
  String get networthArchiveButton => '封存';

  @override
  String get networthRestoreButton => '復原';

  @override
  String get networthArchivedLabel => '已封存';

  @override
  String get networthMoveUpTooltip => '上移';

  @override
  String get networthValueLabel => '市值 (TWD)';

  @override
  String get networthNotRecorded => '未記錄';

  @override
  String get networthInvalidValue => '請輸入 0 或以上的整數';

  @override
  String get networthSnapshotSheetTitle => '更新市值';

  @override
  String get networthAccountNameRequired => '請輸入科目名稱';

  @override
  String get networthSaveNameTooltip => '儲存名稱';

  @override
  String get monthNavPreviousTooltip => '上個月';

  @override
  String get monthNavNextTooltip => '下個月';

  @override
  String get monthPickerTitle => '選擇月份';

  @override
  String get monthPickerPreviousYearTooltip => '上一年';

  @override
  String get monthPickerNextYearTooltip => '下一年';

  @override
  String get monthPickerYearTooltip => '選擇年份';

  @override
  String get monthPickerOpenTooltip => '選擇月份';

  @override
  String get friendsTitle => '好友';

  @override
  String get friendsEmptyTitle => '還沒有好友';

  @override
  String get friendsEmptyMessage => '用邀請連結加入你的第一位好友。';

  @override
  String get friendsInviteButton => '邀請好友';

  @override
  String get friendsInviteAnotherButton => '再產生一個連結';

  @override
  String get friendsCreateAnotherConfirmTitle => '要再產生一個連結嗎?';

  @override
  String get friendsCreateAnotherConfirmMessage =>
      '上面那個連結還沒有複製。產生新的連結會取代它,而且沒辦法再顯示一次。';

  @override
  String get friendsCreateAnotherConfirmButton => '取代';

  @override
  String get friendsLoadErrorMessage => '無法載入好友清單。';

  @override
  String get friendsSectionFriends => '好友';

  @override
  String get friendsSectionInvites => '未接受的邀請';

  @override
  String get friendsRemoveTooltip => '解除好友';

  @override
  String friendsRemoveConfirmTitle(String name) {
    return '解除與 $name 的好友關係?';
  }

  @override
  String friendsRemoveConfirmMessage(String name) {
    return '解除後你和 $name 將不再是好友。';
  }

  @override
  String get friendsRemoveConfirmButton => '解除';

  @override
  String get friendsRemoveNotFoundMessage => '這段好友關係已經不存在。';

  @override
  String get friendsRemoveFailedMessage => '解除好友失敗,請再試一次。';

  @override
  String get friendsInviteLinkTitle => '你的邀請連結';

  @override
  String get friendsCopyButton => '複製';

  @override
  String get friendsCopiedMessage => '已複製連結';

  @override
  String get friendsCopyFailedMessage => '複製失敗,請直接選取上方的連結手動複製。';

  @override
  String get friendsCreateInviteFailedMessage => '建立邀請連結失敗,請再試一次。';

  @override
  String get friendsCreateInviteRefreshFailedMessage => '邀請連結已建立,但清單沒有更新成功。';

  @override
  String get friendsInviteLinkOnceWarning => '請立刻複製:這個連結只會顯示這一次,離開後就再也拿不到了。';

  @override
  String friendsInviteCreatedLabel(String date) {
    return '$date 建立';
  }

  @override
  String friendsInviteExpiresLabel(String date) {
    return '$date 到期';
  }

  @override
  String get friendsRevokeButton => '撤銷';

  @override
  String get friendsRevokeConfirmTitle => '要撤銷這個邀請嗎?';

  @override
  String get friendsRevokeConfirmMessage => '已經傳出去的連結會立刻失效,拿到連結的人將無法接受邀請。';

  @override
  String get friendsRevokeConfirmButton => '撤銷';

  @override
  String get friendsRevokeNotFoundMessage => '這個邀請已經不存在了。';

  @override
  String get friendsRevokeFailedMessage => '撤銷邀請失敗,請再試一次。';

  @override
  String get inviteTitle => '邀請';

  @override
  String inviteFromMessage(String name) {
    return '$name 邀請你成為好友';
  }

  @override
  String get inviteAcceptButton => '接受';

  @override
  String inviteAlreadyFriendsMessage(String name) {
    return '你和 $name 已經是好友了。';
  }

  @override
  String get inviteBackToFriendsButton => '回到好友列表';

  @override
  String get inviteExpiredMessage => '這個邀請已經過期,請對方重新產生一個連結。';

  @override
  String get inviteAlreadyUsedMessage => '這個邀請已經被使用過了。';

  @override
  String get inviteRevokedMessage => '這個邀請已被撤銷。';

  @override
  String get inviteInvalidMessage => '連結無效,請確認是否複製完整。';

  @override
  String get inviteFetchFailedMessage => '無法載入這個邀請,請檢查網路連線後再試一次。';

  @override
  String get inviteOwnInviteMessage => '這是你自己發出的邀請。';

  @override
  String get settingsFriendsSectionTitle => '好友';

  @override
  String get settingsFriendsRowLabel => '好友';

  @override
  String get financeTabSplit => '分帳';

  @override
  String get splitFabTooltip => '記一筆分帳';

  @override
  String get splitEmptyTitle => '還沒有分帳';

  @override
  String get splitEmptyCta => '記一筆分帳';

  @override
  String get splitLoadFailedMessage => '無法載入分帳資料,請檢查網路連線後再試一次。';

  @override
  String get splitProfileFailedMessage => '無法載入你的個人資料,請再試一次。';

  @override
  String get splitSectionOwedToMe => '別人欠你';

  @override
  String splitOwedToMeRow(String name, String amount) {
    return '$name 欠你 $amount';
  }

  @override
  String get splitSectionOwedByMe => '你欠別人';

  @override
  String splitOwedByMeRow(String name, String amount) {
    return '你欠 $name $amount';
  }

  @override
  String get splitSectionGroups => '群組';

  @override
  String get splitNoGroupsYet => '還沒有群組';

  @override
  String get splitAddGroupButton => '新增群組';

  @override
  String get splitSectionRecentExpenses => '最近的支出';

  @override
  String get splitNoExpensesYet => '還沒有支出';

  @override
  String splitExpensePaidBy(String name, String date) {
    return '$name 付款 · $date';
  }

  @override
  String splitYourShare(String amount) {
    return '你的份額 $amount';
  }

  @override
  String get splitAllSettledUp => '大家都結清了';

  @override
  String get splitYouLabel => '你';

  @override
  String get splitUnknownMember => '某人';

  @override
  String get splitCreateGroupTitle => '新增群組';

  @override
  String get splitGroupNameLabel => '群組名稱';

  @override
  String get splitGroupNameRequired => '請輸入群組名稱';

  @override
  String get splitCreateButton => '建立';

  @override
  String get splitExpenseAddTitle => '記一筆分帳';

  @override
  String get splitExpenseEditTitle => '編輯分帳';

  @override
  String get splitGroupFieldLabel => '群組';

  @override
  String get splitGroupNoneOption => '不選群組(一對一)';

  @override
  String get splitPayerLabel => '付款人';

  @override
  String get splitDescriptionLabel => '說明';

  @override
  String get splitDescriptionRequired => '請輸入說明';

  @override
  String get splitDayLabel => '日期';

  @override
  String get splitParticipantsLabel => '參與者';

  @override
  String get splitSplitModeLabel => '拆法';

  @override
  String get splitModeEqual => '均分';

  @override
  String get splitModeExact => '自訂';

  @override
  String splitEqualShareRow(String name, String amount) {
    return '$name: $amount';
  }

  @override
  String splitExactShareLabel(String name) {
    return '$name 的份額';
  }

  @override
  String splitExactRemaining(String amount) {
    return '還差 $amount';
  }

  @override
  String splitExactOverAssigned(String amount) {
    return '超出 $amount';
  }

  @override
  String get splitExactAssignedInFull => '已分配完畢';

  @override
  String get splitStakeWarning => '你必須是付款人,或持有大於零的份額,才能記這筆分帳。';

  @override
  String get splitAmountTooLarge => '金額過大。';

  @override
  String get splitAmountRequired => '請輸入大於 0 的金額。';

  @override
  String get splitPayerRequired => '請選擇付款人。';

  @override
  String get splitParticipantsRequired => '請至少選一位參與者。';

  @override
  String get splitTooFewPeople => '分帳至少要兩個人——除了付款人之外,再選一位。';

  @override
  String get splitNoFriendsYet => '你還沒有好友——先加一位好友,才能跟人分帳。';

  @override
  String get splitAddFriendAction => '去加好友';

  @override
  String splitAmountBelowParticipants(int count) {
    return '這筆金額太小,無法平均分給 $count 個人。';
  }

  @override
  String get splitExactMustSumToAmount => '各人份額加總必須等於總額。';

  @override
  String splitDeleteConfirmTitle(String description) {
    return '刪除「$description」?';
  }

  @override
  String get splitDeleteConfirmMessage => '這會移除這筆支出與所有人的分擔,且無法復原。';

  @override
  String get splitDeleteConfirmButton => '刪除';

  @override
  String get splitSaveFailedMessage => '儲存失敗,請再試一次。';

  @override
  String get splitErrorNotFriends => '對方還不是你的好友,先加好友再分帳。';

  @override
  String get splitErrorNotAGroupMember => '對方不是這個群組的成員。';

  @override
  String get splitErrorGroupArchived => '這個群組已封存,無法新增支出。';

  @override
  String splitErrorSharesMismatch(String message) {
    return '分擔金額加總不等於總額:$message';
  }

  @override
  String get splitErrorTooSmall => '金額太小,無法分帳。';

  @override
  String get splitErrorDuplicateParticipant => '同一個人不能重複列入。';

  @override
  String get splitErrorAlreadyMember => '對方已經是這個群組的成員。';

  @override
  String get splitErrorNotAParticipant => '你需要持有這筆支出的份額才能這麼做。';

  @override
  String splitErrorInvalidInput(String message) {
    return '這筆分帳無法接受:$message';
  }

  @override
  String splitErrorBadRequest(String message) {
    return '這筆資料被退回:$message';
  }

  @override
  String get splitErrorNotFound => '找不到這筆資料,可能已被刪除。';

  @override
  String get splitErrorCannotSettleWithSelf => '不能記錄跟自己的還款。';

  @override
  String get splitErrorGeneric => '發生錯誤,請再試一次。';

  @override
  String get splitGroupArchivedBadge => '已封存';

  @override
  String get splitGroupMembersTitle => '成員';

  @override
  String get splitGroupBalancesTitle => '分帳淨額(不含還款)';

  @override
  String get splitGroupBalancesNote => '不含還款——雙人結清不會改變這個數字。';

  @override
  String splitGroupBalanceShouldCollect(String name, String amount) {
    return '$name 應收 $amount';
  }

  @override
  String splitGroupBalanceShouldPay(String name, String amount) {
    return '$name 應付 $amount';
  }

  @override
  String get splitGroupExpensesTitle => '支出';

  @override
  String get splitGroupNoExpensesYet => '這個群組還沒有支出';

  @override
  String get splitAddMemberButton => '新增成員';

  @override
  String get splitAddMemberTitle => '從好友加入這個群組';

  @override
  String get splitAddMemberEmpty => '你的好友都已經在這個群組裡了。';

  @override
  String get splitArchiveButton => '封存群組';

  @override
  String splitArchiveConfirmTitle(String groupName) {
    return '封存「$groupName」?';
  }

  @override
  String get splitArchiveConfirmMessage =>
      '群組會變成唯讀:不能再新增支出或成員,但既有支出仍可由建立者或付款人編輯。';

  @override
  String get splitArchiveConfirmButton => '封存';

  @override
  String get splitAddExpenseTooltip => '記一筆分帳';

  @override
  String get splitEditExpenseTooltip => '編輯';

  @override
  String get splitDeleteExpenseTooltip => '刪除';

  @override
  String get splitGroupLoadFailedMessage => '無法載入這個群組,請檢查網路連線後再試一次。';

  @override
  String settleUpTitlePaying(String name) {
    return '還給 $name';
  }

  @override
  String settleUpTitleReceiving(String name) {
    return '$name 還你';
  }

  @override
  String get settleUpConfirmButton => '確認';

  @override
  String get settleUpAmountRequired => '請輸入金額';

  @override
  String get settleUpAmountMustBeWhole => '這個幣別沒有小數,請輸入整數';

  @override
  String get settleUpAmountTooLarge => '金額太大';

  @override
  String settleUpOverpayWarningTheyWillOwe(String name, String amount) {
    return '$name 會變成欠你 $amount';
  }

  @override
  String settleUpOverpayWarningYouWillOwe(String name, String amount) {
    return '你會變成欠 $name $amount';
  }

  @override
  String get splitSectionRecentActivity => '近期動態';

  @override
  String get splitNoActivityYet => '還沒有支出或還款';

  @override
  String get splitSettleUpTooltip => '結清';

  @override
  String splitSettlementRow(String from, String to) {
    return '還款:$from 還給 $to';
  }

  @override
  String get splitDeleteSettlementTooltip => '刪除還款';

  @override
  String get splitDeleteSettlementConfirmTitle => '刪除這筆還款?';

  @override
  String splitDeleteSettlementConfirmMessage(String name, String amount) {
    return '這會刪除與 $name 的 $amount 還款紀錄,無法復原。';
  }

  @override
  String get splitDeleteSettlementConfirmButton => '刪除';

  @override
  String get splitGroupPersonalBalancesTitle => '我與各成員的往來';

  @override
  String get splitGroupPersonalBalancesNote => '涵蓋你們所有的共同紀錄,不只這個群組。';

  @override
  String get splitSectionOverview => 'Summary';

  @override
  String get splitSectionChangeLog => 'Change log';

  @override
  String get splitActivityEmptyTitle => 'No changes yet';

  @override
  String get splitActivityEmptyBody =>
      'When you or someone you split with adds, edits or deletes something, it appears here.';

  @override
  String get splitActivityLoadFailedMessage =>
      'Couldn\'t load the change log. Check your connection and try again.';

  @override
  String get splitActivityLoadMoreFailed => 'Couldn\'t load more entries.';

  @override
  String splitActivityExpenseCreatedYou(String description) {
    return 'You added $description';
  }

  @override
  String splitActivityExpenseCreatedOther(String name, String description) {
    return '$name added $description';
  }

  @override
  String splitActivityExpenseUpdatedYou(String description) {
    return 'You edited $description';
  }

  @override
  String splitActivityExpenseUpdatedOther(String name, String description) {
    return '$name edited $description';
  }

  @override
  String splitActivityExpenseDeletedYou(String description) {
    return 'You deleted $description';
  }

  @override
  String splitActivityExpenseDeletedOther(String name, String description) {
    return '$name deleted $description';
  }

  @override
  String get splitActivitySettlementCreatedYou => 'You recorded a repayment';

  @override
  String splitActivitySettlementCreatedOther(String name) {
    return '$name recorded a repayment';
  }

  @override
  String get splitActivitySettlementDeletedYou => 'You deleted a repayment';

  @override
  String splitActivitySettlementDeletedOther(String name) {
    return '$name deleted a repayment';
  }

  @override
  String splitActivityGroupCreatedYou(String group) {
    return 'You created the group $group';
  }

  @override
  String splitActivityGroupCreatedOther(String name, String group) {
    return '$name created the group $group';
  }

  @override
  String splitActivityGroupMemberAddedYou(String member, String group) {
    return 'You added $member to $group';
  }

  @override
  String splitActivityGroupMemberAddedOther(
    String name,
    String member,
    String group,
  ) {
    return '$name added $member to $group';
  }

  @override
  String splitActivityGroupMemberAddedYouWere(String name, String group) {
    return '$name added you to $group';
  }

  @override
  String splitActivityGroupArchivedYou(String group) {
    return 'You archived the group $group';
  }

  @override
  String splitActivityGroupArchivedOther(String name, String group) {
    return '$name archived the group $group';
  }

  @override
  String splitActivityRepaymentYouPaid(String name) {
    return 'You paid $name';
  }

  @override
  String splitActivityRepaymentPaidYou(String name) {
    return '$name paid you';
  }

  @override
  String splitActivityRepaymentBetween(String payer, String payee) {
    return '$payer paid $payee';
  }

  @override
  String splitActivityAmountChange(String previous, String amount) {
    return '$previous → $amount';
  }

  @override
  String splitActivityAmountChangeSpoken(String previous, String amount) {
    return 'from $previous to $amount';
  }

  @override
  String get splitActivityUnknownYou => 'You changed something';

  @override
  String splitActivityUnknownOther(String name) {
    return '$name changed something';
  }

  @override
  String splitActivityRowDetail(String what, String detail) {
    return '$what: $detail';
  }

  @override
  String splitActivityRowSemantics(String what, String amount, String time) {
    return '$what, $amount, $time';
  }

  @override
  String get splitActivityUnnamedItem => 'an untitled item';

  @override
  String get splitActivityUnnamedGroup => 'an untitled group';

  @override
  String splitActivityRowSemanticsNoAmount(String what, String time) {
    return '$what, $time';
  }
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
  String get trackerStillSaving => '尚在儲存——請稍後再試。';

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
  String get cardRefreshFailed => '沒有更新到';

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
  String get settingsInstallSectionTitle => '安裝應用程式';

  @override
  String get settingsInstallButton => '安裝 LifeOS';

  @override
  String get settingsInstallIosHint => '加到主畫面:分享 → 加入主畫面';

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
  String get dietSnackBaseName => '點心';

  @override
  String get dietSearchFoodHint => '搜尋食物';

  @override
  String get dietQuantityLabel => '份量';

  @override
  String get dietGramsLabel => '公克';

  @override
  String get dietPortionUnit => '份';

  @override
  String dietAddToMealButton(String meal) {
    return '加入$meal';
  }

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
  String get dietBonusNote => '✳️ 運動會加成當日目標份數(主食・肉類)。';

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
  String get dietCalendarPrevMonth => '上個月';

  @override
  String get dietCalendarNextMonth => '下個月';

  @override
  String dietAddToMealA11yLabel(String meal) {
    return '加到$meal';
  }

  @override
  String get dietMealEmptyLabel => '還沒記錄';

  @override
  String get dietAddSnackButton => '加點心';

  @override
  String dietSearchDoneButton(int count) {
    return '完成（$count）';
  }

  @override
  String get dietDictionaryTitle => '食物字典';

  @override
  String get dietOpenDictionaryTooltip => '查詢食物';

  @override
  String get dietChooseMealSheetTitle => '要加到哪一餐？';

  @override
  String get dietRemoveItemTooltip => '移除';

  @override
  String get dietMealTotalLabel => '合計';

  @override
  String get dietSaveMealFailed => '儲存失敗，請再試一次。';

  @override
  String get dietUnnamedItemLabel => '未命名項目';

  @override
  String get dietMeasureUnitMl => '毫升';

  @override
  String get dietManualEntryLink => '找不到？手動輸入';

  @override
  String get dietDictionaryFavoritesEmptyTitle => '還沒有常用食物';

  @override
  String get dietDictionaryFavoritesEmptyBody => '搜尋看看某個食物算幾份，點愛心就能留在這裡。';

  @override
  String dietDictionaryNoResultsTitle(String query) {
    return '找不到「$query」';
  }

  @override
  String get dietDictionaryNoResultsBody => '換個名字再找找看。';

  @override
  String get dietDictionaryLoadFailed => '無法載入食物，請再試一次。';

  @override
  String get dietManualEntryTitle => '手動輸入';

  @override
  String get dietManualEntryNameLabel => '名稱';

  @override
  String get dietManualEntryAddButton => '加入';

  @override
  String get dietDeleteItemTooltip => '刪除';

  @override
  String get dietDeleteMealTooltip => '刪除整餐';

  @override
  String get dietDeleteMealConfirmTitle => '刪除這餐？';

  @override
  String get dietDeleteMealConfirmMessage => '將會移除所有項目。';

  @override
  String get dietDeleteMealConfirmButton => '刪除';

  @override
  String get dietChangeTimeTooltip => '改時間';

  @override
  String get errorDietItemNotFound => '找不到這筆紀錄。';

  @override
  String get dietSaveEditButton => '儲存';

  @override
  String get dietTabWater => '飲水';

  @override
  String get waterTitle => '今日飲水';

  @override
  String get waterHistoryTitle => '飲水紀錄';

  @override
  String waterTotalOfTarget(int total, int target) {
    return '$total / $target ml';
  }

  @override
  String get waterAdd250 => '＋250 ml';

  @override
  String get waterAdd500 => '＋500 ml';

  @override
  String get waterCustomAmount => '自訂';

  @override
  String get waterCorrect250 => '−250 ml';

  @override
  String get waterSetTargetButton => '設定目標';

  @override
  String get waterCustomAmountTitle => '新增飲水量(ml)';

  @override
  String get waterSetTargetTitle => '每日飲水目標(ml)';

  @override
  String get errorWaterLoadFailed => '無法載入飲水資料,請再試一次。';

  @override
  String get waterSaveFailed => '儲存失敗,請再試一次';

  @override
  String get waterGoalMet => '達標';

  @override
  String get dietTabBowel => '排便';

  @override
  String get bowelTitle => '今日排便';

  @override
  String get bowelHistoryTitle => '排便紀錄';

  @override
  String get bowelCountLabel => '次數';

  @override
  String get bowelNormalityLabel => '是否正常';

  @override
  String get bowelNormalLabel => '正常';

  @override
  String get bowelAbnormalLabel => '異常';

  @override
  String get bowelNoteLabel => '備註';

  @override
  String get bowelSaveButton => '儲存';

  @override
  String get bowelUnsavedChanges => '尚未儲存';

  @override
  String get bowelSaveFailed => '儲存失敗,請再試一次';

  @override
  String get errorBowelLoadFailed => '無法載入排便資料,請再試一次。';

  @override
  String get dietTabVitals => '數值';

  @override
  String get vitalsTitle => '今日數值';

  @override
  String get vitalsHistoryTitle => '數值紀錄';

  @override
  String get vitalsWeightLabel => '體重(公斤)';

  @override
  String get vitalsBodyFatLabel => '體脂(%)';

  @override
  String get vitalsBloodPressureSection => '血壓 (mmHg)';

  @override
  String get vitalsGlucoseSection => '血糖';

  @override
  String get vitalsSpo2Section => '血氧';

  @override
  String get vitalsSystolicLabel => '收縮壓';

  @override
  String get vitalsDiastolicLabel => '舒張壓';

  @override
  String get vitalsPulseLabel => '脈搏';

  @override
  String get vitalsPulseUnit => 'bpm';

  @override
  String get vitalsGlucoseLabelField => '標籤';

  @override
  String get vitalsGlucoseValueLabel => 'mg/dL';

  @override
  String get vitalsSpo2Label => '血氧 (%)';

  @override
  String get vitalsAddReading => '加一筆';

  @override
  String get vitalsRemoveReading => '移除';

  @override
  String get vitalsSaveButton => '儲存';

  @override
  String get vitalsTimeLabel => '時間';

  @override
  String get vitalsUnsavedChanges => '尚未儲存';

  @override
  String get vitalsSaveFailed => '儲存失敗,請再試一次';

  @override
  String get errorVitalsLoadFailed => '無法載入數值資料,請再試一次。';

  @override
  String get dietTabMore => '更多';

  @override
  String get dietTabExercise => '運動';

  @override
  String get exerciseTitle => '今日運動';

  @override
  String get exerciseHistoryTitle => '運動記錄';

  @override
  String exerciseTotalMinutes(int minutes) {
    return '共 $minutes 分鐘';
  }

  @override
  String exerciseEntryDuration(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get exerciseEmptyLabel => '尚未記錄運動';

  @override
  String get exerciseAddButton => '記錄運動';

  @override
  String get exerciseAddDialogTitle => '記錄運動';

  @override
  String get exerciseActivityLabel => '項目';

  @override
  String get exerciseDurationLabel => '分鐘';

  @override
  String get exerciseNoteLabel => '備註';

  @override
  String get exerciseCategoryAerobic => '有氧';

  @override
  String get exerciseCategoryAnaerobic => '無氧';

  @override
  String get exerciseAddConfirmButton => '新增';

  @override
  String get exerciseRemoveEntry => '移除';

  @override
  String get exerciseSaveFailed => '儲存失敗,請再試一次';

  @override
  String get exerciseEntryRemoved => '已移除運動紀錄';

  @override
  String get exerciseUndo => '復原';

  @override
  String get errorExerciseLoadFailed => '無法載入運動資料,請再試一次。';

  @override
  String get menstrualTitle => '生理期';

  @override
  String get menstrualAverageCycleLabel => '平均週期';

  @override
  String get menstrualAveragePeriodLabel => '平均經期';

  @override
  String get menstrualPredictedNextLabel => '預測下次';

  @override
  String menstrualDaysValue(int days) {
    return '$days 天';
  }

  @override
  String get menstrualStatPlaceholder => '—';

  @override
  String get menstrualLastPeriodLabel => '最近一次週期';

  @override
  String get menstrualOngoingLabel => '進行中';

  @override
  String get menstrualAddButton => '新增週期';

  @override
  String get menstrualAddDialogTitle => '新增週期';

  @override
  String get menstrualEditDialogTitle => '編輯週期';

  @override
  String get menstrualStartDateLabel => '開始日期';

  @override
  String get menstrualEndDateLabel => '結束日期';

  @override
  String get menstrualSelectDate => '選擇';

  @override
  String get menstrualClearEndDate => '清除結束日期';

  @override
  String get menstrualEndBeforeStartError => '結束日期不能早於開始日期。';

  @override
  String get menstrualSavePeriod => '儲存';

  @override
  String get menstrualDeletePeriod => '刪除';

  @override
  String get menstrualPeriodDeleted => '已刪除週期';

  @override
  String get menstrualUndo => '復原';

  @override
  String get menstrualSaveFailed => '儲存失敗,請再試一次';

  @override
  String get menstrualPrevMonth => '上個月';

  @override
  String get menstrualNextMonth => '下個月';

  @override
  String menstrualDaySemanticPeriod(String date) {
    return '$date,經期';
  }

  @override
  String menstrualDaySemanticPredicted(String date) {
    return '$date,預測下次';
  }

  @override
  String menstrualDaySemanticToday(String date) {
    return '$date,今天';
  }

  @override
  String get menstrualLegendPeriod => '經期';

  @override
  String get menstrualLegendPredicted => '預測下次';

  @override
  String get menstrualEmptyHint => '還沒有生理期紀錄,點日曆上的日期或「新增週期」開始記錄。';

  @override
  String get nextPeriodTitle => '下次生理期';

  @override
  String nextPeriodUpcoming(String date, int days) {
    return '$date・還有 $days 天';
  }

  @override
  String get nextPeriodToday => '預計今天';

  @override
  String nextPeriodOverdue(String date, int days) {
    return '預計 $date・已過 $days 天還沒有紀錄';
  }

  @override
  String nextPeriodOngoing(int day) {
    return '進行中・第 $day 天';
  }

  @override
  String nextPeriodOngoingNext(String date) {
    return '下次預計 $date';
  }

  @override
  String get nextPeriodNoRecords => '還沒有生理期紀錄';

  @override
  String get nextPeriodNeedsOneMore => '再記錄一次就能預測下次';

  @override
  String get errorMenstrualLoadFailed => '無法載入生理期資料,請再試一次。';

  @override
  String get errorCareTodayLoadFailed => '無法載入今日照護,請再試一次。';

  @override
  String get updateAvailableTitle => '有新版本可用';

  @override
  String get updateButton => '更新';

  @override
  String get updateDismiss => '關閉';

  @override
  String get dashboardTitle => '總覽';

  @override
  String get healthTabRecord => '記錄';

  @override
  String get healthRecordDiet => '飲食';

  @override
  String get healthCalendarTitle => '本月記錄';

  @override
  String get healthCalendarLoggingRate => '記錄率';

  @override
  String get healthCalendarDietRate => '飲食達標';

  @override
  String get healthCalendarWeightRate => '體重達成';

  @override
  String get healthCalendarLoggedLegend => '有記錄';

  @override
  String get healthCalendarNoData => '無資料';

  @override
  String get healthCalendarLoadFailed => '無法載入本月記錄,請再試一次。';

  @override
  String get goalCardTitle => '體重目標';

  @override
  String get goalTargetLabel => '目標';

  @override
  String get goalCurrentLabel => '目前';

  @override
  String get goalRemainingLabel => '剩餘';

  @override
  String get goalKgUnit => '公斤';

  @override
  String get goalCmUnit => '公分';

  @override
  String get goalHeightShortLabel => '身高';

  @override
  String get goalAchievementLabel => '達成率';

  @override
  String get goalAchievementHint => '再記一天體重即可顯示進度。';

  @override
  String get goalBmiLabel => 'BMI';

  @override
  String get goalPlaceholder => '—';

  @override
  String get goalNoData => '無資料';

  @override
  String get goalUnsetPrompt => '設定身高與目標體重,開始追蹤你的目標。';

  @override
  String get goalSetButton => '設定你的目標';

  @override
  String get goalEditTitle => '設定你的目標';

  @override
  String get goalHeightLabel => '身高(公分)';

  @override
  String get goalTargetWeightLabel => '目標體重(公斤)';

  @override
  String get goalSaveButton => '儲存';

  @override
  String get errorWeightGoalLoadFailed => '無法載入目標資料,請再試一次。';

  @override
  String get trendCardTitle => '趨勢';

  @override
  String get trendMetricWeight => '體重';

  @override
  String get trendMetricBodyFat => '體脂';

  @override
  String get trendMetricSystolic => '收縮壓';

  @override
  String get trendMetricDiastolic => '舒張壓';

  @override
  String get trendMetricPulse => '心跳';

  @override
  String get trendMetricGlucose => '血糖';

  @override
  String get trendMetricSpo2 => '血氧';

  @override
  String get trendMetricBloodPressurePulse => '血壓・心跳';

  @override
  String get glucoseContextFasting => '空腹';

  @override
  String get glucoseContextPreMeal => '餐前';

  @override
  String get glucoseContextPostMeal => '餐後';

  @override
  String get glucoseContextUnspecified => '未分類';

  @override
  String get trendRange7 => '7 天';

  @override
  String get trendRange30 => '30 天';

  @override
  String get trendRange90 => '90 天';

  @override
  String get trendEmpty => '尚無資料';

  @override
  String get trendNormalRangeLabel => '正常範圍';

  @override
  String get trendLoadFailed => '無法載入趨勢資料,請再試一次。';

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

    return '$metric趨勢,近 $days 天,最新 $valueString $unit';
  }

  @override
  String trendChartSemanticsEmpty(String metric, int days) {
    return '$metric趨勢,近 $days 天,無資料';
  }

  @override
  String trendChartSemanticsMulti(String metric, int days) {
    return '$metric趨勢,近 $days 天';
  }

  @override
  String get importTitle => '從 chaodays 匯入';

  @override
  String get importAccountLabel => 'chaodays 帳號';

  @override
  String get importPasswordLabel => 'chaodays 密碼';

  @override
  String get importStartDateLabel => '起始日期';

  @override
  String get importEndDateLabel => '結束日期';

  @override
  String get importSelectDateLabel => '選擇';

  @override
  String get importSubmitButton => '開始匯入';

  @override
  String get importDoneMessage => '匯入完成';

  @override
  String get importCredentialsNote => '帳密僅用於這次匯入,不會儲存。';

  @override
  String get importTypesTitle => '匯入項目';

  @override
  String get importTypeWeight => '體重體脂';

  @override
  String get importTypeDiet => '飲食血糖';

  @override
  String get importTypeWater => '飲水';

  @override
  String get importTypeBowel => '排便';

  @override
  String get importTypeDietTarget => '飲食目標';

  @override
  String get importTypeMenstrual => '生理期';

  @override
  String get importMenstrualOpenPeriodHint => '進行中的週期會跳過，等它結束後再匯入一次';

  @override
  String importResultSummary(int imported, int skipped) {
    return '匯入 $imported・跳過 $skipped';
  }

  @override
  String importResultGlucoseSuffix(int count) {
    return '・血糖 $count';
  }

  @override
  String importResultWaterTargetSuffix(int count) {
    return '・飲水目標 $count';
  }

  @override
  String get importTypeFailed => '失敗';

  @override
  String get importStatusImporting => '正在匯入';

  @override
  String get importStatusSuccess => '匯入成功';

  @override
  String get importStatusFailed => '匯入失敗';

  @override
  String get importStatusNotAttempted => '未匯入';

  @override
  String get importErrorAuthFailed => 'chaodays 帳號或密碼錯誤,請確認後再試一次。';

  @override
  String get importErrorUnavailable => 'chaodays 暫時無法連線,請稍後再試。';

  @override
  String get reminderTitle => '提醒通知';

  @override
  String get reminderStatusUnsupported => '此瀏覽器或裝置不支援通知功能。';

  @override
  String get reminderStatusIosNeedsInstall =>
      '在 iOS 上要接收通知,請在 Safari 點選分享圖示,選擇「加入主畫面」,然後從主畫面開啟 LifeOS 並回到這裡。';

  @override
  String get reminderStatusPermissionDenied => '此網站的通知已被封鎖,請至瀏覽器設定開啟後再回來。';

  @override
  String get reminderEnabledStatus => '此裝置已開啟通知。';

  @override
  String get reminderErrorGeneric => '開啟通知時發生錯誤,請再試一次。';

  @override
  String get reminderEnableButton => '開啟通知';

  @override
  String get reminderTestButton => '測試推播';

  @override
  String reminderTestResult(int sent, int failed) {
    return '已送出 $sent・失敗 $failed';
  }

  @override
  String get reminderTestErrorGeneric => '測試推播失敗,請再試一次。';

  @override
  String get reminderTestSent => '測試推播已送出,請查看你的裝置通知。';

  @override
  String get reminderTestNoDevice => '目前沒有已啟用的裝置收到,請再開啟一次通知。';

  @override
  String get reminderRecheck => '重新檢查';

  @override
  String get reminderStillBlocked => '通知仍被封鎖,請到瀏覽器設定開啟後再重新檢查。';

  @override
  String get careRemindersTitle => '照護管理';

  @override
  String get careRemindersEmptyTitle => '還沒有任何提醒';

  @override
  String get careRemindersEmptyBody => '新增一筆提醒,涵蓋用藥、復健、放療保養或自訂項目。';

  @override
  String get careRemindersAddButton => '新增提醒';

  @override
  String get careCategoryMedication => '用藥';

  @override
  String get careCategoryRehab => '復健';

  @override
  String get careCategoryRadiotherapyCare => '放療保養';

  @override
  String get careCategoryCustom => '自訂';

  @override
  String get careEveryDay => '每天';

  @override
  String careWeekIntervalSuffix(int n) {
    return '· 每 $n 週';
  }

  @override
  String careScheduleUntil(String date) {
    return '至 $date';
  }

  @override
  String careScheduleFrom(String date) {
    return '$date 起';
  }

  @override
  String careStockLabel(String n) {
    return '庫存:$n';
  }

  @override
  String get careDeleteConfirmTitle => '刪除這筆提醒?';

  @override
  String get careDeleteConfirmMessage => '刪除後將不再提醒。';

  @override
  String get careDeleteConfirmButton => '刪除';

  @override
  String get careCancelButton => '取消';

  @override
  String get careErrorGeneric => '發生問題,請再試一次。';

  @override
  String get careFormTitleAdd => '新增照護提醒';

  @override
  String get careFormTitleEdit => '編輯照護提醒';

  @override
  String get careCategoryLabel => '分類';

  @override
  String get careTitleField => '標題';

  @override
  String get careNoteField => '備註';

  @override
  String get careDoseField => '劑量說明';

  @override
  String get careStockField => '庫存數量';

  @override
  String get careStockAlertField => '低庫存提醒門檻';

  @override
  String get careSchedulesLabel => '排程';

  @override
  String get careAddScheduleButton => '新增排程';

  @override
  String get careRemoveScheduleTooltip => '移除排程';

  @override
  String get careChangeTimeTooltip => '變更時間';

  @override
  String get careTimeLabel => '時間';

  @override
  String get careWeekdaysLabel => '重複星期';

  @override
  String get careWeekdaysEmptyHint => '全部不選 = 每天。';

  @override
  String careWeekIntervalValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '每 $n 週',
      one: '每週',
    );
    return '$_temp0';
  }

  @override
  String get careStartDateLabel => '起始日';

  @override
  String get careEndDateLabel => '結束日';

  @override
  String get careAddEndDateButton => '新增結束日';

  @override
  String get careRemoveEndDateTooltip => '移除結束日';

  @override
  String get careDoseQuantityLabel => '每次劑量';

  @override
  String get careNagIntervalLabel => '提醒重複頻率';

  @override
  String get careNagOnceLabel => '只提醒一次';

  @override
  String careNagEveryNMinutes(int n) {
    return '每 $n 分鐘';
  }

  @override
  String get careIncompleteHint => '請輸入標題並新增至少一筆排程,才能儲存。';

  @override
  String get careSaveButton => '儲存';

  @override
  String get weekdayShortSun => '週日';

  @override
  String get weekdayShortMon => '週一';

  @override
  String get weekdayShortTue => '週二';

  @override
  String get weekdayShortWed => '週三';

  @override
  String get weekdayShortThu => '週四';

  @override
  String get weekdayShortFri => '週五';

  @override
  String get weekdayShortSat => '週六';

  @override
  String get careTodayTitle => '今日照護';

  @override
  String get careTodayOverdueSection => '逾期';

  @override
  String get careTodayLaterSection => '稍後';

  @override
  String careTodayDoneSection(int n) {
    return '已完成（$n）';
  }

  @override
  String get careTodayMarkDoneButton => '完成';

  @override
  String get careTodaySkipButton => '略過';

  @override
  String careTodayDoneAtLabel(String time) {
    return '$time 完成';
  }

  @override
  String get careTodayEmptyTitle => '今天沒有排程';

  @override
  String get careTodayEmptyBody => '新增照護提醒後就會顯示在這裡。';

  @override
  String get careTodayCelebrationTitle => '今天的照護都完成了！';

  @override
  String get careTodayCelebrationBody => '做得好，明天見。';

  @override
  String get careTodayUpNext => '接下來';

  @override
  String get careTodayStatusSkipped => '略過';

  @override
  String get careTodayStatusMissed => '未完成';

  @override
  String get careTodayEditSheetTitle => '更新這筆紀錄';

  @override
  String get careTodayEditTimeLabel => '完成時間';

  @override
  String get careTodayEditSubmitButton => '儲存';

  @override
  String careTodaySummaryProgress(int done, int total) {
    return '$done/$total 完成';
  }

  @override
  String careTodaySummaryMoreCount(int n) {
    return '還有 $n 項';
  }

  @override
  String get careTodaySummarySeeAll => '查看全部';

  @override
  String get careTodaySummaryManage => '管理';

  @override
  String get careTodaySummarySetupTitle => '還沒有照護提醒';

  @override
  String get careTodaySummarySetupCta => '設定';

  @override
  String get careRemindersPushOffBanner => '通知還沒開啟，提醒不會送達';

  @override
  String get careRemindersPushOffAction => '開啟通知';

  @override
  String get careRemindersPushDeniedBanner => '通知已被封鎖，提醒不會送達';

  @override
  String get careHistoryTitle => '照護紀錄';

  @override
  String get careHistoryEntryTooltip => '紀錄';

  @override
  String get careHistoryEmptyTitle => '沒有照護紀錄';

  @override
  String get careHistoryEmptyBody => '這段期間沒有排程。';

  @override
  String get careHistoryWidenPeriodButton => '看更長期間';

  @override
  String get careHistoryEmptyManageButton => '前往照護管理';

  @override
  String get careHistoryAdherenceRateLabel => '達成率';

  @override
  String get careHistoryDaysWithDoseLabel => '有完成的天數';

  @override
  String get careHistoryMissedCountLabel => '未完成次數';

  @override
  String get careHistoryLegendFull => '完成';

  @override
  String get careHistoryLegendPartial => '部分';

  @override
  String get careHistoryLegendMissed => '未完成';

  @override
  String get careHistoryLegendNoSchedule => '無排程';

  @override
  String get careHistoryEditSheetTitle => '更新這筆紀錄';

  @override
  String get careHistoryStatusDone => '已完成';

  @override
  String get careHistoryStatusPending => '待完成';

  @override
  String get careHistoryStatusOverdue => '逾期';

  @override
  String get careHistoryLegendUpcoming => '尚未到期';

  @override
  String get careHistoryEditSuccessMessage => '已儲存。';

  @override
  String get careHistoryEditRefreshErrorMessage => '已儲存，但更新清單失敗。';

  @override
  String get careHistoryPastReadOnlyHint => '這裡只有今天可以修改。';

  @override
  String get careAdherenceCardTitle => '照護達成';

  @override
  String careAdherenceHeatmapCellLabel(String date, String state) {
    return '$date · $state';
  }

  @override
  String get careAdherenceOpenHistory => '查看紀錄';

  @override
  String careAdherenceLegendWithCount(String label, int count) {
    return '$label（$count）';
  }

  @override
  String careAdherenceHeatmapRangeCaption(String from, String to) {
    return '$from – $to';
  }

  @override
  String careAdherenceHeatmapSummaryLabel(String details) {
    return '各狀態天數：$details';
  }

  @override
  String get careAdherenceHeatmapSummarySeparator => '、';

  @override
  String get careEditActionLabel => '編輯';

  @override
  String careErrorForPeriod(int days) {
    return '無法載入過去 $days 天的資料，請再試一次。';
  }

  @override
  String get careHistoryEditNotAppliedMessage => '未套用，沒有任何變更，請再試一次。';

  @override
  String get careHistoryNoCareItemsTitle => '還沒有任何照護項目';

  @override
  String get careHistoryNoCareItemsBody => '你還沒有設定任何照護項目，新增一個開始追蹤吧。';

  @override
  String lastUpdatedAt(String time) {
    return '上次更新 $time';
  }

  @override
  String get refreshDiscardTitle => '要捨棄未儲存的變更嗎？';

  @override
  String get refreshDiscardMessage => '重新整理會捨棄你尚未儲存的變更。';

  @override
  String get discard => '捨棄';

  @override
  String get cancel => '取消';

  @override
  String get sharedFoodItemCreateTitle => '新增共用品項';

  @override
  String get sharedFoodItemEditTitle => '編輯共用品項';

  @override
  String get sharedFoodItemNameLabel => '名稱';

  @override
  String get sharedFoodItemCarbLabel => '碳水化合物 (g)';

  @override
  String get sharedFoodItemProteinLabel => '蛋白質 (g)';

  @override
  String get sharedFoodItemFatLabel => '脂肪 (g)';

  @override
  String get sharedFoodItemSugarLabel => '糖 (g)';

  @override
  String get sharedFoodItemFiberLabel => '纖維 (g)';

  @override
  String get sharedFoodItemKcalLabel => '熱量 (kcal)';

  @override
  String get sharedFoodItemMeasureAmountLabel => '量基準數量';

  @override
  String get sharedFoodItemMeasureUnitLabel => '量基準單位';

  @override
  String get sharedFoodItemSubmitButton => '儲存';

  @override
  String get sharedFoodItemMeasurePairError => '數量與單位要一起填,或一起留空。';

  @override
  String get sharedFoodItemMeasureAmountPositiveError => '數量必須大於零。';

  @override
  String sharedFoodItemNumberFieldError(String field) {
    return '$field必須是零或正數。';
  }

  @override
  String get sharedFoodItemNameRequiredError => '名稱為必填。';

  @override
  String get sharedFoodItemCreateSuccess => '已建立共用品項。';

  @override
  String get sharedFoodItemEditSuccess => '已更新共用品項。';

  @override
  String get sharedFoodItemForbiddenError => '你沒有權限執行此操作。';

  @override
  String get sharedFoodItemSaveFailed => '儲存失敗,請再試一次。';

  @override
  String get sharedFoodItemNeedsReauthError => '請重新登入以儲存。';

  @override
  String get createSharedItemTooltip => '新增共用品項';

  @override
  String get editSharedItemTooltip => '編輯共用品項';

  @override
  String get editSharedItemMenuLabel => '編輯';

  @override
  String get sharedFoodItemPortionsHeading => '份量';

  @override
  String get sharedFoodItemNutrientsHeading => '營養素';

  @override
  String get financeTabOverview => '總覽';

  @override
  String get financeTabTransactions => '明細';

  @override
  String get financeFabTooltip => '記一筆';

  @override
  String get financeAddTitle => '記一筆';

  @override
  String get financeEditTitle => '編輯交易';

  @override
  String get financeAmountLabel => '金額';

  @override
  String get financeTypeExpense => '支出';

  @override
  String get financeTypeIncome => '收入';

  @override
  String get financeCategoryLabel => '分類';

  @override
  String get financeDateLabel => '日期';

  @override
  String get financeCurrencyLabel => '幣別';

  @override
  String get financeNoteLabel => '備註';

  @override
  String get financeSaveButton => '儲存';

  @override
  String get financeDeleteButton => '刪除';

  @override
  String get financeDeleteConfirmTitle => '刪除這筆交易?';

  @override
  String get financeDeleteConfirmMessage => '此動作無法復原。';

  @override
  String get financeDeleteConfirmButton => '刪除';

  @override
  String get financeCancelButton => '取消';

  @override
  String get financeSaveFailed => '儲存失敗,請檢查網路後重試。';

  @override
  String get financeLoadFailed => '財務資料載入失敗。';

  @override
  String get financeEmptyTitle => '這個月還沒有紀錄';

  @override
  String get financeEmptyCta => '記第一筆';

  @override
  String get financeExpenseTotal => '支出';

  @override
  String get financeIncomeTotal => '收入';

  @override
  String get financeNetTotal => '結餘';

  @override
  String get financeRecentTransactions => '最近交易';

  @override
  String get financeSplitSpendingTitle => '你的分帳自付額';

  @override
  String get financeSplitSpendingNote => '不計入上方的支出總額,也不計入預算。';

  @override
  String get financeSplitSpendingLoadFailed => '分帳自付額載入失敗';

  @override
  String get financeCategoryBreakdown => '分類統計';

  @override
  String get financeBudgetCardTitle => '預算';

  @override
  String get financeBudgetOverallLabel => '總額';

  @override
  String get financeBudgetEmptyTitle => '尚未設定預算';

  @override
  String get financeBudgetEmptyCta => '設定預算';

  @override
  String get financeBudgetOverLabel => '已超支';

  @override
  String get financeBudgetSheetTitle => '預算設定';

  @override
  String get financeBudgetSheetHint => '預算為每月循環設定,修改即套用到所有月份。';

  @override
  String get financeBudgetArchivedLabel => '已封存,僅能清空';

  @override
  String get financeBudgetClearButton => '清空';

  @override
  String get financeBudgetClearedLabel => '將被清空';

  @override
  String get financeBudgetInvalidAmount => '請輸入有效金額';

  @override
  String get financeTabNetWorth => '淨值';

  @override
  String get networthNetWorthLabel => '淨值';

  @override
  String get networthGrowthUp => '上升';

  @override
  String get networthGrowthDown => '下降';

  @override
  String get networthGrowthFlat => '持平';

  @override
  String get networthArchivedSubtotal => '已封存科目';

  @override
  String get networthAssetsTitle => '資產';

  @override
  String get networthLiabilitiesTitle => '負債';

  @override
  String get networthTotalAssets => '資產合計';

  @override
  String get networthTotalLiabilities => '負債合計';

  @override
  String get networthTrendTitle => '淨值趨勢';

  @override
  String get networthTrendInsufficient => '資料不足,持續記錄以看趨勢。';

  @override
  String get networthTrendSummary => '近幾個月的淨值趨勢。';

  @override
  String get networthEmptyTitle => '本月尚未記錄任何市值';

  @override
  String get networthEmptyCta => '記錄第一筆';

  @override
  String get networthManageAccounts => '管理科目';

  @override
  String get networthAddAccount => '新增科目';

  @override
  String get networthAccountNameLabel => '科目名稱';

  @override
  String get networthKindAsset => '資產';

  @override
  String get networthKindLiability => '負債';

  @override
  String get networthArchiveButton => '封存';

  @override
  String get networthRestoreButton => '復原';

  @override
  String get networthArchivedLabel => '已封存';

  @override
  String get networthMoveUpTooltip => '上移';

  @override
  String get networthValueLabel => '市值 (TWD)';

  @override
  String get networthNotRecorded => '未記錄';

  @override
  String get networthInvalidValue => '請輸入 0 或以上的整數';

  @override
  String get networthSnapshotSheetTitle => '更新市值';

  @override
  String get networthAccountNameRequired => '請輸入科目名稱';

  @override
  String get networthSaveNameTooltip => '儲存名稱';

  @override
  String get monthNavPreviousTooltip => '上個月';

  @override
  String get monthNavNextTooltip => '下個月';

  @override
  String get monthPickerTitle => '選擇月份';

  @override
  String get monthPickerPreviousYearTooltip => '上一年';

  @override
  String get monthPickerNextYearTooltip => '下一年';

  @override
  String get monthPickerYearTooltip => '選擇年份';

  @override
  String get monthPickerOpenTooltip => '選擇月份';

  @override
  String get friendsTitle => '好友';

  @override
  String get friendsEmptyTitle => '還沒有好友';

  @override
  String get friendsEmptyMessage => '用邀請連結加入你的第一位好友。';

  @override
  String get friendsInviteButton => '邀請好友';

  @override
  String get friendsInviteAnotherButton => '再產生一個連結';

  @override
  String get friendsCreateAnotherConfirmTitle => '要再產生一個連結嗎?';

  @override
  String get friendsCreateAnotherConfirmMessage =>
      '上面那個連結還沒有複製。產生新的連結會取代它,而且沒辦法再顯示一次。';

  @override
  String get friendsCreateAnotherConfirmButton => '取代';

  @override
  String get friendsLoadErrorMessage => '無法載入好友清單。';

  @override
  String get friendsSectionFriends => '好友';

  @override
  String get friendsSectionInvites => '未接受的邀請';

  @override
  String get friendsRemoveTooltip => '解除好友';

  @override
  String friendsRemoveConfirmTitle(String name) {
    return '解除與 $name 的好友關係?';
  }

  @override
  String friendsRemoveConfirmMessage(String name) {
    return '解除後你和 $name 將不再是好友。';
  }

  @override
  String get friendsRemoveConfirmButton => '解除';

  @override
  String get friendsRemoveNotFoundMessage => '這段好友關係已經不存在。';

  @override
  String get friendsRemoveFailedMessage => '解除好友失敗,請再試一次。';

  @override
  String get friendsInviteLinkTitle => '你的邀請連結';

  @override
  String get friendsCopyButton => '複製';

  @override
  String get friendsCopiedMessage => '已複製連結';

  @override
  String get friendsCopyFailedMessage => '複製失敗,請直接選取上方的連結手動複製。';

  @override
  String get friendsCreateInviteFailedMessage => '建立邀請連結失敗,請再試一次。';

  @override
  String get friendsCreateInviteRefreshFailedMessage => '邀請連結已建立,但清單沒有更新成功。';

  @override
  String get friendsInviteLinkOnceWarning => '請立刻複製:這個連結只會顯示這一次,離開後就再也拿不到了。';

  @override
  String friendsInviteCreatedLabel(String date) {
    return '$date 建立';
  }

  @override
  String friendsInviteExpiresLabel(String date) {
    return '$date 到期';
  }

  @override
  String get friendsRevokeButton => '撤銷';

  @override
  String get friendsRevokeConfirmTitle => '要撤銷這個邀請嗎?';

  @override
  String get friendsRevokeConfirmMessage => '已經傳出去的連結會立刻失效,拿到連結的人將無法接受邀請。';

  @override
  String get friendsRevokeConfirmButton => '撤銷';

  @override
  String get friendsRevokeNotFoundMessage => '這個邀請已經不存在了。';

  @override
  String get friendsRevokeFailedMessage => '撤銷邀請失敗,請再試一次。';

  @override
  String get inviteTitle => '邀請';

  @override
  String inviteFromMessage(String name) {
    return '$name 邀請你成為好友';
  }

  @override
  String get inviteAcceptButton => '接受';

  @override
  String inviteAlreadyFriendsMessage(String name) {
    return '你和 $name 已經是好友了。';
  }

  @override
  String get inviteBackToFriendsButton => '回到好友列表';

  @override
  String get inviteExpiredMessage => '這個邀請已經過期,請對方重新產生一個連結。';

  @override
  String get inviteAlreadyUsedMessage => '這個邀請已經被使用過了。';

  @override
  String get inviteRevokedMessage => '這個邀請已被撤銷。';

  @override
  String get inviteInvalidMessage => '連結無效,請確認是否複製完整。';

  @override
  String get inviteFetchFailedMessage => '無法載入這個邀請,請檢查網路連線後再試一次。';

  @override
  String get inviteOwnInviteMessage => '這是你自己發出的邀請。';

  @override
  String get settingsFriendsSectionTitle => '好友';

  @override
  String get settingsFriendsRowLabel => '好友';

  @override
  String get financeTabSplit => '分帳';

  @override
  String get splitFabTooltip => '記一筆分帳';

  @override
  String get splitEmptyTitle => '還沒有分帳';

  @override
  String get splitEmptyCta => '記一筆分帳';

  @override
  String get splitLoadFailedMessage => '無法載入分帳資料,請檢查網路連線後再試一次。';

  @override
  String get splitProfileFailedMessage => '無法載入你的個人資料,請再試一次。';

  @override
  String get splitSectionOwedToMe => '別人欠你';

  @override
  String splitOwedToMeRow(String name, String amount) {
    return '$name 欠你 $amount';
  }

  @override
  String get splitSectionOwedByMe => '你欠別人';

  @override
  String splitOwedByMeRow(String name, String amount) {
    return '你欠 $name $amount';
  }

  @override
  String get splitSectionGroups => '群組';

  @override
  String get splitNoGroupsYet => '還沒有群組';

  @override
  String get splitAddGroupButton => '新增群組';

  @override
  String get splitSectionRecentExpenses => '最近的支出';

  @override
  String get splitNoExpensesYet => '還沒有支出';

  @override
  String splitExpensePaidBy(String name, String date) {
    return '$name 付款 · $date';
  }

  @override
  String splitYourShare(String amount) {
    return '你的份額 $amount';
  }

  @override
  String get splitAllSettledUp => '大家都結清了';

  @override
  String get splitYouLabel => '你';

  @override
  String get splitUnknownMember => '某人';

  @override
  String get splitCreateGroupTitle => '新增群組';

  @override
  String get splitGroupNameLabel => '群組名稱';

  @override
  String get splitGroupNameRequired => '請輸入群組名稱';

  @override
  String get splitCreateButton => '建立';

  @override
  String get splitExpenseAddTitle => '記一筆分帳';

  @override
  String get splitExpenseEditTitle => '編輯分帳';

  @override
  String get splitGroupFieldLabel => '群組';

  @override
  String get splitGroupNoneOption => '不選群組(一對一)';

  @override
  String get splitPayerLabel => '付款人';

  @override
  String get splitDescriptionLabel => '說明';

  @override
  String get splitDescriptionRequired => '請輸入說明';

  @override
  String get splitDayLabel => '日期';

  @override
  String get splitParticipantsLabel => '參與者';

  @override
  String get splitSplitModeLabel => '拆法';

  @override
  String get splitModeEqual => '均分';

  @override
  String get splitModeExact => '自訂';

  @override
  String splitEqualShareRow(String name, String amount) {
    return '$name: $amount';
  }

  @override
  String splitExactShareLabel(String name) {
    return '$name 的份額';
  }

  @override
  String splitExactRemaining(String amount) {
    return '還差 $amount';
  }

  @override
  String splitExactOverAssigned(String amount) {
    return '超出 $amount';
  }

  @override
  String get splitExactAssignedInFull => '已分配完畢';

  @override
  String get splitStakeWarning => '你必須是付款人,或持有大於零的份額,才能記這筆分帳。';

  @override
  String get splitAmountTooLarge => '金額過大。';

  @override
  String get splitAmountRequired => '請輸入大於 0 的金額。';

  @override
  String get splitPayerRequired => '請選擇付款人。';

  @override
  String get splitParticipantsRequired => '請至少選一位參與者。';

  @override
  String get splitTooFewPeople => '分帳至少要兩個人——除了付款人之外,再選一位。';

  @override
  String get splitNoFriendsYet => '你還沒有好友——先加一位好友,才能跟人分帳。';

  @override
  String get splitAddFriendAction => '去加好友';

  @override
  String splitAmountBelowParticipants(int count) {
    return '這筆金額太小,無法平均分給 $count 個人。';
  }

  @override
  String get splitExactMustSumToAmount => '各人份額加總必須等於總額。';

  @override
  String splitDeleteConfirmTitle(String description) {
    return '刪除「$description」?';
  }

  @override
  String get splitDeleteConfirmMessage => '這會移除這筆支出與所有人的分擔,且無法復原。';

  @override
  String get splitDeleteConfirmButton => '刪除';

  @override
  String get splitSaveFailedMessage => '儲存失敗,請再試一次。';

  @override
  String get splitErrorNotFriends => '對方還不是你的好友,先加好友再分帳。';

  @override
  String get splitErrorNotAGroupMember => '對方不是這個群組的成員。';

  @override
  String get splitErrorGroupArchived => '這個群組已封存,無法新增支出。';

  @override
  String splitErrorSharesMismatch(String message) {
    return '分擔金額加總不等於總額:$message';
  }

  @override
  String get splitErrorTooSmall => '金額太小,無法分帳。';

  @override
  String get splitErrorDuplicateParticipant => '同一個人不能重複列入。';

  @override
  String get splitErrorAlreadyMember => '對方已經是這個群組的成員。';

  @override
  String get splitErrorNotAParticipant => '你需要持有這筆支出的份額才能這麼做。';

  @override
  String splitErrorInvalidInput(String message) {
    return '這筆分帳無法接受:$message';
  }

  @override
  String splitErrorBadRequest(String message) {
    return '這筆資料被退回:$message';
  }

  @override
  String get splitErrorNotFound => '找不到這筆資料,可能已被刪除。';

  @override
  String get splitErrorCannotSettleWithSelf => '不能記錄跟自己的還款。';

  @override
  String get splitErrorGeneric => '發生錯誤,請再試一次。';

  @override
  String get splitGroupArchivedBadge => '已封存';

  @override
  String get splitGroupMembersTitle => '成員';

  @override
  String get splitGroupBalancesTitle => '分帳淨額(不含還款)';

  @override
  String get splitGroupBalancesNote => '不含還款——雙人結清不會改變這個數字。';

  @override
  String splitGroupBalanceShouldCollect(String name, String amount) {
    return '$name 應收 $amount';
  }

  @override
  String splitGroupBalanceShouldPay(String name, String amount) {
    return '$name 應付 $amount';
  }

  @override
  String get splitGroupExpensesTitle => '支出';

  @override
  String get splitGroupNoExpensesYet => '這個群組還沒有支出';

  @override
  String get splitAddMemberButton => '新增成員';

  @override
  String get splitAddMemberTitle => '從好友加入這個群組';

  @override
  String get splitAddMemberEmpty => '你的好友都已經在這個群組裡了。';

  @override
  String get splitArchiveButton => '封存群組';

  @override
  String splitArchiveConfirmTitle(String groupName) {
    return '封存「$groupName」?';
  }

  @override
  String get splitArchiveConfirmMessage =>
      '群組會變成唯讀:不能再新增支出或成員,但既有支出仍可由建立者或付款人編輯。';

  @override
  String get splitArchiveConfirmButton => '封存';

  @override
  String get splitAddExpenseTooltip => '記一筆分帳';

  @override
  String get splitEditExpenseTooltip => '編輯';

  @override
  String get splitDeleteExpenseTooltip => '刪除';

  @override
  String get splitGroupLoadFailedMessage => '無法載入這個群組,請檢查網路連線後再試一次。';

  @override
  String settleUpTitlePaying(String name) {
    return '還給 $name';
  }

  @override
  String settleUpTitleReceiving(String name) {
    return '$name 還你';
  }

  @override
  String get settleUpConfirmButton => '確認';

  @override
  String get settleUpAmountRequired => '請輸入金額';

  @override
  String get settleUpAmountMustBeWhole => '這個幣別沒有小數,請輸入整數';

  @override
  String get settleUpAmountTooLarge => '金額太大';

  @override
  String settleUpOverpayWarningTheyWillOwe(String name, String amount) {
    return '$name 會變成欠你 $amount';
  }

  @override
  String settleUpOverpayWarningYouWillOwe(String name, String amount) {
    return '你會變成欠 $name $amount';
  }

  @override
  String get splitSectionRecentActivity => '近期動態';

  @override
  String get splitNoActivityYet => '還沒有支出或還款';

  @override
  String get splitSettleUpTooltip => '結清';

  @override
  String splitSettlementRow(String from, String to) {
    return '還款:$from 還給 $to';
  }

  @override
  String get splitDeleteSettlementTooltip => '刪除還款';

  @override
  String get splitDeleteSettlementConfirmTitle => '刪除這筆還款?';

  @override
  String splitDeleteSettlementConfirmMessage(String name, String amount) {
    return '這會刪除與 $name 的 $amount 還款紀錄,無法復原。';
  }

  @override
  String get splitDeleteSettlementConfirmButton => '刪除';

  @override
  String get splitGroupPersonalBalancesTitle => '我與各成員的往來';

  @override
  String get splitGroupPersonalBalancesNote => '涵蓋你們所有的共同紀錄,不只這個群組。';

  @override
  String get splitSectionOverview => '摘要';

  @override
  String get splitSectionChangeLog => '變更紀錄';

  @override
  String get splitActivityEmptyTitle => '還沒有任何變更';

  @override
  String get splitActivityEmptyBody => '你或和你分帳的人新增、修改或刪除紀錄之後,就會出現在這裡。';

  @override
  String get splitActivityLoadFailedMessage => '無法載入變更紀錄,請檢查連線後再試一次。';

  @override
  String get splitActivityLoadMoreFailed => '無法載入更多紀錄。';

  @override
  String splitActivityExpenseCreatedYou(String description) {
    return '你新增了 $description';
  }

  @override
  String splitActivityExpenseCreatedOther(String name, String description) {
    return '$name 新增了 $description';
  }

  @override
  String splitActivityExpenseUpdatedYou(String description) {
    return '你修改了 $description';
  }

  @override
  String splitActivityExpenseUpdatedOther(String name, String description) {
    return '$name 修改了 $description';
  }

  @override
  String splitActivityExpenseDeletedYou(String description) {
    return '你刪除了 $description';
  }

  @override
  String splitActivityExpenseDeletedOther(String name, String description) {
    return '$name 刪除了 $description';
  }

  @override
  String get splitActivitySettlementCreatedYou => '你記了一筆還款';

  @override
  String splitActivitySettlementCreatedOther(String name) {
    return '$name 記了一筆還款';
  }

  @override
  String get splitActivitySettlementDeletedYou => '你刪除了一筆還款';

  @override
  String splitActivitySettlementDeletedOther(String name) {
    return '$name 刪除了一筆還款';
  }

  @override
  String splitActivityGroupCreatedYou(String group) {
    return '你建立了群組 $group';
  }

  @override
  String splitActivityGroupCreatedOther(String name, String group) {
    return '$name 建立了群組 $group';
  }

  @override
  String splitActivityGroupMemberAddedYou(String member, String group) {
    return '你把 $member 加入 $group';
  }

  @override
  String splitActivityGroupMemberAddedOther(
    String name,
    String member,
    String group,
  ) {
    return '$name 把 $member 加入 $group';
  }

  @override
  String splitActivityGroupMemberAddedYouWere(String name, String group) {
    return '$name 把你加入 $group';
  }

  @override
  String splitActivityGroupArchivedYou(String group) {
    return '你封存了群組 $group';
  }

  @override
  String splitActivityGroupArchivedOther(String name, String group) {
    return '$name 封存了群組 $group';
  }

  @override
  String splitActivityRepaymentYouPaid(String name) {
    return '你付給 $name';
  }

  @override
  String splitActivityRepaymentPaidYou(String name) {
    return '$name 付給你';
  }

  @override
  String splitActivityRepaymentBetween(String payer, String payee) {
    return '$payer 付給 $payee';
  }

  @override
  String splitActivityAmountChange(String previous, String amount) {
    return '$previous → $amount';
  }

  @override
  String splitActivityAmountChangeSpoken(String previous, String amount) {
    return '從 $previous 變成 $amount';
  }

  @override
  String get splitActivityUnknownYou => '你做了一項變更';

  @override
  String splitActivityUnknownOther(String name) {
    return '$name 做了一項變更';
  }

  @override
  String splitActivityRowDetail(String what, String detail) {
    return '$what:$detail';
  }

  @override
  String splitActivityRowSemantics(String what, String amount, String time) {
    return '$what,$amount,$time';
  }

  @override
  String get splitActivityUnnamedItem => '未命名項目';

  @override
  String get splitActivityUnnamedGroup => '未命名群組';

  @override
  String splitActivityRowSemanticsNoAmount(String what, String time) {
    return '$what,$time';
  }
}
