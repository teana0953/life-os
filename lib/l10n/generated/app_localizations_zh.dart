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
}
